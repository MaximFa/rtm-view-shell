---
role: dba
project: RTM View Shell
version: 0.1
last_verified: 2026-06-19T09:30:00Z
owner: dba
reviewer: curator
---
# role-dba — RTM DBA role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (db/, RTM/sql/, git log --oneline db/), NOT session narrative.
> Standard: .coord/protocols/role-skill-standard.md.

## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
### ⛔ ЧП / EMERGENCY MODE — ACTIVE (declared 2026-06-25 coordinator-0624; REMOVE on operator lift)
Release is bug-ridden (dashboards) + the reports version blocking its fixes is in catastrophic state → emergency until the operator lifts ЧП.
1. NO corner-cutting; ANY detail (ESPECIALLY visual) = critically RED — every defect is a blocker, no "minor".
2. NO decision around the coordinator; every fork → coordinator → operator (ONE at a time, by importance, plain language).
3. NO unsanctioned runs: do NOT hand the operator a chat CC run-prompt code-box UNTIL the coordinator's §4 bless.
4. Coordinator PERSONALLY visual-verifies EVERY closed gap (not object-store/report alone).
5. Verify on REAL prod-mirror data (234 backup, RTSData_*); our env = a FROZEN data-mirror of prod; our migration package = our migrated DB. One-time seed from the backup.
6. Protocol shorthand: `.` = `коорд: входящие`; `..` = "check the result" (specs know it).
7. Coordinator + operator steer the recovery out of the dive.

Role: Database schema, migrations, functions, Compare-ToBaseline, metrics. Owns: db/, RTM/sql/.
Does NOT write application code — code changes flow via CC prompts.

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **Apply-user for DDL migrations = owner/superuser (postgres), not app-user.**
   ccdashboard_user gets "must be owner" on ALTER TABLE / CREATE INDEX. Run the WHOLE
   migration list as postgres for consistent privilege. Read-only Compare gate stays app-user.
   · SOURCE: dba-0610 STEP-4 apply-user confirm 2026-06-19

2. **§38a: Migrations self-record in db_patch_history ledger.**
   Every NEW migration MUST end with INSERT INTO db_patch_history. Pre-ledger migrations
   (before _002_db_patch_history) cannot self-record — permanent D-drift noise.
   · SOURCE: CLAUDE.md §38a, 234 Compare 114916 D=4

3. **Compare-ToBaseline is MANDATORY before any deploy (E1 gate).**
   Yields the server-specific -MigrationList AND catches runtime-critical drift.
   · SOURCE: 234+45 deploys 2026-06-19

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-19 · Apply-user for DDL migration set = OWNER/superuser (postgres), NOT app user. DML-only migs could use app user, but run the WHOLE list as postgres for one consistent privilege. · SOURCE: dba-0610 STEP-4 apply-user confirm · status: active
- 2026-06-19 · Idempotent-migration NOTICEs ("already exists, skipping" / "does not exist, skipping") on already-populated server are EXPECTED, not errors — the guards (IF NOT EXISTS / to_regclass / ON CONFLICT) make re-apply safe. · SOURCE: 234 STEP-4b log (all 10 migs [OK] amid NOTICEs) · status: active
- 2026-06-19 · Pre-ledger migrations (created before _002_db_patch_history) CANNOT self-record (§38a) -> permanent D-drift (MISSING/unknown) in Compare even when applied+effective. Optional 1-row-each ledger-backfill to reach D=0. · SOURCE: 234 Compare-after 114916 (D=4: _604_001/_605_004/_606_005/_606_008) · status: active

