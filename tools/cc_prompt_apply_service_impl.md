# CC Task — Metrics Hot-Reload apply-service IMPL (leg 3) + ledger DDL

> Session devops-2-0607. Implements the 3rd hot-reload leg from docs/metrics-apply-endpoint-contract.md
> (backend compile + shell deploy-tab already committed). DRAFT for §4. Push is operator-parked → this is
> push-independent build work; ONE db: + web: commit set, NO push.

## 0. §0.6a integrity check FIRST. 0b. §40 skill reads. Standard preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode): `src/CcDashboard.ApplyService/` (NEW project dir), `db/migrations/20260609_010_metric_deploy_log.sql` (NEW),
`src/CcDashboard.Domain/Domain/Metrics/MetricDeployLog.cs` (NEW), `src/CcDashboard.Infrastructure/Persistence/Configurations/MetricDeployLogConfiguration.cs` (NEW).
`CcDashboard.sln` — add the new project ref. §4-RESOLVED: no separate sequencing (no other session claims sln; both other impl legs already committed). CLAIM CcDashboard.sln for the commit.lock DURATION ONLY (edit inside the lock, release after).
- S1 marker-based barrier (`grep -q "FREEZE ACTIVE" .coord/push/request.md` → STOP). S2 coord_check_claims. S3 commit.lock + /tmp/acquire_lock.py (sync block). S4 cc_post_commit.sh.
## Git push — DO NOT (§37). §0.3 Python+fsync, Edit BANNED. §35 BOM where PS1/SQL for psql.

