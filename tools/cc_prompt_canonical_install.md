# CC task — canonical fresh-install (Design B): one repeatable DB+app provisioning, with all punch-list fixes

> **Goal:** a clean, repeatable, git-native fresh install on a NEW server — no dumps, no manual patches.
> **HARD PRECONDITION (ЧП gate):** do NOT run/accept this task until CC-1 (`cc_prompt_app_drop_backend_tables.md`,
> commit 46c6d4b) has passed its evidence gate — `BUILD=0` + `UNIT failed=0` (native/Soma) and the fresh-DB
> proof (prod `migrate` yields shell-only; `schema.sql` then applies with no "already exists"). CC-2's correctness
> ("`migrate` = shell-only") depends on that. Authoring/committing CC-2 may proceed; ACCEPTANCE is gated on CC-1 green.
>
> Canonical order (Design B / ADR-007):
> `drop+recreate db → 01_init_db (extensions+app user) → Web.exe migrate (SHELL tables + seed, run FROM Shell dir, Production env) → db/schema.sql (backend tables) → db/functions/* → db/data/*`.
>
> Branch: **v3 ONLY**. Commits: **`db:`** for `db/tools/Provision-FreshDb.ps1`; **`deploy:`** for `deploy/*` + `tools/Build-ProdRelease.ps1` + docs (§39.6 — do NOT mix modules in one commit). **NO push** (§37). Territory: devops (deploy/, db/tools/).

## Mandatory — read before starting (§40 — do NOT skip any)
Read file: .claude/skills/role-devops/role-devops.md   (§A CORE + §C VERIFY — MANDATORY, file is present)
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read for context: deploy/Install-RTMView.ps1, db/tools/Restore-All.ps1, db/tools/Create-FreshDb.ps1, deploy/Restore-SqlDump.ps1, tools/Build-ProdRelease.ps1
Only after reading: proceed.

## INIT — §0.6a integrity + branch (v3)
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # MUST be v3
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HH=$(git hash-object "$f"); HEADH=$(git rev-parse "HEAD:$f" 2>/dev/null)
  [ "$HH" != "$HEADH" ] && { WT=$(wc -l < "$f"); HD=$(git show HEAD:"$f"|wc -l); [ "$WT" -lt "$HD" ] && { git show HEAD:"$f" > "$f"; echo "RESTORED $f"; }; }
