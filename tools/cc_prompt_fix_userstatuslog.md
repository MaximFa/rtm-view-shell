# CC Task — Fix: restore RTSData_UserStatusLog write (DayTrend agent history)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only. Push is requested separately via the barrier.

---

## §0.6a — MANDATORY INTEGRITY CHECK — Step 0 (NO EXCEPTIONS)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== integrity check complete ==="
```
Known false-M (hash==HEAD, do NOT restore): `db/data/02_metrics.sql`, `db/schema.sql`.
NOTE: `RTM/RTM/Union.cs`, `RTM/RTM/UserManager.cs`, `tools/lint_metrics.py` are metrics-0605
territory — if truncated, DO NOT touch; they are outside this task's claims.

---

## Multi-session sync — MANDATORY (§42)
Session slug: `daytrend-0606`
Claims for this task:
  - db/functions/02_rtsdata_functions.sql
  - db/migrations/20260606_002_fix_userstatuslog_write.sql

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py daytrend-0606 \
  db/functions/02_rtsdata_functions.sql \
  db/migrations/20260606_002_fix_userstatuslog_write.sql
# exit 1 -> STOP (conflict -> queue, skill §9). Touch ONLY the two claimed files (+ /tmp).
```

### S3. Commit lock — around the git add/commit  (PHANTOM-AWARE, L-SC-14)
Acquire with this exact script (a phantom commit.lock dirent is on the mount: `test -f` YES,
no content — the old non-phantom script would hang/fail on it):

```python
# /tmp/daytrend-0606_acquire_lock.py — phantom-aware
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
def real_lock():
    try:
        with open(lock) as f:
            return f.read().strip() != ""   # real lock = non-empty readable content
    except OSError:
        return False
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: daytrend-0606\nacquired: "
                    + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        if not real_lock():
            print("PHANTOM lock (empty/unreadable dirent) - clearing")
            try: os.remove(lock)
            except OSError: print("  cannot unlink this side - needs CC/Windows rm")
            time.sleep(2); continue
        print("BUSY (real): " + open(lock).read().strip()); time.sleep(60)
print("FAILED to acquire commit lock after 5 attempts"); sys.exit(1)
```

If FAILED: abort the commit, report the lock owner. A REAL lock >15 min is stale -> report
contents and WAIT for operator; never auto-delete a real lock.

### S4. Journal + release — after the commit
Append `<UTC> | daytrend-0606 | <hash> <subject>` to `.coord/journal.md` (Python+fsync),
then remove `.coord/locks/commit.lock`, then `sync`.

### S4b. Post-commit flush to coordinator (REQUIRED, v1.4)
After the journal line, append ONE block to `.coord/inbox/coordinator.md` (Python+fsync,
/tmp script named per-slug — L-SC-16):

```python
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
block = (
    "## " + datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
    + " | from: daytrend-0606 | to: coordinator\n"
    "COMMIT " + h + "\n"
    "claims-releasable: db/functions/02_rtsdata_functions.sql, db/migrations/20260606_002_fix_userstatuslog_write.sql\n"
    "blocker/question: none\n"
    "next: awaiting operator (prod deploy of migration _002 + push barrier)\n---\n"
)
with open(".coord/inbox/coordinator.md","a",encoding="utf-8") as f:
    f.write(block); f.flush(); os.fsync(f.fileno())
print("post-commit flush written")
```
Then `sync`. Since claims are releasable, ALSO remove both db paths from `files:` in
`.coord/sessions/daytrend-0606.md` (frees them for waiters, §9).

### S5. No push (§37).

---

## File writes — Python + os.fsync ONLY. Edit tool is BANNED (§0.3).
After every write: `sync && tail -3 <file> && wc -l <file>`.

---

# TASK

