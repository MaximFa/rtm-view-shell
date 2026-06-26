# CC TASK — Prod-Mirror Seed procedure (db/tools/Seed-ProdMirror.ps1)  [⛔ЧП · branch v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. Implements docs/Prod-Mirror-Seed-Plan.md §2 + operator AMEND (full client STRUCTURE on ONE tenant). This task ONLY CREATES + COMMITS the script. It does NOT run it. Running the seed is a SEPARATE, later, §4-gated + seeder-gate-live step.

## 0. Mandatory reads (before any work)
- `.claude/skills/role-dba/role-dba.md` — §A CORE (incl ⛔ЧП block at top) + run §C VERIFY (object-store; mismatch → superseded, don't act).
- `.claude/skills/session-coord/session-coord.md` — §1 runbook, §3 commit discipline, §10 commands, §4 peer-review.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40 mandatory-read rule — load even if unrelated).
- CLAUDE.md: §0.2/§0.3/§0.4/§0.5 (mount discipline), §33 (RTM TenantId model), §36.4 (Workgroup=NGC_Queues.ExternalId; ClassificationId='ALL'), §46 (IDENT — agents EXTERNAL, system users INTERNAL), §35 (PS1 UTF-8 BOM + CRLF, PS5.1-safe), §39 (db module), §43 (ops layout).

## 1. §0.6a INTEGRITY block (Step 0, run first)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# branch must be v3 by object-store: git rev-parse --abbrev-ref HEAD == v3 ; git rev-parse v3
# for every M file: git hash-object <f> vs git rev-parse HEAD:<f> — NOT line counts; restore truncated/NUL via: git show HEAD:<f> > <f>
sync
```
S1 barrier check: if `.coord/push/request.md` exists (content-based, -s + cat) → STOP, do not commit.

## 2. §0.6b BINDING preamble (append to .coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_seed.md | status: open
### DIRECTIVE (spec->CC): create db/tools/Seed-ProdMirror.ps1 per spec below. claim: db/tools/ (db module, file-mode: db/tools/Seed-ProdMirror.ps1). gate: build N/A (PS script); object-store verify + PS5.1 lint. NO push.
```

## 3. CLAIM
- Module: db (file-mode). Files: `db/tools/Seed-ProdMirror.ps1` (NEW). No other file touched.

## 4. TASK — create `db/tools/Seed-ProdMirror.ps1`
A one-time, RE-RUNNABLE prod-mirror data-load tool. **Encoding (CLAUDE.md §35): UTF-8 BOM + CRLF. PS5.1-safe: 2-arg Join-Path only (nest for 3), NO ternary, NO `??`, `$ErrorActionPreference` managed explicitly.**

### Parameters
- `-PgBin`   default `C:\Program Files\PostgreSQL\18\bin` (our PG18; use its pg_restore/pg_dump/psql for ALL ops — newer pg_restore reads the older PG15 custom dump fine).
- `-SuperUser` default `postgres`  ·  `-SuperPassword` (mandatory; via env `PGPASSWORD`, never logged).
- `-DbName`   default `rtmviewdb`   (our migrated working DB — schema stays OURS).
- `-StagingDb` default `rtmviewdb_prodstg`.
- `-DumpPath` default `Installations\prod-mirror\dump-rtmviewdb-202606252308.sql` (PGDMP custom v1.16).
- `-TargetTenantSlug` default `prod-mirror`  ·  `-TargetTenantId` (optional explicit override). **The tenant ruling is a PARAMETER, not code** (see §6 proposal).
- `-Mode` = `Inspect` (default — phases 0-3 only) | `Load` (phases 0-5).
- Common: `$ErrorActionPreference='Stop'` except where pg tools write progress to stderr (wrap those in `='Continue'` + explicit exit-code checks).

### Phase 0 — Preflight (FAIL-STOP)
- Verify pg_restore/pg_dump/psql exist under -PgBin; print versions.
- Verify -DumpPath exists and first 5 bytes == `PGDMP` (custom format). If plain SQL → ABORT with guidance (this tool is custom-format only).
- Verify -DbName reachable (psql `SELECT 1`).
- Print a banner: Mode, DbName, StagingDb, DumpPath, TargetTenantSlug.

### Phase 1 — Backup OUR DB FIRST (FAIL-STOP safety, both modes)
- `pg_dump -Fc -U postgres -d <DbName> -f Installations\prod-mirror\our_pre_seed_<yyyyMMdd-HHmmss>.dump`. Abort all if it fails.