done
sync
```

## §0.6b BINDING PREAMBLE — append to .coord/cc/devops.md (Python+fsync)
```
## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_canonical_install.md | status: open
### DIRECTIVE (spec->CC): canonical Design-B fresh-install — Provision-FreshDb.ps1 + Install-RTMView.ps1 (Superadmin/Redis/RTM-params/-NoStartServices/-FreshDb) + db/ in package + FRESH-INSTALL.md. v3. Commits db:/deploy: split. NO push. Report BUILD/parse counts + package db/ entries WITH COUNTS. Acceptance gated on CC-1 (46c6d4b) green.
```

## GROUNDING (issues observed on the 140 install — every one must be fixed)
1. `Create-FreshDb.ps1` never applies `db/schema.sql` → incomplete backend (RTSGrid_Metric w/o CatalogCategory, no RTSData_Interaction). `Restore-All.ps1` DOES apply schema.sql — mirror that.
2. `Web.exe migrate` run from a wrong CWD → `connectionString` null (ASP.NET content-root = CWD). MUST run from the Shell dir.
3. `Seed:SuperadminPassword` absent from Shell appsettings → "superadmin will not be created". MUST inject.
4. Shell `ConnectionStrings:Redis` had no password but Garnet uses `--auth` → Shell can't reach cache. MUST inject the Garnet password into the Redis connstr.
5. RTM appsettings ships Kestrel `8088` + `PipeName rtmpipe` + `TenantId 000…` + `AdaptorServiceName RTMView.Nayax`. For side-by-side these must be parametrised: RTM port (e.g. 8089), pipe (e.g. rtmpipe_v3), TenantId, AdaptorServiceName.
6. `Create-FreshDb.ps1` uses `$ErrorActionPreference='Stop'` → a psql stderr NOTICE ("role already exists") aborted the whole script. Provisioning must use `Continue` around native psql.
7. Install `[6/6]` starts services immediately — before the DB exists → Shell/RTM crash-loop. Services must NOT start until the DB is provisioned.

## THE WORK

### A) `db/tools/Provision-FreshDb.ps1` — NEW canonical DB provisioning  (commit `db:`)
Params: `-DBHost/-DBPort/-Database(rtmviewdb)/-SuperUser(postgres)/-SuperPassword/-AppUser(ccdashboard_user)/-AppPassword/-ShellExe(C:\RTMView\Shell\CcDashboard.Web.exe)`.
`$ErrorActionPreference='Continue'`, `$env:PGCLIENTENCODING='UTF8'`. RepoRoot resolves `db/` relative to the script (same convention as Restore-All: parent-of-parent-of-ScriptDir). Steps, each printing progress + not aborting on psql NOTICE:
1. Terminate connections → `dropdb --if-exists` → `createdb -E UTF8` (as superuser).
2. `db/setup/01_init_db.sql` (extensions + app user) — as superuser.
3. **Shell migrate (shell tables + seed):** run `& $ShellExe migrate` **with working directory = Split-Path $ShellExe** (Push-Location the Shell dir) and `ASPNETCORE_ENVIRONMENT=Production`. (After the CC-1 drop-migration, this yields shell-only.)
4. `db/schema.sql` — as superuser (creates backend tables); then transfer object ownership to `$AppUser` (reuse the ownership DO-block from `Restore-All.ps1`).
5. `db/functions/01_ngc_functions.sql,02_rtsdata_functions.sql,03_rtsgrid_read.sql,04_misc_functions.sql` — as superuser.
6. `db/data/*.sql` (name-sorted) — as superuser.
7. Sequence resync + grants (reuse the blocks from `Restore-All.ps1`).
Verify-print at the end: `SELECT to_regclass('public."RTSGrid_Metric"')`, `..."RTSData_Interaction"`, `..."tenants"`, and `SELECT COUNT(*) FROM "RTSGrid_Metric"` (>0), tenants (>0), a superadmin row exists.

### B) `deploy/Install-RTMView.ps1` — additive fixes (keep existing behavior when new flags absent)  (commit `deploy:`)
- New param `-SuperadminPassword` → inject `Seed:SuperadminPassword` into the deployed Shell appsettings (in the same [4b] block that injects ConnectionStrings:Default).
- Inject `ConnectionStrings:Redis` = `localhost:6379,password=<RedisPassword>` when `-RedisPassword` is set (currently only Default/PG is injected).
- New params for RTM appsettings injection (in the [4/6] RTM deploy block): `-RTMPort`(→ Kestrel Endpoints:Http:Url `http://127.0.0.1:<port>`), `-RTMPipeName`(→ RTM:PipeName), `-RTMTenantId`(→ RTM:TenantId), `-AdaptorServiceName`(→ RTM:AdaptorServiceName). Use atomic read→modify→write (UTF-8, preserve the Hebrew `AgentWGPerfixList`).
- New switch `-NoStartServices`: when set, register services but do NOT `Start-Service` at [6/6] — so the DB can be provisioned first, then started.
- New switch `-FreshDb`: when set (instead of `-SkipDB` restore path), call `db/tools/Provision-FreshDb.ps1` (runs AFTER binaries are deployed, since it needs Shell.exe). If both dump-restore and FreshDb are unset, keep current behavior.
- `tools/Build-ProdRelease.ps1` (commit `deploy:`): ensure the Full package includes the ENTIRE `db/` tree (schema.sql + setup + functions + data + tools/Provision-FreshDb.ps1). (Today the package omits db/.)

### C) Canonical runbook (docs)  (commit `deploy:`)
`deploy/FRESH-INSTALL.md`: the one canonical order + the exact `Install-RTMView.ps1` invocation for a side-by-side server (RTM 8089/rtmpipe_v3, Shell HTTPS 8444, Fqdn/cert, RedisPassword, SuperadminPassword, `-FreshDb -NoStartServices`), then start services, then post-config (RTM TenantId once the tenant exists). Also document the **existing-dev-DB caveat** from CC-1: on an already-migrated dev DB, `beDb` history is applied so the App drop leaves backend-less until dev DB / beDb history is reset — fresh DBs only.

## VERIFY / DoD (report NUMBERS)
- **Syntax:** all PS1 parse (`powershell -NoProfile -Command "[void][ScriptBlock]::Create((Get-Content -Raw <f>))"`) → 0 errors. UTF-8 BOM + CRLF for PS1 (§35).
- **Package:** run `Build-ProdRelease.ps1 -Mode Full -SkipDB` → confirm `db/` (schema.sql + tools/Provision-FreshDb.ps1 + data + functions + setup) is in the zip; report the added entry list + count.
- **Logic review (state it):** Provision-FreshDb order matches Design B; migrate runs from Shell dir + Production; psql steps Continue-safe; Install injects Superadmin+Redis+RTM params; `-NoStartServices` honored; `db/` in package.
- Full FUNCTIONAL test = the coordinator-run **140 shakedown** (fresh deploy end-to-end on the prod-identical box), NOT this task. This task's DoD = correct scripts + package + syntax.

## COMMIT (commit.lock + journal + NO push · §39.6 split)
- `bash tools/pre-commit-check.sh` → 0. commit.lock (retry 5×60s).
- Commit 1 `db:` — stage ONLY `db/tools/Provision-FreshDb.ps1`. Message: `db: Provision-FreshDb.ps1 — canonical Design-B fresh DB (init→migrate(shell)→schema.sql→functions→data) [devops]`.
- Commit 2 `deploy:` — stage `deploy/Install-RTMView.ps1` + `tools/Build-ProdRelease.ps1` + `deploy/FRESH-INSTALL.md`. Message: `deploy: Install-RTMView superadmin/redis/RTM-params/-NoStartServices/-FreshDb + db/ in package + FRESH-INSTALL runbook [devops]`.
- §0.6 post-commit verify (both). **NO push.** §0.7 re-sync.

## §0.6b BINDING POSTAMBLE — RESULT into .coord/cc/devops.md
```
### RESULT (CC->spec): commits <db-hash>,<deploy-hash> . PS parse <0 err/n files> . package db/ entries <count list> . files Provision-FreshDb.ps1 + Install-RTMView.ps1 + Build-ProdRelease.ps1 + FRESH-INSTALL.md . status done|failed . blockers . verified: object-store + parse + package (functional=140 shakedown, coordinator)
```

## §0.6b CAPTURE → role-devops §B
"Fresh install on a new server broke because the DB tooling was split (Create-FreshDb=EF-migrate-only, Restore-All=schema.sql) and Install injected only the PG connstr. Canonical Design-B fresh install = drop→init→migrate(shell, from Shell dir, Production)→schema.sql→functions→data, with Install injecting Superadmin+Redis+RTM-appsettings params and NOT starting services before the DB exists; the package must ship the whole db/ tree. Rule: a repeatable install has ONE ordered provisioning path + all per-server config injected by the installer, never hand-patched."