- 2026-06-21 · A schema.sql carve is INCOMPLETE unless mirrored across db/data seeds AND rebuild tooling — static schema verify (table count, FK) passed GREEN while the FUNCTIONAL rebuild FAILED because db/data still seeded carved tables (tenants/identity/widget_catalog) + Restore-All wrote BOM temp files + WIN1252 client. Rule: a carve = schema + seed + tooling; always run the functional rebuild proof, never trust static verify alone. · SOURCE: R0b proof FAIL 2026-06-21, R0c fix · status: active
- 2026-06-21 · FUNCTION SINGLE-SOURCE: routines must live ONLY in db/functions/ (per §39.1); schema.sql = table DDL. Duplicating functions in BOTH (pg_dump --schema-only without -t pulls them into schema.sql) causes silent drift: rebuild applies db/functions/ LAST (CREATE OR REPLACE wins) so runtime is correct, but Compare [A] flags the stale schema.sql copies. Compare [A] baseline must = schema.sql + db/functions/ (not schema.sql alone) to be carve-aware. Verify CREATE (not mere DROP) when deciding if a fn exists; check signature (overloads coexist). · SOURCE: R0c rebuild-proof Compare A=12 2026-06-21, R0d fix · status: superseded-by:R0e
- 2026-06-21 · Compare [A] for a tables+functions split repo: dump the SERVER tables-only via the SAME -t whitelist as schema.sql and line-diff tables vs schema.sql; validate ROUTINES by name+identity-args presence (pg_get_function_identity_arguments) vs db/functions CREATE set + prokind ([B]) — NEVER line-diff raw db/functions source vs pg_dump output (pg_dump canonicalizes -> every routine double-counts as missing+extra; my R0d concat blew A 12->106). On a fresh rebuild function drift is impossible by construction; presence/prokind is the meaningful routine check. · SOURCE: R0d (iv) wrong, R0e fix, proof delta 20260621-204906 · status: active
- 2026-06-25 · ref: visual-check prep runbook = **docs/Visual-Test-Preflight.md** (profiles A=rebuild / B=running; shared gate Chrome→Soma /health:5199→Shell /ops/health.up→restart×3→start). Use when running or awaiting a visual check. · SOURCE: docs/Visual-Test-Preflight.md · status: active

- 2026-06-25 · PS native pg-tool call whose stderr is PIPED to a cmdlet (| Out-Null / | Tee-Object) under $ErrorActionPreference='Stop' turns BENIGN stderr (dropdb NOTICE) into a terminating NativeCommandError; variable-capture ($x = & tool 2>&1 + $LASTEXITCODE) is safe. FIX: route native calls through an Invoke-Native helper (EAP='Continue' local + $LASTEXITCODE), never pipe native stderr under Stop. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 (dropdb L260) · status: active
- 2026-06-25 · `Join-String` is a PS7-only cmdlet — absent in Windows PowerShell 5.1; use the `-join` OPERATOR (wrap source in @() for single-item uniformity). Grep new PS1 for Join-String before ship. · SOURCE: Seed-ProdMirror.ps1 L556/L571 · status: active

- 2026-06-25 · PowerShell STRIPS embedded double-quotes when passing `psql -c "...\"Ident\"..."` to the native exe → PG PascalCase identifiers fold to lowercase → `relation "ident" does not exist` (proven: `FROM "NGC_Site"` echoed as `FROM NGC_Site`). FIX: never pass quoted identifiers via -c; write the query to a temp .sql and run `psql -f`. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 · status: active
- 2026-06-25 · PS5.1 `Set-Content -Encoding UTF8` writes a BOM; `psql -f` then errors `syntax error at or near "ï»¿"`. Write SQL files UTF-8 NO-BOM via [System.IO.File]::WriteAllText($p,$sql,(New-Object System.Text.UTF8Encoding($false))). · SOURCE: prodmirror_diag.sql 2026-06-25 · status: active

- 2026-06-25 · Under `Set-StrictMode -Version Latest`, `$x.Count` THROWS PropertyNotFoundStrict when $x is a scalar (single-item) or $null (empty) — PowerShell unwraps single/empty @() on FUNCTION RETURN. FIX: assign function/pipeline results via `$x = @(...)` AND wrap every count read as `@($x).Count`. Leave hashtable .Keys.Count / property .Count. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 · status: active