## Background (root cause — verified)
`fn_daytrendagentstatus` reads agent history ONLY from `RTSData_UserStatusLog`. The live
prod procedure `RTSData_SetUserStatus` (15-param PROCEDURE, the one RTM C# DBMng calls)
upserts current state into `RTSData_UserStatus` but NEVER appends to `RTSData_UserStatusLog`.
The original MSSQL SP did both (H_RTM.sql:27062). The MSSQL->PG port dropped the log INSERT.
Result: `RTSData_UserStatusLog` holds only the one-time migrated rows; nothing is written for
any current day -> DayTrend shows no historical agent data. Prod-verified: today count = 0
while agents are live.

`db/functions/02_rtsdata_functions.sql` currently defines a STALE 13-param FUNCTION that does
NOT match the C# call and is superseded by the deployed 15-param PROCEDURE. This task makes the
source match reality AND restores the log write.

## Step 1 — db/functions/02_rtsdata_functions.sql  (claimed)
Replace section "2. RTSData_SetUserStatus" (the 13-param `CREATE OR REPLACE FUNCTION`, approx
lines 105-156) with the 15-param PROCEDURE below. Drop the stale function explicitly. Keep the
param ORDER exactly (matches RTM DBMng.cs:355-369 and schema.sql:974).

```sql
-- ============================================================================
-- 2. RTSData_SetUserStatus  (PROCEDURE, 15 params — matches RTM DBMng C# call)
--    (a) APPEND history row to RTSData_UserStatusLog  [restored MSSQL behaviour;
--        fn_daytrendagentstatus reads agent history ONLY from this table]
--    (b) UPSERT current state into RTSData_UserStatus (ON CONFLICT 4-col PK)
-- ============================================================================
DROP FUNCTION IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, integer, integer,
    integer, text, text, timestamptz, text, text, uuid
);
DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus"(
    text, text, text, text, text, text,
    double precision, double precision, integer, text,
    timestamptz, timestamptz, text, timestamptz, uuid
);

CREATE PROCEDURE "RTSData_SetUserStatus"(
    p_user_id        text,
    p_status_id      text,
    p_server_id      text,
    p_on_date        text,
    p_status_name    text,
    p_status_group   text,
    p_total_duration double precision,
    p_max_duration   double precision,
    p_total_count    integer,
    p_display_name   text,
    p_start_time     timestamptz,
    p_end_time       timestamptz,
    p_time_zone      text,
    p_update_time    timestamptz,
    p_tenant_id      uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- (a) Append-only history (powers DayTrend agent metrics). StatusGroup + TenantId
    --     are required by fn_daytrendagentstatus and exist on the PG table.
    IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL
       AND p_end_time > p_start_time THEN
        INSERT INTO "RTSData_UserStatusLog" (
            "TenantId","UserId","StatusId","ServerId","OnDate",
            "StartTime","EndTime","Duration","UpdateTime","TimeZone","StatusGroup"
        )
        VALUES (
            p_tenant_id, p_user_id, p_status_id, p_server_id, p_on_date,
            p_start_time, p_end_time,
            (EXTRACT(EPOCH FROM (p_end_time - p_start_time)) * 1000)::integer,
            p_update_time, p_time_zone, p_status_group
        );
    END IF;

    -- (b) Current-state upsert (unchanged behaviour).
    INSERT INTO "RTSData_UserStatus" (
        "UserId","StatusId","ServerId","OnDate",
        "StatusName","StatusGroup","TotalDuration","MaxDuraction",
        "TotalCount","UpdateTime","DisplayName","TimeZone","TenantId"
    )
    VALUES (
        p_user_id, p_status_id, p_server_id, p_on_date,
        p_status_name, p_status_group, p_total_duration::integer, p_max_duration::integer,
        p_total_count, p_update_time, p_display_name, p_time_zone, p_tenant_id
    )
    ON CONFLICT ("UserId","StatusId","ServerId","OnDate")
    DO UPDATE SET
        "StatusName"    = EXCLUDED."StatusName",
        "StatusGroup"   = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuraction"  = EXCLUDED."MaxDuraction",
        "TotalCount"    = EXCLUDED."TotalCount",
        "UpdateTime"    = EXCLUDED."UpdateTime",
        "DisplayName"   = EXCLUDED."DisplayName",
        "TimeZone"      = EXCLUDED."TimeZone",
        "TenantId"      = EXCLUDED."TenantId";
END;
$$;
```

## Step 2 — db/migrations/20260606_002_fix_userstatuslog_write.sql  (claimed, NEW)
Create an idempotent deploy migration with the SAME `DROP ... DROP ... CREATE PROCEDURE`
block as Step 1. Header comment MUST state explicitly the SIGNATURE CHANGE: drop the stale
13-param FUNCTION, replace with the 15-param PROCEDURE (this is what aligns source==prod), and
the restored RTSData_UserStatusLog write. Date 2026-06-06. Deploy on prod via:
`psql -U ccdashboard_user -d rtmviewdb -f db/migrations/20260606_002_fix_userstatuslog_write.sql`

## Do NOT
- Do NOT hand-edit `db/schema.sql` (generated by Export-All; regenerated after deploy).
- Do NOT change `fn_daytrendagentstatus` (read side is correct).
- Do NOT touch any file outside the two claims.
- Do NOT change object KIND: keep it a PROCEDURE (C# DBAdapter calls via CALL; a FUNCTION
  would break the live call convention).

## Verify before commit
```bash
bash tools/pre-commit-check.sh db/functions/02_rtsdata_functions.sql db/migrations/20260606_002_fix_userstatuslog_write.sql
grep -n 'INSERT INTO "RTSData_UserStatusLog"' db/functions/02_rtsdata_functions.sql
grep -n 'CREATE PROCEDURE' db/functions/02_rtsdata_functions.sql
# only exit 0 from pre-commit-check -> commit
```

## Commit (under commit.lock, prefix db:)
```
db: write RTSData_UserStatusLog in RTSData_SetUserStatus (restore DayTrend agent history)
```

## §0.6 post-commit + PD-007 re-sync
```bash
git status --short            # expect empty
git diff HEAD -- db/functions/02_rtsdata_functions.sql db/migrations/20260606_002_fix_userstatuslog_write.sql   # empty
for f in db/functions/02_rtsdata_functions.sql db/migrations/20260606_002_fix_userstatuslog_write.sql; do
    git show HEAD:"$f" > "$f"; echo "re-synced $f ($(wc -l < "$f") lines)"; done
sync
```

## Operator note (post-deploy proof — NOT part of this CC task)
After deploying the migration on prod and letting RTM Service run, agent history fills:
`SELECT COUNT(*) FROM "RTSData_UserStatusLog" WHERE "OnDate" = to_char(current_date,'DD/MM/YYYY');`
grows from 0; DayTrend agent metrics then appear for the current day.
Refresh schema.sql afterwards via `db/tools/Export-All.ps1`.
