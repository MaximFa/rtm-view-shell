# Database Rebuild Runbook

> Fresh-install order and ownership split. Created R0b (2026-06-21).

## Overview

The database has **two distinct authority layers**:

| Authority | Owner | Tables | Creator |
|-----------|-------|--------|---------|
| **EF-app** | Shell (Web.exe migrate) | dashboards, identity.*, audit.*, permission_groups, tenants, etc. (38 tables) | EF Core migrations |
| **RTM-canonical** | db/schema.sql | NGC_*, RTSData_*, RTSGrid_*, RTSUserGrid_*, db_patch_history, metric_deploy_log (26 tables) | psql schema.sql |

## Fresh Install Order

### 1. Create Database and User (as postgres superuser)

```bash
psql -U postgres -c "CREATE USER ccdashboard_user WITH PASSWORD 'your_password';"
psql -U postgres -c "CREATE DATABASE rtmviewdb OWNER ccdashboard_user;"
psql -U postgres -d rtmviewdb -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql -U postgres -d rtmviewdb -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
psql -U postgres -d rtmviewdb -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
```

### 2. Run EF Migrations (App + Audit contexts)

```powershell
# This creates: identity.* tables, audit.* tables, all EF-app public tables,
# and the __ef_migrations_history tables (public + audit schemas).
CcDashboard.Web.exe migrate
```

**What this does:**
- Creates `identity` and `audit` schemas via EF's EnsureSchema
- Creates all 38 EF-app tables with indexes and FKs
- Creates `public.__ef_migrations_history` and `audit.__ef_migrations_history`
- Seeds roles (Superadmin, Administrator, Editor, Viewer)
- Seeds platform tenant and superadmin user via `DatabaseInitializer`

**Source code ref:** `DatabaseInitializer.cs` lines 34-35:
```csharp
await db.Database.MigrateAsync(cancellationToken);
await auditDb.Database.MigrateAsync(cancellationToken);
```

### 3. Apply RTM Schema (26 tables)

```bash
psql -U ccdashboard_user -d rtmviewdb -f db/schema.sql
```

**What this does:**
- Creates the 26 RTM-canonical tables (NGC_*, RTSData_*, RTSGrid_*, RTSUserGrid_*, db_patch_history, metric_deploy_log)
- Creates associated indexes and constraints
- Does NOT create identity/audit schemas (already done by Step 2)

### 4. Apply Functions

```bash
psql -U ccdashboard_user -d rtmviewdb -f db/functions/01_ngc_functions.sql
psql -U ccdashboard_user -d rtmviewdb -f db/functions/02_rtsdata_functions.sql
psql -U ccdashboard_user -d rtmviewdb -f db/functions/03_rtsgrid_read.sql
psql -U ccdashboard_user -d rtmviewdb -f db/functions/04_misc_functions.sql
```

### 5. Seed Data (RTM-only)

> Note: EF-app tables (tenants, roles, superadmin, widget_catalog) are seeded by Step 2 (Web.exe migrate / DatabaseInitializer).
> db/data/ contains RTM-canonical seed data only.

```bash
psql -U ccdashboard_user -d rtmviewdb -f db/data/02_metrics.sql
psql -U ccdashboard_user -d rtmviewdb -f db/data/03_rtsgrid.sql
psql -U ccdashboard_user -d rtmviewdb -f db/data/04_catalog.sql   # NGC_Site only
# If present:
psql -U ccdashboard_user -d rtmviewdb -f db/data/05_metric_translations.sql 2>/dev/null || true
```

## BackendEmulation Context (Dev/Test Only)

The `BackendEmulationDbContext` models the same 24 RTM tables as `db/schema.sql` for local development emulation (ADR-007). It is **NOT** run on production rebuilds.

Its migration history is stored in `public.__BackendEmulationMigrationsHistory`, separate from the App/Audit histories.

**Rule (PD-008):** The 24 RTM DbSets in BackendEmulation must stay a subset of schema.sql. Any new RTM table must be added to BOTH places.

## EF Migration History Tables

| Table | Schema | Context | Notes |
|-------|--------|---------|-------|
| `__ef_migrations_history` | public | AppDbContext | Main app migrations |
| `__ef_migrations_history` | audit | AuditDbContext | Audit-specific migrations |
| `__BackendEmulationMigrationsHistory` | public | BackendEmulationDbContext | Dev/test only |

These are auto-created by EF and must NEVER be in schema.sql.

## Verification

After rebuild, run Compare-ToBaseline to confirm zero drift:

```powershell
.\db\tools\Compare-ToBaseline.ps1 -Password "your_password"
# Expected: B=0, D=0
```

## Troubleshooting

### 42P01: relation does not exist

If RTM Service fails with `42P01` (relation does not exist), schema.sql was not applied.
Run Step 3 above.

### NGC_GetCellsByDataGrid 42P01 on RTSGrid_TemplateCell

If this specific error occurs, the function references a dropped table.
The fix (R0b, 2026-06-21) removed the dead TemplateCell JOIN from the function.
Re-apply: `psql -f db/functions/04_misc_functions.sql`

### Identity/Audit schema missing

If `CREATE TABLE identity.users` fails with "schema does not exist", Step 2 was not run.
`Web.exe migrate` creates the schemas via EF's EnsureSchema.