- 2026-06-25 · Prod-mirror seed = 2.4a (operator): load under the ORIGINAL prod TenantId, NO re-stamp; target tenant == source. Create the `tenants` row with the ORIGINAL id (ON CONFLICT Id DO NOTHING) + tenant_settings. Single source tenant 019e03e9 (orphan 019e0422 excluded by WHERE TenantId=src). · SOURCE: coordinator §4 2026-06-26 (operator 2.4a) + inspect_20260626-020044 · status: active

- 2026-06-25 · RTM CC tables (NGC_*/RTSData_*) have GLOBAL business-key PKs with NO TenantId (NGC_Site=SiteId, NGC_BusinessUnit=BusinessUnitId, RTSData_Interaction=(InteractionId,Segment,OnDate,ServerId,Workgroup),...). A per-tenant DELETE cannot clear cross-tenant PK collisions (our seed SiteId='IL' vs prod's). Prod-mirror load (operator A) = TRUNCATE these global-PK tables (one multi-table stmt under session_replication_role=replica, no CASCADE), DELETE-by-tenant only for uuid/PG-scoped tables (permission_groups/pg_*). · SOURCE: Mode=Load NGC_Site PK clash 2026-06-26 + schema.sql PKs · status: active

- 2026-06-25 · RTM chain real columns (verified schema.sql + live proof): NGC_Queues key = "ExternalId" (=Workgroup §36.4), NO "QueueId"; NGC_BusinessUnitQueueClassification."QueueId"(varchar)=NGC_Queues."ExternalId". NGC_AgentGroups = Id/ExternalId/Name (NO AgentGroupId/Name); NGC_SupergroupAgentgroup."AgentgroupId" & NGC_UserAgentgroup."AgentgroupId" (varchar) = NGC_AgentGroups."ExternalId"; NGC_UserAgentgroup."UserId"=RTSData_UserStatus."UserId" (external, §46). Verify chain joins against schema, NOT CLAUDE.md §6 (§6 names stale). · SOURCE: Seed-ProdMirror Phase-5 + manual proof 2026-06-26 (PG Administrators→Q001-Q005, 180-240 interactions) · status: active

- 2026-06-25 · hist_agent_intervals aggregation reads RTSData_UserStatusLog (StartTime time-series), NOT RTSData_UserStatus (current snapshot, no usable history). Prod-mirror agent-history load MUST include RTSData_UserStatusLog (has TenantId + StartTime/EndTime); omitting it → hist_agent_intervals=0 while queue side is fine. Always cross-check the aggregation service's source tables against the load set. · SOURCE: HistoricalAggregationService.cs:153 + backfill hist_agent_intervals=0 2026-06-26 · status: active

- 2026-07-02 · Restored prod backup (234) has tables PRESENT but __EFMigrationsHistory EMPTY -> EF MigrateAsync retries InitialCreate -> 'relation already exists' -> app crash. If ALL current-model objects already exist (verify via to_regclass on each migration's signature object), BASELINE the history: INSERT all applied MigrationIds (ProductVersion from Designer, e.g. 8.0.16) ON CONFLICT DO NOTHING -> migrate no-ops -> app starts. Confirm the object-existence state FIRST; if only PARTIAL, insert only the truly-applied set + let migrate apply the rest (never insert an ID whose objects are missing -> hides drift). · SOURCE: prod-mirror EFMigrationsHistory=0 + all 6 signature objects present 2026-07-02 · status: active
## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Test-Path "db/tools/Compare-ToBaseline.ps1"` — must be True
2. `Select-String -Path "db/schema.sql" -Pattern "CREATE TABLE"` — expect count >10
3. `Test-Path "db/migrations"` — must be True
4. `Select-String -Path "CLAUDE.md" -Pattern "db_patch_history"` — must exist (§38a)

## §D REFERENCE
Schema: db/schema.sql, db/functions/*.sql.
Migrations: db/migrations/*.sql (self-record per §38a).
Tooling: db/tools/Compare-ToBaseline.ps1, db/tools/Export-All.ps1.
