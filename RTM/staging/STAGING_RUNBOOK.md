# RTM Backend PostgreSQL Staging Runbook

> Deployment guide for migrating RTM backend from SQL Server to PostgreSQL staging environment.

---

## Prerequisites

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| pgloader | 3.6+ | https://pgloader.io |
| PostgreSQL | 15+ | https://www.postgresql.org/download/ |
| .NET SDK | 8.0+ | https://dotnet.microsoft.com/download |
| SQL Server | 2016+ | Source database (read access required) |

### Install EF Core Tools

```powershell
dotnet tool install --global dotnet-ef
# or update if already installed:
dotnet tool update --global dotnet-ef
```

### Create PostgreSQL Database and User

```sql
-- Run as postgres superuser
CREATE DATABASE cc_rtm_staging;
CREATE USER cc_rtm_app WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE cc_rtm_staging TO cc_rtm_app;

-- Connect to cc_rtm_staging and grant schema permissions
\c cc_rtm_staging
GRANT ALL ON SCHEMA public TO cc_rtm_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO cc_rtm_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO cc_rtm_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO cc_rtm_app;
```

### Verify SQL Server Access

Ensure the machine running the migration can connect to SQL Server RTM source database (H_RTM).

---

## Quick Start (PowerShell)

Run the automated deployment script:

```powershell
cd RTM\staging

.\run_staging.ps1 `
    -PgHost "localhost" `
    -PgPort 5432 `
    -PgDb "cc_rtm_staging" `
    -PgUser "cc_rtm_app" `
    -PgPassword "your_pg_password" `
    -MssqlConn "mssql://sa:your_sql_password@localhost/H_RTM" `
    -PgloaderPath "C:\Tools\pgloader\pgloader.exe"
```

### Script Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-PgHost` | No | localhost | PostgreSQL host |
| `-PgPort` | No | 5432 | PostgreSQL port |
| `-PgDb` | No | cc_rtm_staging | Target database |
| `-PgUser` | No | cc_rtm_app | PostgreSQL user |
| `-PgPassword` | **Yes** | - | PostgreSQL password |
| `-MssqlConn` | No | - | SQL Server connection for pgloader |
| `-PgloaderPath` | No | pgloader | Path to pgloader executable |
| `-SkipEfMigrations` | No | false | Skip EF migration step |
| `-SkipPgloader` | No | false | Skip data migration step |

---

## Manual Steps (if script fails)

### Step 1: Test PostgreSQL Connectivity

```powershell
$env:PGPASSWORD = "your_pg_password"
psql -h localhost -p 5432 -U cc_rtm_app -d cc_rtm_staging -c "SELECT 1;"
```

Expected: Returns `1` without errors.

### Step 2: Run EF Migrations

```powershell
cd C:\path\to\RTM-View-Shell

# Set connection string
$env:ASPNETCORE_ConnectionStrings__BackendEmulation = "Host=localhost;Port=5432;Database=cc_rtm_staging;Username=cc_rtm_app;Password=your_pg_password"

# Apply BackendEmulationDbContext migrations
dotnet ef database update `
    --context BackendEmulationDbContext `
    --project src/CcDashboard.Infrastructure `
    --startup-project src/CcDashboard.Web
```

Expected: `Done.` message with applied migrations listed.

### Step 3: Deploy PL/pgSQL Functions

```powershell
psql -h localhost -p 5432 -U cc_rtm_app -d cc_rtm_staging `
    -f RTM/staging/00_deploy_all_functions.sql
```

Expected: Output shows 37 functions deployed across 4 sections.

Verify function count:
```sql
SELECT COUNT(*) FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname LIKE ANY(ARRAY['ngc_%', 'rts%']);
-- Expected: 37
```

### Step 4: Run pgloader Data Migration

Edit `RTM/sql/pgloader/rtm_staging.load`:
- Replace `YOUR_SQL_SERVER_PASSWORD` with actual password
- Replace `changeme` with PostgreSQL password

```powershell
pgloader RTM/sql/pgloader/rtm_staging.load
```

Expected: Summary table showing rows loaded for each table.

### Step 5: Run Verification Queries

```powershell
psql -h localhost -p 5432 -U cc_rtm_app -d cc_rtm_staging `
    -f RTM/sql/pgloader/verify_migration.sql `
    -o RTM/staging/results/verify_manual.txt
```

Review output file for any errors or unexpected counts.

### Step 6: RTSData_UserStatusLog Special Migration

If RTSData_UserStatusLog has data, run Duration conversion:

```sql
-- Check if temp table approach is needed
SELECT COUNT(*), MIN("Duration"), MAX("Duration")
FROM "RTSData_UserStatusLog";

-- If Duration values are < 1000, they're in seconds — need conversion
-- (pgloader should have skipped this table; load separately with transform)
```