## RESOLVED DESIGN DECISIONS (bake in — these close the spec §12 open items)
- LEDGER = SIBLING table `public.metric_deploy_log` (per-metric grain), NOT folded into db_patch_history (file grain — wrong granularity). The migration FILE still self-records in db_patch_history (§38a).
- HOSTING = NEW minimal ASP.NET Core service project `src/CcDashboard.ApplyService` (Kestrel, 127.0.0.1 ONLY), a SEPARATE process from Shell (honours contract: apply is NOT in the Shell process). Runs under a dedicated catalogue-owner DB connection (distinct from Shell's app-user connection — Shell keeps NO catalogue-write grant, CODE-03).
- COMPILE-AGNOSTIC (Option A): the service NEVER calls RTM/compileMetrics. Shell fires compile from the response.

---

# FILE 1 — db/migrations/20260609_010_metric_deploy_log.sql
- `CREATE TABLE IF NOT EXISTS public.metric_deploy_log ( "MetricId" uuid PRIMARY KEY, "DeployedAt" timestamptz NOT NULL, "SourceCommit" text NULL );`
  (Cross-tenant like RTSGrid_Metric / WGT-01 — NO TenantId column.)
- `GRANT SELECT, INSERT ON public.metric_deploy_log TO ccdashboard_user;` (Shell reads for the delta; apply-owner writes — see role note below).
- End with §38a self-record:
  `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260609_010_metric_deploy_log') ON CONFLICT (migration_name) DO NOTHING;`
- BOM-less UTF-8 for psql -f. Idempotent (IF NOT EXISTS / ON CONFLICT).
- After write: also add to db/schema.sql via Export-All in a LATER step? NO — schema.sql regen is a separate post-task (do not touch schema.sql here; just the migration). Note it in the report.

# FILE 2 — src/CcDashboard.Domain/Domain/Metrics/MetricDeployLog.cs
Plain entity: `Guid MetricId; DateTime DeployedAt; string? SourceCommit;`. No navigation. (UTC per IDateTimeProvider at write time.)

# FILE 3 — src/CcDashboard.Infrastructure/Persistence/Configurations/MetricDeployLogConfiguration.cs
`IEntityTypeConfiguration<MetricDeployLog>` → table `metric_deploy_log` (schema public), PK MetricId, timestamptz, no GQF (cross-tenant). Register in the DbContext used by the apply-service (see FILE 5). Do NOT add to the Shell AppDbContext write-surface.

# FILE 4 — src/CcDashboard.ApplyService/CcDashboard.ApplyService.csproj
net8.0 web (Microsoft.NET.Sdk.Web), minimal API. ProjectReferences: CcDashboard.Infrastructure, CcDashboard.Contracts, CcDashboard.Domain. (NOT referenced by Web/Api — standalone host.)

# FILE 5 — src/CcDashboard.ApplyService/Program.cs  (+ ApplyMetricsHandler.cs)
- Kestrel: `builder.WebHost.UseUrls("http://127.0.0.1:<port-from-config>")` — 127.0.0.1 ONLY (never 0.0.0.0).
- Config (appsettings.json, placeholders; real values via Data Protection / Credential Manager, CODE-05/CODE-06):
  `CatalogueOwner:ConnectionString` (catalogue-owner role, sslmode=verify-full), `ApplyService:Token`, `ApplyService:PackageMigrationsDir`, `ApplyService:ManifestPath`.
- A dedicated `ApplyDbContext` (or reuse AppDbContext with the catalogue-owner connection string) wired to CatalogueOwner:ConnectionString. This is the ONLY component with catalogue-write creds.
- Endpoint `POST /apply-metrics` (request/response EXACTLY per contract §5/§6):
  1. AuthN: `Authorization: Bearer <token>` constant-time compare vs config; else 401. (Superadmin assertion is Shell-side; service logs `triggeredBy`.)
  2. Validate `migrationRef`: must be a plain filename existing in PackageMigrationsDir; reject path traversal (`..`, separators) → 400.
  3. Load manifest (ManifestPath) → map MetricId → metricType (RT|History). If a requested MetricId missing from manifest → add to `warnings`.
  4. ONE transaction (ApplyDbContext, `BeginTransactionAsync`):
     a. Execute the migration file body via `ExecuteSqlRawAsync` (the migration does the idempotent RTSGrid_Metric INSERT ON CONFLICT — service does NOT hand-craft catalogue INSERTs). Migration must be tx-safe (no CONCURRENTLY).
     b. For each requested MetricId: `INSERT INTO metric_deploy_log (...) VALUES (...) ON CONFLICT (MetricId) DO NOTHING` (parameterised — CODE-01; collect rows actually inserted as ledgerRows).
     c. db_patch_history self-record for `migrationRef` (ON CONFLICT DO NOTHING) — defense-in-depth even though the migration self-records.
     d. Commit. On ANY exception → rollback → 500 `{success:false,error}` (nothing half-applied).
  5. AFTER commit success: write audit `System.MetricsDeployed` via the SEPARATE AuditDbContext (AUD-01 — never in the business tx), Details = {migrationRef, sourceCommit, appliedMetricIds, triggeredBy}. Return its id as `auditId`.
  6. Compute `appliedRtMetricIds` = requested MetricIds whose manifest metricType==RT (history excluded — R1 source-of-truth, contract §7).
  7. Response 200 `{success:true, appliedRtMetricIds[], ledgerRows[], warnings[], auditId}`.
- Structured logging (Serilog, MAINT-02): no token/secret in logs.
- DTOs in Contracts: `ApplyMetricsRequest {packageRef, migrationRef, metricIds[], triggeredBy}`, `ApplyMetricsResponse {success, appliedRtMetricIds[], ledgerRows[], warnings[], auditId, error}`, `MetricLedgerRow {metricId, deployedAt, sourceCommit}`.

# FILE 6 — src/CcDashboard.ApplyService/appsettings.json
Placeholders only (no real secrets — CODE-05). Bind port (e.g. 5099), Token "REPLACE_AT_DEPLOY", CatalogueOwner connection placeholder, PackageMigrationsDir/ManifestPath placeholders.

# FILE 7 — DB role note (in the migration header comment, NOT executed here)
The apply-service connects as a catalogue-owner role with INSERT on RTSGrid_Metric + metric_deploy_log + db_patch_history + the audit insert. Shell's ccdashboard_user gets only SELECT on metric_deploy_log (+ existing). Provisioning the catalogue-owner role/grant = a deploy-step follow-up (flag).

---

## Tests (tests/CcDashboard.Tests.Integration — Testcontainers Postgres)
- apply twice (same migrationRef) → both success; 2nd returns ledgerRows for already-present = empty + warning; RTSGrid_Metric unchanged (idempotent).
- response appliedRtMetricIds = RT-only (a History MetricId in the request is NOT in appliedRtMetricIds).
- bad migration (syntax error) → 500, tx rolled back, metric_deploy_log untouched, no audit.
- missing/!127.0.0.1 token → 401.
Unit: token constant-time compare; path-traversal rejection.

## Self-tests (no server)
- `dotnet build CcDashboard.sln` 0 errors (after sln add — see SHARED TOUCH).
- grep: Program.cs binds 127.0.0.1 (not 0.0.0.0); Bearer check present; ExecuteSqlRawAsync inside a transaction; metric_deploy_log INSERT parameterised; compileMetrics / RTM NOT referenced anywhere in ApplyService (compile-agnostic proof).
- migration: BOM-less; ends with db_patch_history self-record; IF NOT EXISTS.

## DEPLOY follow-up (FLAG — NOT in this task)
Apply-Server45Upgrade.ps1 + Install must publish + register + start CcDashboard.ApplyService (localhost) and provision CatalogueOwner connection + Token. Separate orchestrator-patch task after this lands.

## Commit — TWO commits per §39.3 (§4-DECIDED), inside ONE commit.lock window
pre-commit-check.sh → 0 ; acquire commit.lock (/tmp/acquire_lock.py).
COMMIT 1 (db:): `git add db/migrations/20260609_010_metric_deploy_log.sql` → `git commit -m "db: metric_deploy_log ledger table (hot-reload apply-service)"`.
COMMIT 2 (web:): `git add src/CcDashboard.ApplyService db/.. src/CcDashboard.Domain/Domain/Metrics/MetricDeployLog.cs src/CcDashboard.Infrastructure/Persistence/Configurations/MetricDeployLogConfiguration.cs CcDashboard.sln <tests>` → `git commit -m "web: CcDashboard.ApplyService hot-reload apply endpoint + ledger entity"`.
§0.6 verify each → `bash tools/cc_post_commit.sh devops-2-0607 <hash>` per commit (journal+flush+lock-release; release the lock only AFTER both commits) → HEAD re-sync (PD-007). NO push (unpushed→5, rides next barrier).

## Report back
files created ; dotnet build result ; the 5 grep proofs (127.0.0.1, Bearer, tx-wrapped ExecuteSqlRaw, parameterised ledger insert, no-RTM-ref) ; migration BOM + self-record ; test results (or Testcontainers-unavailable note) ; sln-touch status. NO push.
