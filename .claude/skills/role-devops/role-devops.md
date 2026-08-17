---
role: devops
project: RTM View Shell
version: 0.1
last_verified: 2026-06-19T09:30:00Z
owner: devops
reviewer: curator
---
# role-devops — RTM DevOps role-skill (Specialist Protocol)
> COLD-STARTED FROM ARTIFACTS (deploy/, tools/, Installations/, db/tools/, git log --oneline deploy/),
> NOT session narrative. Standard: .coord/protocols/role-skill-standard.md.

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

Role: Deployment scripts, packaging, ops tooling. Owns: deploy/, tools/Build-*.ps1, Installations/, db/tools/.
Does NOT write business logic — code changes flow via CC prompts.

**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.

Cardinal truths (source-pinned):

1. **MANDATORY Compare-ToBaseline before ANY deploy. Never rely on memory.**
   Never apply migrations/binaries without FIRST running Compare-ToBaseline against THAT server.
   Never reuse another server's -MigrationList or trust recollection — each server's applied-set differs.
   The Compare IS the gate: yields the server-specific -MigrationList AND catches runtime-critical drift.
   · SOURCE: 234+45 deploys 2026-06-19; journal 2026-06-19; 234 baseline_delta 111313 -> FULL-10 vs 45's different list

2. **§35: PS1 files MUST be UTF-8 BOM + CRLF for Windows PowerShell 5.1.**
   Box-draw/Cyrillic without BOM -> "Unexpected token" parse failure.
   · SOURCE: CLAUDE.md §35, 024feef BOM fix

3. **Preserve operator config across binary updates (appsettings.json + *.Production.json).**
   · SOURCE: 234 28P01 incident; e46e849

## §B LESSONS  (append-only · dated · source-pinned · status)
- 2026-06-19 · StrictMode scalar.Count: Get-ChildItem/Sort-Object/.Split() return SCALAR on single item -> .Count THROWS under Set-StrictMode -Version Latest. ALWAYS wrap collection results in @(...). · SOURCE: de5e835 (@() on $allBackups L137 + $migrations L204) · status: active
- 2026-06-19 · §35 BOM re-encode via Python: a TEXT write drops the UTF-8 BOM -> PS 5.1 fails. Re-encode in BINARY: b"\xef\xbb\xbf" + text_CRLF.encode("utf-8") + fsync; verify head -c3 == ef bb bf. · SOURCE: d62e704 dropped BOM -> 024feef fix · status: active
- 2026-06-19 · Deploy must PRESERVE operator config: Update-RTMView Shell-preserve missed appsettings.json -> overwrote 234's live conn-string -> 28P01 password auth failed. Preserve every operator config file, not just *.Production.json. · SOURCE: 234 Shell crash; e46e849 fix · status: active
- 2026-06-19 · pg_dump completeness: pre-apply pg_dump must run as OBJECT OWNER (postgres), else backup is INCOMPLETE. Run the whole apply path as postgres. · SOURCE: 234 STEP-4 pg_dump-completeness flag · status: active
- 2026-06-19 · pkg-copy PD-007: staged package file gets truncated by mount write-back AFTER native commit; re-materialize from HEAD + byte/hash-verify the swap source before every swap. · SOURCE: BOM + StrictMode fixes both needed pkg re-materialize · status: active
- 2026-06-25 · ref: visual-check prep runbook = **docs/Visual-Test-Preflight.md** (profiles A=rebuild / B=running; shared gate Chrome→Soma /health:5199→Shell /ops/health.up→restart×3→start). Use when running or awaiting a visual check. · SOURCE: docs/Visual-Test-Preflight.md · status: active

