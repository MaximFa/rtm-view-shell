# INSTALL CHANGESET — consolidated (DRAFT, coordinator+operator) 2026-07-13T01:48Z
STATUS: DRAFTING with operator -> finalize -> ONE centralized §4-blessed dispatch to owners. Supersedes all piecemeal tenant/slug/UUID dispatches (HELD).

## GOAL
A single-command reproducible fresh install where the default platform tenant, its reference data (NGC_Site), and RTM config are ALL consistent BY CONSTRUCTION — so RTM data (queues/groups) loads on first run with no hand-alignment.

## ROOT (found on 140)
Seed generated a RANDOM platform tenant UUID (019f58ea-0c56-7792-a5f2-dafacec8a848), but db/data (NGC_Site "IL", the mandatory default) + RTM appsettings hardcode 019e03e9-60dd-72da-bd01-648ffdb2b433 → tenant != NGC_Site.TenantId != RTM.TenantId → RTM queue/group data does not join → empty until manually aligned. Operator manually set NGC_Site "IL" to the real tenant -> data loaded.

## CHANGES (by owner)
1. [BACKEND seed] Default platform tenant = FIXED const Id **019e03e9-60dd-72da-bd01-648ffdb2b433** (no random UUIDv7). Name="Platform" = STABLE idempotency key. Slug = config `Seed:PlatformTenantSlug` (default "platform"). Re-run: find-by-Name, no dup, sync slug from config.
2. [DEVOPS install] `-TenantSlug <slug>` (default platform) -> inject `Seed:PlatformTenantSlug` into deployed Shell appsettings [4b]. (140 = nayax.)
3. [DEVOPS install] RTM appsettings `TenantId` baked default = **019e03e9...** (+ `-RTMTenantId` param, default the const). No per-install lookup.
4. [DBA/DB] VERIFY every tenant-scoped baseline row in db/data uses **019e03e9...** — NGC_Site "IL" (mandatory default) FIRST, plus any other TenantId-bearing seed (queues/groups/agent-states reference). By construction they then match the fixed platform tenant. Fix any that don't.
5. [DEVOPS] DEFECT A fail-fast: install validates superadmin pw policy (>=12, digit+upper+lower+special) BEFORE seed, with a clear error (not a mid-seed swallow).

## SHAKEDOWN BACKLOG — decide IN-batch vs follow-up
- C: Provision VERIFY unquoted-identifier false-FAIL (devops).
- D: Shell service Serilog RELATIVE path -> log lands in System32 (SCM CWD) (devops).
- E: app-user lacks CREATEDB -> Automatic-start BEFORE provision = FTL 42501; app should assume DB exists OR gate service start until provisioned (backend/devops).
- SEC: appsettings.json plaintext DB/Redis/Superadmin secrets -> rotate + DataProtection/env-var (security).

## OPEN QUESTIONS FOR OPERATOR
Q1. 140 now = tenant 019f58ea + NGC_Site aligned to 019f58ea (queues loaded) + RTM 019e03e9 (mismatch). After the fix (all on 019e03e9): RE-PROVISION 140 CLEAN (019e03e9 everywhere, removes hand-patches) — or hand-align 140 to 019e03e9? (Coordinator recommends clean re-provision = true "как надо".)
Q2. Which of C/D/E/SEC go in THIS install batch vs a scheduled follow-up?
Q3. Confirm 019e03e9-60dd-72da-bd01-648ffdb2b433 as THE permanent standard default-platform UUID for every server.


## 2026-07-13T02:04Z | INSTALL CHANGESET — ADD item 6: provision TenantSettings.SignalRConnectionUrl
Post-install defect (140): BU Edit → Queues picker empty + Blazor "unhandled error" because `TenantSettings.SignalRConnectionUrl` for the platform tenant was UNSET. Operator set it manually → resolved.
CHANGE [devops/backend]: install must SET the platform tenant's `SignalRConnectionUrl` (RTM relay hub URL, per-server — e.g. derived from -RTMPort / an explicit `-SignalRUrl` param) so it is populated on fresh install, not hand-entered. Either seed default (backend, if a sane per-server default exists) OR inject at install (devops -SignalRUrl → tenant_settings). Decide owner when batched.
Ref: §6.2 SignalRConnectionUrl, §34 RTM relay. Folds into the consolidated install changeset (`.coord/install_changeset_spec.md`).


