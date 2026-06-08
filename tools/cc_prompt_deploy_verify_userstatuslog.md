# CC Task — Deploy + Verify: RTSData_UserStatusLog write (DayTrend agent history)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## Git push (§37)
Do NOT run `git push`. This task makes NO commit (deploy/verify only).

---

## Step 0 — integrity + fetch (§0.6a + §42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
# fix 434e4c7 is already on origin/v2; verify local HEAD is at/ancestor of origin/v2
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
git merge-base --is-ancestor HEAD origin/v2 && echo "HEAD is ancestor/equal of origin/v2 (OK)" || echo "WARNING: local HEAD ahead of origin/v2 — report"
# Known false-M (do NOT restore): db/data/02_metrics.sql, db/schema.sql
```

## Multi-session sync (§42) — slug: daytrend-0606
- Claims: NONE (read + execute only; this task does not edit repo files and does not commit).
- S1 barrier check (content-based):
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
```
- If verification reveals a CODE/SQL FIX is needed: STOP, report to operator. Do NOT edit
  db/functions or migrations here — that becomes a separate claimed+committed task.

---

# TASK — runs against the PROD database

DB connection (operator sets the password in the environment before running; do NOT hardcode):
```powershell
$env:PGPASSWORD = "<DB_PASSWORD>"   # operator-provided
$DB = "rtmviewdb"; $U = "ccdashboard_user"
```

## 1. Apply the migration (idempotent — DROP old + CREATE 15-param PROCEDURE with Log INSERT)
```powershell
psql -U $U -d $DB -f "db\migrations\20260606_002_fix_userstatuslog_write.sql"
```
(`db/functions/02_rtsdata_functions.sql` carries the same definition; applying the migration is
sufficient for this procedure.)

## 2. VERIFY — procedure replaced, single object, body writes the Log
```sql
SELECT p.prokind, pg_get_function_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='RTSData_SetUserStatus';
-- expect ONE row, prokind='p' (procedure), 15 args. Stale 13-param FUNCTION must be gone.

SELECT pg_get_functiondef(p.oid) LIKE '%RTSData_UserStatusLog%' AS has_log_insert
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname='RTSData_SetUserStatus';
-- expect t
```

## 3. VERIFY — Log fills for today after the RTM Service processes live status changes
(Let RTM Service run a few minutes with live agents, then:)
```sql
SELECT COUNT(*) AS log_today, MIN("StartTime") first_t, MAX("StartTime") last_t
FROM "RTSData_UserStatusLog"
WHERE "OnDate" = to_char(current_date,'DD/MM/YYYY');
-- expect log_today > 0 and growing (was 0 before the fix)

SELECT "StatusGroup", "TenantId", COUNT(*)
FROM "RTSData_UserStatusLog"
WHERE "OnDate" = to_char(current_date,'DD/MM/YYYY')
GROUP BY 1,2;
-- StatusGroup must be NOT NULL and TenantId set, else fn_daytrendagentstatus excludes the rows
```

## 4. VERIFY — read function returns agent history (substitute tenant uuid + BU queues + interval)
```sql
SELECT * FROM fn_daytrendagentstatus(
  '<tenant-uuid>'::uuid,
  to_char(current_date,'DD/MM/YYYY'),
  ARRAY['<queue1>','<queue2>'],   -- from NGC_BusinessUnitQueueClassification for the BU
  30
) WHERE metric_id LIKE 'statuslog.%' LIMIT 20;
-- expect non-empty statuslog.* rows with non-zero values (was empty before the fix)
```

## 5. Report (no commit)
Report to operator: migration applied (Y/N), §2 results (prokind/args/has_log_insert),
§3 log_today count + StatusGroup/TenantId fill, §4 sample rows. If all pass -> agent-history bug
closed on this DB. If §2 shows two objects or has_log_insert=f -> STOP, report (fix needed).

## RELEASE caveat (flag to operator — NOT part of this task)
Any package build (Build-ProdRelease.ps1, Mode RTM/Full) must RE-EXPORT the DB dump AFTER this
migration is applied — the bundled Installations/dump-...202606041735.sql PREDATES the fix and
would ship the old function. Use db/tools/Export-All.ps1 to refresh before packaging.
