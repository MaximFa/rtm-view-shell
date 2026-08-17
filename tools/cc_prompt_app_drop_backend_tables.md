# CC task — App migration: drop App-owned backend tables so `migrate` = shell-only (Design B)

> **Goal:** Make a fresh-install `CcDashboard.Web.exe migrate` (Production) produce **only shell tables**
> (App + Audit contexts). The backend tables (RTSGrid_*, RTSData_*, NGC_*, RTSUserGrid_*) must be left
> for `db/schema.sql` to create (ADR-007 / Design B). Today the App migration chain still historically
> CREATES stale versions of those tables (e.g. `RTSGrid_Metric` **without** `CatalogCategory`,
> `NGC_*`, `RTSUserGrid_*`), and `App/20260525223134_SeparateBackendTablesToBeDb` was a **NO-OP** that
> excluded them from the model snapshot but never dropped them. This task completes that intent.
>
> Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Territory: backend (App migrations).

## Mandatory — read before starting
Read file: .claude/skills/role-backend/role-backend.md   (§A CORE, §C VERIFY)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## INIT — §0.6a integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
  [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```

## GROUNDING (verified 2026-07-13 by diagnosis subagent)
- 3 DbContexts: `AppDbContext`, `AuditDbContext`, `BackendEmulationDbContext` (beDb).
  beDb owns the backend tables + uses a **separate** history table `__BackendEmulationMigrationsHistory`.
- `DatabaseInitializer.cs` (~line 36-44): App + Audit `MigrateAsync` run ALWAYS; **beDb `MigrateAsync` runs only in Development/Testing**. So in Production, `migrate` = App + Audit only.
- App migration chain creates the STALE backend tables:
  `RTSGrid_Metric` (in `App/…RenameRtsGridMetricToPascalCase`, orig InitialCreate),
  `NGC_*` (NgcConfiguration, NgcQueueAgentGroupTables), `RTSUserGrid_*` (AddRtsUserGridTables).
  `CatalogCategory` + `RTSData_Interaction` appear in NO App migration.
- `db/schema.sql` is the AUTHORITATIVE backend schema (26 CREATE TABLE, backend-only, excludes tenants/identity/audit). It has `RTSGrid_Metric` WITH `CatalogCategory` + `RTSData_Interaction`.

## THE WORK
1. Determine the authoritative backend table set = every table `db/schema.sql` creates.
   Read `db/schema.sql`, extract each `CREATE TABLE [schema.]"Name"` → the list of backend tables
   (public schema; e.g. `RTSGrid_Metric`, `RTSGrid_MetricTranslation`, `RTSData_Interaction`,
   `RTSData_UserStatus`, `NGC_*`, `RTSUserGrid_*`, `RTSGrid_*`, `NGC_Site`, etc.). This list is the
   single source — do not hand-guess; derive it from schema.sql.

2. Add a NEW **App** migration (empty model diff — the snapshot already excludes these):
   ```
   dotnet ef migrations add DropAppOwnedBackendTables \
     --project src/CcDashboard.Infrastructure --startup-project src/CcDashboard.Web \
     --context AppDbContext --output-dir Migrations/App
   ```
   The generated Up/Down will be empty (model already excludes backend tables). **Hand-edit** the
   migration's `Up(MigrationBuilder mb)` to raw-SQL drop every backend table from step 1:
   ```csharp
   // Design B (ADR-007): backend tables are owned by db/schema.sql, NOT the App context.
   // The App chain historically created stale versions; drop them so `migrate` = shell-only.
   // Prod: schema.sql creates the real ones next. Dev/Test: beDb.MigrateAsync (runs AFTER App)
   // recreates them — so dev remains correct.
   mb.Sql(@"DROP TABLE IF EXISTS ""RTSGrid_Metric"" CASCADE;");
   mb.Sql(@"DROP TABLE IF EXISTS ""RTSData_Interaction"" CASCADE;");
   // … one DROP TABLE IF EXISTS <name> CASCADE per backend table from schema.sql …
   ```
   `Down(...)` = leave empty (forward-only; add an explanatory comment). Do NOT recreate.

3. **Ordering proof (reason about it, state it in the commit body):** within one `migrate`,
   App migrations (incl. this drop) run BEFORE beDb. So Dev/Test: App creates shell + drops backend →
   beDb recreates backend → correct. Prod: App creates shell + drops backend → beDb skipped →
   backend absent → `db/schema.sql` creates them → correct. No collision either way.

4. Do NOT touch AuditDbContext, beDb migrations, entities, or the model snapshot logic.

## VERIFY / DoD (report NUMBERS)
- **Build:** `dotnet build CcDashboard.sln` → **0 errors** (report warning count).
- **Object-store:** the new migration exists under `Migrations/App/`, Up() drops every table in
  `db/schema.sql`, Down() empty. App model snapshot unchanged (no backend tables re-added).
- **Fresh-DB proof (if a scratch Postgres is available via Soma/local):** create an empty DB →
  run `CcDashboard.Web.exe migrate` with `ASPNETCORE_ENVIRONMENT=Production` → assert
  `to_regclass('public."RTSGrid_Metric"')` IS NULL and `to_regclass('public."RTSData_Interaction"')`
  IS NULL and `to_regclass('public."tenants"')` IS NOT NULL (shell present, backend absent).
  Then `psql -f db/schema.sql` → applies with NO "already exists" error. If no scratch DB is
  reachable, state that and rely on the object-store + build proof.
- **Dev-unaffected:** confirm by reasoning (ordering proof §3) that Development still ends with backend tables present (beDb migrate after App).

## COMMIT (commit.lock + journal + NO push)
- `bash tools/pre-commit-check.sh` → exit 0. commit.lock (retry 5×60s). Stage only the new migration file(s).
- Commit `fix(web): App migration DropAppOwnedBackendTables — migrate now yields shell-only tables; backend owned by db/schema.sql (Design B / ADR-007) [backend]`. Include the ordering proof in the commit body.
- §0.6 post-commit verify. **NO push.** §0.7 re-sync from HEAD.

## §0.6b CAPTURE → role-backend §B
"Fresh-install `migrate` (prod) produced an incomplete backend schema because the App chain still CREATED stale backend tables (RTSGrid_Metric w/o CatalogCategory) while beDb.MigrateAsync is gated to dev/test and schema.sql owns the real backend (ADR-007). SeparateBackendTablesToBeDb was a NO-OP (snapshot-only). Fix: an App migration that DROP TABLE IF EXISTS all schema.sql-owned backend tables → migrate = shell-only; schema.sql (prod) / beDb-migrate (dev, runs after App) create them. Rule: when a table's ownership moves out of a context, add a DROP migration in that context — excluding it from the snapshot is not enough."