---

## Verification Checklist

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| EF migrations applied | No errors | | ☐ |
| PL/pgSQL functions deployed | Count: 37 | | ☐ |
| pgloader completed | No errors | | ☐ |
| NGC_Site row count | Matches SQL Server | | ☐ |
| NGC_BusinessUnit row count | Matches SQL Server | | ☐ |
| RTSGrid_Grid row count | Matches SQL Server | | ☐ |
| RTSGrid_Metric row count | Matches SQL Server | | ☐ |
| RTSData_Interaction row count | Matches SQL Server | | ☐ |
| UPSERT test passed | Row count unchanged | | ☐ |
| NGC_GetSiteTable() returns data | Rows > 0 | | ☐ |
| RTSGrid_GetAllMetrics() returns data | Rows > 0 | | ☐ |
| RTSGrid_GetDataCells() executes | No errors | | ☐ |
| All 37 function smoke tests | Passed | | ☐ |

### Quick Verification Queries

```sql
-- Row counts
SELECT 'NGC_Site' AS t, COUNT(*) FROM "NGC_Site"
UNION ALL SELECT 'NGC_BusinessUnit', COUNT(*) FROM "NGC_BusinessUnit"
UNION ALL SELECT 'RTSGrid_Grid', COUNT(*) FROM "RTSGrid_Grid"
UNION ALL SELECT 'RTSGrid_Metric', COUNT(*) FROM "RTSGrid_Metric"
UNION ALL SELECT 'RTSData_Interaction', COUNT(*) FROM "RTSData_Interaction";

-- Function smoke tests
SELECT COUNT(*) AS sites FROM "NGC_GetSiteTable"();
SELECT COUNT(*) AS metrics FROM "RTSGrid_GetAllMetrics"();
SELECT COUNT(*) AS data_cells FROM "RTSGrid_GetDataCells"();
```

---

## Known Limitations

### RTSData_UserStatusLog Duration Field

The `Duration` column requires multiplication by 1000 (seconds → milliseconds) during migration.
pgloader cannot perform this transform natively. The table is **excluded** from the main pgloader run.

**Manual migration required:**
```sql
-- After pgloader completes, migrate separately:
-- 1. Load to temp table from SQL Server (using separate pgloader config)
-- 2. Transform and insert:
INSERT INTO "RTSData_UserStatusLog" (...)
SELECT ..., "Duration" * 1000, ...
FROM tmp_userstatuslog;
```

### RTSGrid_UserStatus

This table has **no DDL in SQL Server** — it was reconstructed from stored procedure parameters.
It starts empty in PostgreSQL and will be populated by the RTM backend during normal operation.

### RTSUserView_GetHTMLSettings

This function is a **stub** returning empty results. The original SQL Server SP reads from
DNN (DotNetNuke) CMS `ModuleSettings` table, which is not migrated.

**Decision required (OQ-01):**
- Keep as stub (current)
- Port DNN table to PostgreSQL
- Move settings to appsettings.json and read in C#

---

## Rollback

To completely reset staging and start over:

```sql
-- Connect as postgres superuser
DROP DATABASE cc_rtm_staging;
CREATE DATABASE cc_rtm_staging;
GRANT ALL PRIVILEGES ON DATABASE cc_rtm_staging TO cc_rtm_app;
```

Then re-run the deployment from Step 1.

---

## Troubleshooting

### pgloader "connection refused"

- Verify SQL Server allows remote connections
- Check firewall rules for port 1433
- Verify SQL Server authentication mode (mixed mode required for sa login)

### EF migrations fail with "relation does not exist"

- Ensure you're using `BackendEmulationDbContext`, not `AppDbContext`
- Check connection string points to correct database

### Function deployment errors

- Verify tables exist (EF migrations must complete first)
- Check for syntax errors in 00_deploy_all_functions.sql
- Run each section separately to isolate issues

### pgloader "permission denied"

- Ensure `cc_rtm_app` has GRANT ALL on the database
- Run schema grants as shown in Prerequisites

---

## Files Reference

| File | Purpose |
|------|---------|
| `RTM/staging/00_deploy_all_functions.sql` | Combined 37 PL/pgSQL functions |
| `RTM/staging/run_staging.ps1` | Automated deployment script |
| `RTM/staging/STAGING_RUNBOOK.md` | This document |
| `RTM/staging/results/` | Verification output files |
| `RTM/sql/pgloader/rtm_staging.load` | pgloader configuration |
| `RTM/sql/pgloader/verify_migration.sql` | Verification queries |

---

*Last updated: 2026-05-30*
