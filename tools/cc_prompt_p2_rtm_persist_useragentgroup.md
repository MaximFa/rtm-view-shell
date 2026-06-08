# CC Task — P2: persist agent↔agentgroup membership from RTM (NGC_UserAgentgroup)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## DEPENDENCY — DO NOT RUN until P1 is deployed
P1 (metrics-0605) must already exist in the target DB: table NGC_UserAgentgroup + SPs
NGC_SetUserAgentgroup / NGC_DeleteUserAgentgroup. If they are missing, STOP and report —
this task only WIRES the RTM calls; it does not create the table/SPs.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — integrity + fetch (§0.6a + §42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
# For every M file: HEAD lines > working lines -> truncated -> git show HEAD:f > f
# Known false-M (do NOT restore): db/data/02_metrics.sql, db/schema.sql
```

## Multi-session sync (§42) — slug: daytrend-0606
Claims: RTM/RTM/Engine.cs, RTM/RTM/DBMng.cs
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
python3 tools/coord_check_claims.py daytrend-0606 RTM/RTM/Engine.cs RTM/RTM/DBMng.cs
# exit 1 -> STOP (queue). Touch ONLY these 2 files (+ /tmp). Edit tool BANNED (§0.3): Python+fsync writes.
# NOTE: do NOT touch UserManager.cs (metrics quarantine) — the hook is in Engine.cs by design.
```
- S3 commit lock: phantom-aware acquire (owner daytrend-0606) from tools/cc_prompt_sync_block.md.
- S4 journal + release; S4b post-commit flush to .coord/inbox/coordinator.md (per-slug /tmp script).

---

# TASK

## Goal
Persist agent↔agentgroup (workgroup) membership into NGC_UserAgentgroup so DayTrend (P3) can scope
agent metrics to a BU without depending on calls. Membership lives in RTM memory only today
(UserManager._workgroups) — hook the same event path that maintains it.

## Edit 1 — RTM/RTM/DBMng.cs : add two synchronous persist methods
Mirror the existing `midnightClear()` style (DBAdapter.ExecuteNonQuery + @TenantId LAST, §33).
`_tenantId` field already exists (line ~192). Add:

```csharp
// Persist agent↔agentgroup membership (NGC_UserAgentgroup). SPs are P1 (metrics).
public void setUserAgentgroup(string userId, string agentgroupId)
{
    try
    {
        var parameters = new List<NpgsqlParameter>();
        parameters.Add(new NpgsqlParameter("@UserId", userId));
        parameters.Add(new NpgsqlParameter("@AgentgroupId", agentgroupId));
        parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
        DBAdapter.ExecuteNonQuery("NGC_SetUserAgentgroup", parameters);
    }
    catch (Exception ex) { AsyncLogger.Error("DBMng.setUserAgentgroup", ex); }
}

public void deleteUserAgentgroup(string userId, string agentgroupId)
{
    try
    {
        var parameters = new List<NpgsqlParameter>();
        parameters.Add(new NpgsqlParameter("@UserId", userId));
        parameters.Add(new NpgsqlParameter("@AgentgroupId", agentgroupId));
        parameters.Add(new NpgsqlParameter("@TenantId", _tenantId));
        DBAdapter.ExecuteNonQuery("NGC_DeleteUserAgentgroup", parameters);
    }
    catch (Exception ex) { AsyncLogger.Error("DBMng.deleteUserAgentgroup", ex); }
}
```

## Edit 2 — RTM/RTM/Engine.cs : call them in userWorkgroupActivation (~line 1544)
In `userWorkgroupActivation(string workgroup, List<string> activeUsersList, List<string> deactiveUsersList, …)`
the existing loops call `userManager.workgroupActivation(workgroup, true/false)`. Add the DB persist
right after each (Engine already has the `_dbMng` field — used by getUsersStatuses()):

```csharp
foreach (string userId in activeUsersList)
{
    userManager = getUserManager(userId);
    userManager.workgroupActivation(workgroup, true);
    _dbMng.setUserAgentgroup(userId, workgroup);      // + persist membership (P2)
}
foreach (string userId in deactiveUsersList)
{
    userManager = getUserManager(userId);
    userManager.workgroupActivation(workgroup, false);
    _dbMng.deleteUserAgentgroup(userId, workgroup);   // + remove membership (P2)
}
```
Init is covered by the same event (platform sends current membership as activation events on connect).

## Expected P1 SP contract (for metrics — must match these names/params; §33 tenant LAST)
- NGC_SetUserAgentgroup(p_user_id text, p_agentgroup_id text, p_tenant_id uuid)
    -> INSERT INTO "NGC_UserAgentgroup"(...) ON CONFLICT ("TenantId","UserId","AgentgroupId") DO NOTHING
- NGC_DeleteUserAgentgroup(p_user_id text, p_agentgroup_id text, p_tenant_id uuid)
    -> DELETE WHERE "TenantId"=p_tenant_id AND "UserId"=p_user_id AND "AgentgroupId"=p_agentgroup_id
If P1's SP names/signatures differ, STOP and reconcile via §9 before editing.

## PERFORMANCE NOTE (raise in §4 review)
On connect, activeUsersList can be large -> a synchronous ExecuteNonQuery per agent may burst the DB.
Acceptable for v1 (membership events are infrequent). If it proves heavy, a follow-up can batch or
route through the existing async DB request queue (addUserStatusRequest pattern). Flagging, not fixing.

## Verify before commit
```bash
# build RTM to ensure it compiles
dotnet build RTM/RTM -c Debug 2>&1 | tail -5
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs RTM/RTM/DBMng.cs
grep -c "setUserAgentgroup\|deleteUserAgentgroup" RTM/RTM/DBMng.cs   # >=2
grep -c "_dbMng.setUserAgentgroup\|_dbMng.deleteUserAgentgroup" RTM/RTM/Engine.cs  # 2
```

## Commit (under commit.lock, prefix rtm:)
```
rtm: persist agent↔agentgroup membership to NGC_UserAgentgroup (BU-scope groundwork)
```
Then §0.6 post-commit verify + PD-007 re-sync of both files, S4 journal/release, S4b flush.

## After deploy (operator)
Publish RTM Service (CLAUDE.md §27 fixed path), restart it; on connect it repopulates NGC_UserAgentgroup
from the platform's current membership, then keeps it live on add/remove. Verify:
SELECT "AgentgroupId", COUNT(*) FROM "NGC_UserAgentgroup" WHERE "TenantId"='<uuid>' GROUP BY 1;
