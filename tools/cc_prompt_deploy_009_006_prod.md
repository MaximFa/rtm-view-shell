# CC Task — DEPLOY _009 + _006 to prod (rtmviewdb) + verify (deploy-only, NO commit)

> devops-2-0607. Apply the two pushed migrations to PROD so the repo and prod match. _009 (prod was
> already hotfixed manually -> re-apply is idempotent confirmation). _006 (UNAVAILABLE RT metrics — NEW
> on prod). Deploy-only: no repo edits, no commit, no claims (executing committed SQL is not a repo change).

## Step 0 — fetch + confirm clean HEAD (§42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/v2)" && echo "HEAD==origin/v2 OK (dbd694c)" || echo "DIVERGED — reconcile before deploy"
```

## Sync: S1 barrier check (content-based). NO claims (deploy only). NO push.

## A. Apply _009 (FUNCTION->PROCEDURE) — DDL, run as POSTGRES (table owner; §33.9/§33.8)
Operator sets the postgres password.
```powershell
$env:PGPASSWORD = "<postgres password>"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 `
  -f "db\migrations\20260606_009_ngc_useragentgroup_procedures.sql"
# verify: both must be prokind='p'
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U postgres -d rtmviewdb -c `
  "SELECT proname, prokind FROM pg_proc WHERE proname IN ('NGC_SetUserAgentgroup','NGC_DeleteUserAgentgroup') ORDER BY proname;"
# smoke a CALL (proves the RTM path):
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U postgres -d rtmviewdb -c `
  "CALL ""NGC_SetUserAgentgroup""('u-smoke','ag-smoke','00000000-0000-0000-0000-000000000000'); CALL ""NGC_DeleteUserAgentgroup""('u-smoke','ag-smoke','00000000-0000-0000-0000-000000000000');"
$env:PGPASSWORD = ""
```

## B. Apply _006 (UNAVAILABLE RT metrics) — DML INSERT, run as ccdashboard_user
```powershell
$env:PGPASSWORD = "<ccdashboard_user password>"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 `
  -f "db\migrations\20260606_006_unavailable_rtsgrid_metrics.sql"
# verify: 4 UNAVAILABLE GROUP metrics present
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U ccdashboard_user -d rtmviewdb -c `
  "SELECT ""MetricId"",""MetricFunction"" FROM ""RTSGrid_Metric"" WHERE ""MetricParameter""='UNAVAILABLE' ORDER BY ""MetricId"";"
$env:PGPASSWORD = ""
```
NOTE: _006 translations (db/data/05) + seeder/baseline are fresh-install seed paths — NOT a prod-apply
(prod gets the 4 metrics via this migration INSERT). Idempotent (ON CONFLICT DO NOTHING) — safe to re-run.

## Report to operator
prokind=p,p; CALL smoke OK; 4 UNAVAILABLE metrics present on prod; both idempotent. No commit/push.
