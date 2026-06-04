# Task: Remove RTSGrid_TemplateCell from solution

## Background

`RTSGrid_TemplateCell` is a legacy MSSQL table that was supposed to be imported
via pgloader during initial RTM-M1 migration. It has always been empty (0 rows
in all staging verifications). The SQL function `RTSGrid_GetDataCells` used
INNER JOIN with it → always returned 0 rows → RTM Engine never registered cells
→ `updateGridData` never sent → QueueGrid/DataSlot widgets showed no data.

A hotfix SQL was applied to server 45 via:
  `RTM/staging/fix_templatecell_dependency.sql`

This CC task makes the permanent change in source code.

## Changes required

### 1. RTM/sql/pgsql/03_rtsgrid_read_functions.sql

Replace `RTSGrid_GetDataCells` function body:
- Remove `RTSGrid_TemplateCell` from FROM clause
- Remove `CellTemplateId` join condition
- Simplify WHERE to `c."CellType" = 'Data'`
- Return `NULL::text AS "ColumnMetric"` to preserve column index 9
- Update the CRITICAL DEPENDENCY comment to: "-- TemplateCell dependency removed (always empty in all deployments)"

New function body (exact, preserve column order — C# reads by index):

```sql
DROP FUNCTION IF EXISTS "RTSGrid_GetDataCells"();

CREATE OR REPLACE FUNCTION "RTSGrid_GetDataCells"()
RETURNS TABLE(
    "CellId" integer,
    "CellType" text,
    "GridId" integer,
    "ColumnId" integer,
    "RowId" integer,
    "UnionId" integer,
    "GridUnionId" integer,
    "RowUnionId" integer,
    "Metric" text,
    "ColumnMetric" text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c."CellId",
        c."CellType"::text,
        g."GridId",
        o."ColumnId",
        r."RowId",
        c."UnionId",
        g."UnionId"  AS "GridUnionId",
        r."UnionId"  AS "RowUnionId",
        c."Value"::text  AS "Metric",
        NULL::text   AS "ColumnMetric"
    FROM "RTSGrid_Grid" g
    JOIN "RTSGrid_Row"  r ON r."GridId"    = g."GridId"
    JOIN "RTSGrid_Cell" c ON c."RowId"     = r."RowId"
    JOIN "RTSGrid_Column" o ON o."ColumnId" = c."ColumnId"
    WHERE c."CellType" = 'Data';
END;
$$;
```

### 2. RTM/staging/00_deploy_all_functions.sql

Apply the same change to `RTSGrid_GetDataCells` in this file (it's a copy of the
functions for all-in-one deployment). Search for the existing function block and
replace identically to step 1.

### 3. src/CcDashboard.Domain/Domain/RtsEntities.cs

Remove the `RtsGridTemplateCell` class (lines with the `/// RTSGrid_TemplateCell`
comment block and the class definition below it).

### 4. src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs

Remove:
- `public DbSet<RtsGridTemplateCell> RtsGridTemplateCells => Set<RtsGridTemplateCell>();`
- The `mb.Entity<RtsGridTemplateCell>(...)` configuration block

### 5. EF migration

Create a BackendEmulation migration to drop the table:

```bash
dotnet ef migrations add RemoveRtsGridTemplateCell \
  --context BackendEmulationDbContext \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

The migration should contain:
```csharp
migrationBuilder.DropTable(name: "RTSGrid_TemplateCell");
```

## Verification

```bash
# Build must be clean
dotnet build src/CcDashboard.Web --no-restore

# Verify function change
grep -A 5 "RTSGrid_GetDataCells" RTM/sql/pgsql/03_rtsgrid_read_functions.sql | grep -v "TemplateCell"

# Verify entity removed
grep "TemplateCell" src/CcDashboard.Domain/Domain/RtsEntities.cs && echo "FAIL - still present" || echo "OK - removed"
grep "TemplateCell" src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs && echo "FAIL - still present" || echo "OK - removed"
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
# Exit code must be 0 before committing
```

## Commit message

```
fix: remove RTSGrid_TemplateCell dependency from RTSGrid_GetDataCells

Table was always empty (never populated from MSSQL). INNER JOIN caused
GetDataCells to return 0 rows -> RTM Engine had no cells -> updateGridData
never fired -> QueueGrid/DataSlot showed no data on any deployment.

Fix: remove join, simplify to CellType='Data', return NULL for ColumnMetric
(index 9, unused when index 8 Metric is set). Remove entity from Shell model.
Hotfix already applied to server 45 via fix_templatecell_dependency.sql.
```