### Phase 2 — Restore prod backup into STAGING (throwaway; full restore OK there)
- `dropdb --if-exists <StagingDb>`; `createdb -O postgres <StagingDb>`.
- `pg_restore --no-owner --no-privileges --no-acl -d <StagingDb> <DumpPath>` as postgres. Treat restore NOTICEs/benign role-missing as expected (§B 2026-06-19 idempotent NOTICEs); FAIL-STOP only on a non-zero exit WITH hard errors (capture stderr to Installations\prod-mirror\staging_restore_<ts>.log).

### Phase 3 — INSPECT (Mode=Inspect stops here)  → Installations\prod-mirror\inspect_<ts>.txt
For EACH chain table (list in §5), against STAGING:
- `SELECT count(*)`; `SELECT DISTINCT "TenantId"` (where the table has TenantId — RTSData_ChatMessage has NONE, §B dba-0620).
- Column-drift map vs OUR DbName via `information_schema.columns`: intersection / staging-only / ours-only.
CITE every row count + the DISTINCT TenantId set in the report. Determine the single CLIENT source TenantId (the tenant carrying RTSData_Interaction rows). If >1 client tenant → STOP and escalate (operator picks one).

### Phase 4 — Selective DATA-ONLY load STAGING → our DbName (Mode=Load only; gated by §7 SEQUENCE)
All inside ONE psql transaction on DbName, as postgres, with `SET session_replication_role = replica;` (disables FK triggers so order is forgiving; reset to `origin` at end).
1. Resolve TARGET tenant: if -TargetTenantId given use it; else `SELECT "Id" FROM tenants WHERE "Slug"='<TargetTenantSlug>'`; if absent → create the tenant row + a default tenant_settings row (status Active). (Tenant/tenant_settings are SYSTEM rows we add, not test CC data.)
2. TRUNCATE OUR rows in EXACTLY the §5 load tables (only those), for the TARGET tenant scope where the table has TenantId, else table-wide for non-tenant tables. NEVER truncate: identity.* (superadmin/login), widget_catalog, RTSGrid*/RTSUserGrid*, report_* , tenant_settings(other tenants), tenants(other rows).
3. For each table in §5 FK ORDER: file-based `\copy` with EXPLICIT INTERSECTION column list + TenantId RE-STAMP:
   - source: `psql -d <StagingDb> -c "\copy (SELECT <intersection cols, but emit '<targetTenantId>'::uuid AS \"TenantId\"> FROM \"<t>\" WHERE \"TenantId\"='<srcTenantId>') TO 'tmp_<t>.csv' WITH (FORMAT csv, HEADER false)"`
   - target: `psql -d <DbName> -c "\copy \"<t>\" (<intersection cols>) FROM 'tmp_<t>.csv' WITH (FORMAT csv, HEADER false)"`
   - **File-based `\copy` (NOT a PowerShell pipe between two psql processes — PS pipe corrupts COPY data).** Delete tmp_*.csv after.
   - Non-tenant table RTSData_ChatMessage (if present): load as-is (no TenantId column); else skip.
   - ClassificationId integrity (§36): after loading NGC_BusinessUnitQueueClassification, assert all loaded rows have ClassificationId='ALL' (warn+report if not).
4. **NO provenance marker row** (coordinator §4 ruling 2026-06-25T23:10 — backend FORK1=(B): NO `seed_provenance` table). The DATA-PRESENCE under the working tenant IS the sentinel; backend's config flag `Seed:SampleData=false` is the PRIMARY rebuild gate. The load writes NO marker — it only loads the data under the working tenant. (Backend owns the gate; this script must NOT invent any sentinel schema.)
5. `SET session_replication_role = origin;` COMMIT.
6. hist_* : the 234 backup (pre-reports) has NO hist_queue_intervals/hist_agent_intervals → they are NOT loaded here; our HistoricalAggregationService re-aggregates over the loaded RTSData_* on app start (note this in output).

### Phase 5 — VERIFY (Mode=Load)  → Installations\prod-mirror\load_proof_<ts>.txt
- For each loaded table: target count (for target tenant) == staging count (for src tenant). Mismatch → FAIL.
- HARD ACCEPTANCE (operator AMEND): pick ONE loaded permission_group on the target tenant; run the BU∩PG scope resolution and CITE it yields ≥1 queue/agent WITH ≥1 RTSData_* row:
  `permission_groups → pg_business_units → NGC_BusinessUnit → NGC_BusinessUnitQueueClassification (ClassificationId='ALL') → NGC_Queues → RTSData_Interaction` (and the SG→AG→agent branch via NGC_BusinessUnitSupergroup→NGC_SupergroupAgentgroup→NGC_AgentGroups→NGC_UserAgentgroup→RTSData_UserStatus). Emit the chosen PG id + the resolved queue/agent ids + the RTSData row counts. If the chain yields ZERO → FAIL LOUD (the load did not achieve visible data).