## 2026-07-15T10:24Z | INSTALL-SEED backlog (AgentGrid default reaches fresh install) — added post-DefectA, DEFERRED by operator ('push first, backlog after')
Canonical fix DONE + in the push: 46a1ce7 (db/data/03_rtsgrid.sql) + 6dc2b9c (ScreenEditorPage.razor). These 3 propagation/gap items are DEFERRED to the install-changeset batch (pre-existing, not regressions):
- (a) devops/tools/db/data/03_rtsgrid.sql still has the 5 PHANTOM default MetricIds → swap to real (byte-mirror 46a1ce7). PROMPT AUTHORED + self-§4: tools/cc_prompt_reconcile_agentgrid_mirror_devops.md (awaiting §4 when unblocked). Mirror consistency, not prod-critical.
- (b) ⚠ db/baseline.sql + Installations/dbdeploy/db/baseline.sql have ZERO `COPY "RTSUserGrid_Column"` blocks → **db/tools/Create-FreshDb.ps1 (applies baseline.sql) seeds a BLANK AgentGrid** (fix 46a1ce7 lives in db/data, which Create-FreshDb does NOT apply). Restore-All (db/data) path = OK. FIX = add the 5 real-id RTSUserGrid_Column set-1 default rows (+ ColumnsSet=1 header if missing) to db/baseline.sql, OR regenerate baseline.sql from the fixed modular db/data. Pre-existing gap (defaults were never in baseline.sql). SOURCE: dba-0625 Q1 verify 2026-07-15 (Create-FreshDb.ps1:9,37,114).
- (c) PROD path deploy/Install-RTMView.ps1:509-518 → Restore-SqlDump.ps1 restores a PACKAGED .dump (Build-ProdRelease from a reference DB), NOT db/data nor baseline → VERIFY the packaged dump carries correct RTSUserGrid_Column defaults (real IDs). SOURCE: dba-0625 Q1.
Owner cluster: dba/devops (baseline+prod-dump seed correctness). Folds into .coord/install_changeset_spec.md. Un-HELD with the rest of the install changeset after the push.


## 2026-07-15T13:33Z | INSTALL-CHANGESET — Restore-All / provisioning defects surfaced during QA reseed 2026-07-15 (DEFERRED)
QA's local-DB reseed for the push barrier surfaced a cascade of provisioning defects (reinforces the install-changeset urgency):
- Restore-All.ps1 grant step: `@"...DO \$\$...END \$\$;"@` double-quoted → literal `\$` → psql `invalid command \$`. FIX: backtick `` `$`$ `` (lines 170/184).
- Restore-All 01_init_db resets ccdashboard_user pw (→ 28P01 vs Shell conn-string). FIX: set role pw to -AppPassword consistently, or document.
- [DB-INTAKE-01]: Restore-All -DropAndRecreate applies schema/data but leaves __EFMigrationsHistory EMPTY → Shell migrate 42P07 (PK exists). reconcile artifact staging/reconcile_efmig_prodmirror.sql is STALE (26 App-only migrations, missing 2 newest + Audit/BackendEmulation contexts).
- Naming: EF migrate `rtsgrid_metric` (lowercase) vs schema/db-data `"RTSGrid_Metric"` (PascalCase) — part of the baseline gap; unify.
Canonical fresh-install path = Design-B (init→migrate(shell all contexts)→schema→functions→data). Owner cluster: devops/dba. Folds with the baseline.sql RTSUserGrid_Column gap + prod-dump check.