- 2026-07-03 · Local self-signed HTTPS (Kestrel Store cert, AllowInvalid=true) does NOT complete the TLS handshake on the local box (cert/client/protocol-agnostic; TLS1.2/1.3=OS default; Schannel silent) -> local prod-parity HTTPS validation blocked; validate on the REAL server (234, live insightense cert) instead. Candidate fix: PFX Path like RTM. · SOURCE: local prodparity redeploy 2026-07-03 · status: active (parked)
- 2026-07-03 · Install-RTMView -Mode Full writes LITERAL REPLACE_FQDN/REPLACE_HTTPS_PORT/REPLACE_CERT_SUBJECT placeholders into the deployed appsettings.json when per-server params (-Fqdn/-ShellPort/-CertSubject) are omitted -> broken Kestrel. RULE: fail-fast on missing per-server params, OR redeploy code-only changes via Update-RTMView (preserves the server's real appsettings/cert/data.sys) — NEVER Install -Mode Full on an existing server. · SOURCE: 234 deploy decision 2026-07-03 (role-coordinator §B) · status: active

- 2026-07-03 · Build-ProdRelease packs Install/Update-RTMView.ps1 at the ZIP ROOT but does NOT pack db\tools\ (only DB\ dump via $PublishDB). Update-RTMView resolves Compare-ToBaseline at $RepoRoot\db\tools\ (parent of script dir) -> in a standalone package deploy the path misses -> [E1] drift gate SILENTLY SKIPS (WARN, does not stop) = §DEPLOY-16 mandatory gate bypassed. FIX (follow-up): Build-ProdRelease must pack db\tools\ next to Update-RTMView so the drift gate runs on the target server. For a code-only/zero-migration deploy the skip is acceptable WITH a compensating EF-history-count check (unchanged) + no 'Applying migration' in startup log. · SOURCE: 234 b03b870 deploy 2026-07-03 (coordinator RULING) · status: active

- 2026-07-11 · ONE task/command to the operator at a time — hand a SINGLE run-command/step, WAIT for the operator's result, THEN issue the next. Do NOT batch multiple dotnet/deploy commands in one hand-off (operator has to execute + report each serially). Applies to build+test gates, multi-step runbooks, sequential deploys. · SOURCE: operator directive 2026-07-11 (batched build+test to operator) · status: active

- 2026-07-13 · PS1 saved WITHOUT UTF-8 BOM parses fine in pwsh7 (UTF-8 default) but FAILS in Windows PowerShell 5.1 (no BOM -> Win-1252 codepage decodes UTF-8 multibyte em-dashes as garbage -> broken string literals -> ParserError). §35 PS1-parse DoD MUST be verified with **powershell.exe (5.1)** + first-bytes EF BB BF — NEVER pwsh7 alone (it hides the defect). My earlier R2 parse-check (ParseFile) used the generic parser -> did NOT catch the BOM/decode issue. · SOURCE: commits 0966263/88f4888 stripped BOM on 3 PS1 -> Build-ProdRelease ParserError on 234 box, 2026-07-13 · status: active

- 2026-07-13 · DOUBLE-BOM trap: §0.7 re-sync `git show HEAD:<f> > <f>` of a BOM'd file via **PowerShell `>`** (Out-File UTF8BOM) PREPENDS a 2nd BOM to git-show's already-BOM'd bytes -> EF BB BF EF BB BF. Windows PS 5.1 reads BOM#1 as file-BOM and BOM#2 as a literal ZWNBSP (\uFEFF) before #Requires -> `#Requires` unrecognized -> 'Unexpected attribute CmdletBinding' parse cascade. The COMMIT is fine (single BOM); only the WORKING TREE is corrupt. FIX: re-sync BOM'd files BYTE-EXACT (bash `>` / Python binary write / git checkout-index) — NEVER PowerShell `>`. When a PS 5.1 parse fails on a BOM'd file, check the WORKING-TREE bytes (head -c6) not just the commit blob. · SOURCE: cb6f069 working-tree double-BOM broke Build-ProdRelease parse, 2026-07-13 · status: active


- 2026-07-13 · 140 fresh-install shakedown: a FAILED install left C:\RTMView\Shell+RTM deployed AND the migrate exe (CcDashboard.Web.exe, PID 8276) STILL RUNNING (Defect-B old build's migrate never exited). A re-provision STEP1 re-check MUST wipe dirs + orphan-kill even when services are absent. · rule: never assume 'services gone' = 'clean' — verify dirs + running exes. · SOURCE:140 run, PID8276 killed · status: active
- 2026-07-13 · PowerShell STRIPS inline double-quotes when calling native psql `-c 'SELECT ... "PascalTable"'` -> psql gets unquoted -> folds lowercase -> false `relation does not exist`. Use `psql -f <file>` (here-string @'...'@ -> Set-Content) so quoted PascalCase survives. SAME root as Provision-FreshDb [VERIFY] false-FAILs (Defect C). · SOURCE:140 sanity, "RTSGrid_Metric"=202 only via -f · status: active
- 2026-07-13 · Windows Service registered directly (UseWindowsService, sc binPath=exe) runs CWD=C:\Windows\System32, so a RELATIVE Serilog path (logs/log-.txt) writes the SERVICE log to C:\Windows\System32\logs\, NOT the app dir (app-dir logs/ only holds the migrate run, whose CWD Provision sets). Fix: absolute Serilog path or service WorkingDirectory. · SOURCE:140 svc log-20260713.txt · status: active
- 2026-07-13 · app user ccdashboard_user lacks CREATEDB; if RTMViewShell (StartType=Automatic) starts BEFORE the DB is provisioned, DatabaseInitializer Migrate -> NpgsqlDatabaseCreator.CreateAsync -> 42501 permission denied -> [FTL] Application terminated. Canonical order (Provision creates DB as postgres + -NoStartServices) avoids it; harden: app should ASSUME DB exists. · SOURCE:140 svc log 00:42 FTL vs 03:39 clean · status: active


- 2026-07-13 · Fresh-install SHELL crashes on RESTART if the platform tenant slug was changed from 'platform': SeedPlatformTenantAsync hardcodes slug=='platform' (DatabaseInitializer.cs:119/126, no Seed:PlatformTenantSlug), so a renamed platform tenant (e.g. ->nayax for the FQDN) isn't found -> seeder creates a DUP 'platform' tenant -> SeedSuperadminAsync re-creates 'admin' -> GLOBAL UserNameIndex 23505 -> Program.Main crash. Also users unique index is global (not per-tenant per §6.2). Any -SkipShell RTM update that bounces the Shell surfaces this. Fix = configurable seed slug + per-tenant username index. · SOURCE:140 svc log 23505 + tenants(nayax/platform dup) 2026-07-13 · status: active


- 2026-07-13 · Update-RTMView -SkipRTM/-SkipShell does NOT leave the other service untouched: it STOPS+STARTS (bounces) BOTH (stop@106-115/start@392-401 ignore the -Skip flag; only the binary redeploy is skipped). The bounce is USEFUL — an RTMService bounce re-triggers the adapter snapshot on the pipe -> populates NGC_Queues (seal). Also -DBPassword is MANDATORY (internal pg_dump overwrites PGPASSWORD with $DBPassword default '' -> aborts AFTER both services stopped -> both DOWN). And -SkipCacheMigration to not touch a live Garnet. · SOURCE:140 Shell redeploy 2026-07-13 · status: active
- 2026-07-13 · Verify an EF migration applied by checking the ACTUAL object, not __EFMigrationsHistory (App-context history table name/schema varies — ILIKE '%migrationshistory%' found 0). For PerTenantUserNameIndex: `SELECT indexdef FROM pg_indexes WHERE schemaname='identity' AND tablename='users'` -> UNIQUE IX_users_NormalizedUserName_TenantId WHERE IsActive proves H; old UserNameIndex becomes non-unique. · SOURCE:140 2026-07-13 · status: active
- 2026-07-13 · Update-RTMView drift-gate path bug: it looks for Compare-ToBaseline.ps1 at C:\Temp\db\tools\ (hardcoded C:\Temp) not the extracted package dir C:\Temp\<pkg>\db\tools\ -> WARN-skips every time even when the Full pkg ships it. Gate never runs. · SOURCE:140 Update output 2026-07-13 · status: active


- 2026-07-14 · Adapter (RTM.Twilio) warm binary-swap on a SHARED pipe can leave BOTH feeds down: adapter=pipe CLIENT reconnects, but the RTM pipe-SERVERS may not re-accept a reconnecting client without a SERVER restart -> 'Pipe hasn't been connected yet' persists on both rtmpipe(legacy)+rtmpipe_v3(ours). Fix path that WORKED: rollback old binary + restart legacy RTM. Lesson for adapter-swap runbooks: PRE-PLAN restarting the RTM pipe-servers (our RTMService + legacy RTM) inside the window, and run the isolating probe (restart our RTMService -> does the new adapter connect rtmpipe_v3?) BEFORE concluding a binary regression. A green WIRE-14/14 (format) does NOT cover live warm-server connect behavior. · SOURCE:140 6ebd39f rollback 2026-07-14 · status: active (CORRECTED 2026-07-14: operator restarted ALL services in recovery -> cannot attribute to a 6ebd39f binary regression; leading cause = pipe-SERVERS need restart to re-accept; adapter-swap runbook MUST restart RTM pipe-servers then RE-TEST 6ebd39f before concluding a binary bug) [OPERATOR DIRECTIVE 2026-07-14: legacy RTM must NEVER be restarted as part of our procedure — live prod, not ours. Acceptance = adapter self-reconnects to a STILL-RUNNING legacy pipe-server (only OUR RTMService may bounce). The recovery that restarted legacy is NOT a valid standing procedure.]

## §C VERIFY  (run at init — spot-check §A vs CURRENT code; mismatch -> superseded, don't act)
1. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "@\(Get-ChildItem"` — must exist (@() wrap)
2. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "appsettings\.json"` — must exist (preserve)
3. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "pg_dump"` — must exist (DB backup)
4. `Select-String -Path "deploy/Update-RTMView.ps1" -Pattern "Compare-ToBaseline"` — must exist (E1 gate)

## §D REFERENCE
Scripts: deploy/Update-RTMView.ps1, deploy/Install-RTMView.ps1, tools/Build-ProdRelease.ps1.
Ops layout: CLAUDE.md §43 (external-server ops), §35 (prod release encoding).