## 5. Chain tables + FK LOAD ORDER (parents first)
1. NGC_Site
2. NGC_BusinessUnit
3. NGC_Supergroup
4. NGC_AgentGroups
5. NGC_Queues  (+ `queues` reference table if it carries rows in staging)
6. NGC_BusinessUnitQueueClassification (ClassificationId='ALL', §36)
7. NGC_BusinessUnitSupergroup
8. NGC_SupergroupAgentgroup
9. NGC_UserAgentgroup   (agent = EXTERNAL id, §46 — NOT identity.users)
10. permission_groups
11. pg_business_units, pg_queues, pg_skills, pg_agent_supergroups
12. RTSData_Interaction
13. RTSData_UserStatus
14. RTSData_ChatMessage (only if present; no TenantId — load as-is or skip)
- NOT loaded: identity.users (KEEP our superadmin/logins — agents are external ids), tenants/tenant_settings (we ADD the target tenant only), widget_catalog, RTSGrid*/RTSUserGrid*, report_*, hist_* (re-aggregated).

## 6. TenantId mapping — RULED 2.4b (coordinator §4 2026-06-25T23:10) — re-stamp to OUR working tenant
- **Target = a DEDICATED working tenant, slug `prod-mirror`** (default `-TargetTenantSlug`). Re-stamp the ENTIRE loaded chain (NGC_*, all mappings, permission_groups, pg_*, RTSData_*) to that ONE tenant's TenantId. Resolve-or-create the tenant + a tenant_settings row (Phase 4.1).
- WHY dedicated (not `platform`): (a) ISOLATION — prod-mirror data stays out of the `platform` system tenant (superadmin/system seeds), so backend's DATA-PRESENCE idempotency bites cleanly per-tenant and rebuilds never mix; (b) **SF-BI-001 proof** — a dedicated tenant can host the re-stamped PGs AND a scoped PG-login, so we prove scope ACTUALLY FILTERS (Superadmin alone only proves bypass). Superadmin (on `platform`) SWITCHES to `prod-mirror` (ARCH-02) to view.
- **Scoped login for SF-BI-001 = BACKEND** (identity.users is internal/login + passwords — §46, backend territory, NOT this script). FLAG: backend provisions ONE test login user on the `prod-mirror` tenant assigned to one loaded permission_group. This script's Phase-5 proves the BU∩PG chain by SQL regardless of any login.
- Parameter override available (`-TargetTenantId`) — value is config, no code change.

## 7. SEQUENCE / gates (DO NOT bypass)
- `Mode=Inspect` may run after §4-bless (read-only on staging; still backs up our DB first).
- `Mode=Load` MUST NOT run until **backend's seeder-gate is LIVE** — config flag `Seed:SampleData=false` (PRIMARY) + data-presence idempotency-by-real-rows (FORK1=B, no marker table), Plan §3 — else the post-load app start re-seeds test data over the mirror.
- ЧП: NO chat run code-box until coordinator §4-bless. This CC task only CREATES + COMMITS the script.

## 8. Acceptance for THIS CC task (authoring only)
- `db/tools/Seed-ProdMirror.ps1` exists, UTF-8 BOM + CRLF, 0 NUL bytes, PS5.1-safe (2-arg Join-Path, no ternary/??), implements phases 0-5 + params above.
- Self-lint: `powershell -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('db\tools\Seed-ProdMirror.ps1',[ref]$null,[ref]$null); 'PARSE-OK'"` returns PARSE-OK (or `Get-Command -Syntax` parse) — no syntax errors on PS5.1.
- NO execution of any seed/restore/load in this task.

## 9. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic open x, retry 5×60s, content-based stale check).
- `pre-commit-check.sh`; narrow explicit `git add db/tools/Seed-ProdMirror.ps1` (NEVER `git add -A`/dir-wide; do NOT sweep the untracked 20260606100233 or Installations/*).
- Commit prefix `db:` — message `db: Seed-ProdMirror.ps1 — one-time prod-mirror data-load (ЧП, inspect+load, §4-blessed)`.
- §0.6 post-commit verify (status clean, `git show HEAD:db/tools/Seed-ProdMirror.ps1 | wc -l` == working), journal line (`bash tools/cc_post_commit.sh dba-0625 <hash>` if present, else Python+fsync journal+flush+lock-release), §0.7 re-sync from HEAD. NO push.

## 10. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files db/tools/Seed-ProdMirror.ps1 (<lines>) . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
