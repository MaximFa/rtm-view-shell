# CC Task — Add StatusGroup column to RTSData_UserStatusLog (DayTrend agent metrics)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Git push (§37)
Do NOT run `git push`. Commit only.

---

## Step 0 — integrity + fetch (§0.6a + §42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
# For every M file: if HEAD lines > working lines -> truncated -> git show HEAD:f > f
# Known false-M (do NOT restore): db/data/02_metrics.sql, db/schema.sql
```

## Multi-session sync (§42) — slug: daytrend-0606
Claim (single new file): db/migrations/20260606_004_userstatuslog_statusgroup.sql
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
python3 tools/coord_check_claims.py daytrend-0606 db/migrations/20260606_004_userstatuslog_statusgroup.sql
# exit 1 -> STOP (queue). Touch ONLY this file (+ /tmp). Edit tool BANNED (§0.3): Python+fsync writes.
```
- S3 commit lock: phantom-aware acquire (owner daytrend-0606) from tools/cc_prompt_sync_block.md.
- S4 journal + release; S4b post-commit flush to .coord/inbox/coordinator.md (per-slug /tmp script).

---

# TASK

## Root cause (verified on prod)
RTSData_UserStatusLog has NO "StatusGroup" column (original MSSQL never had it; pgloader-migrated
prod never got it; patch_origin_v2.sql added catalogue columns but NOT this one). The deployed
RTSData_SetUserStatus procedure DOES write StatusGroup into the Log -> INSERT fails on the missing
column -> Log stays empty -> fn_daytrendagentstatus (filters usl."StatusGroup") returns nothing ->
DayTrend Agent Metrics are empty. Fix = add the column (+ supporting index), idempotently, for
existing deployments. (db/schema.sql + db/functions already define it correctly; this migration
brings already-migrated databases into line.)

## Create file: db/migrations/20260606_004_userstatuslog_statusgroup.sql
Idempotent, ON_ERROR_STOP-safe. Contents:

1. Header comment: purpose + date 2026-06-06 + "adds StatusGroup to RTSData_UserStatusLog;
   re-asserts RTSData_SetUserStatus so column + writer are consistent".

2. Column + index (idempotent):
```sql
ALTER TABLE "RTSData_UserStatusLog"
  ADD COLUMN IF NOT EXISTS "StatusGroup" varchar(50);

-- Index definition copied from db/schema.sql:3525 (single source); only addition = IF NOT EXISTS.
CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
  ON "RTSData_UserStatusLog" USING btree ("TenantId", "StatusGroup", "StartTime", "EndTime");
```

3. Re-assert the procedure: copy the CURRENT `RTSData_SetUserStatus` definition VERBATIM from
   db/functions/02_rtsdata_functions.sql (section "2. RTSData_SetUserStatus" — the
   DROP FUNCTION + DROP PROCEDURE + CREATE PROCEDURE block that writes both RTSData_UserStatusLog
   and RTSData_UserStatus). Do NOT rewrite it by hand — copy it so there is a single source.

Do NOT touch db/schema.sql (generated; already has the column+index) or db/functions (already
correct). Touch ONLY the new migration file.

## Verify before commit
```bash
bash tools/pre-commit-check.sh db/migrations/20260606_004_userstatuslog_statusgroup.sql
grep -c 'ADD COLUMN IF NOT EXISTS "StatusGroup"' db/migrations/20260606_004_userstatuslog_statusgroup.sql   # 1
grep -c 'CREATE PROCEDURE "RTSData_SetUserStatus"' db/migrations/20260606_004_userstatuslog_statusgroup.sql # 1
```

## Commit (under commit.lock, prefix db:)
```
db: add StatusGroup column to RTSData_UserStatusLog (DayTrend agent metrics)
```
Then §0.6 post-commit verify + PD-007 re-sync of the file, S4 journal/release, S4b flush.

## Deploy + verify on prod (after commit; operator sets PGPASSWORD)
```powershell
psql -U ccdashboard_user -d rtmviewdb -f "db\migrations\20260606_004_userstatuslog_statusgroup.sql"
```
```sql
-- column now exists:
\d "RTSData_UserStatusLog"
-- after RTM Service runs a few minutes with live agents:
SELECT "StatusGroup", COUNT(*) FROM "RTSData_UserStatusLog"
WHERE "OnDate" = to_char(current_date,'DD/MM/YYYY') GROUP BY 1;
-- expect rows; StatusGroup populated with AVAILABLE/ONPHONE/BREAK/PAPERWORK/TRAINING
-- then DayTrend Agent Metrics (statuslog.*) render for today
```

## RELEASE caveat
Any package build must RE-EXPORT the DB dump (db/tools/Export-All.ps1) after this migration.
