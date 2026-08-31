# CC task — CONVERGE DEPLOY to 234 (nayax prod-parity) — our-stack @d1982de
> ⛔ЧП. Branch v3. Commits only, **NO push**, ветку НЕ двигать. Joins the active barrier.
> §4-review by coordinator BEFORE run. Operator receives the code-box from the COORDINATOR after bless, one box at a time.
> Owner: devops-0625. Target product version = **d1982de** (unchanged since 2026-07-22).
> Rev 2 (2026-08-29): §4 REVISE addressed — rollback path, probe two-predicate, Step-0 full path set, BE-history gate, curl.exe.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-devops/role-devops.md

## Step 0 — INTEGRITY (object-store, §0.2/§0.5)
cd "D:\Claude\Projects\RTM View Shell"
git status --short          # KEEP — integrity check (native exec, no mount index.lock risk)
git rev-parse v3 origin/v3
# Product tree == d1982de proof (MUST be 0). FULL path set — prompt outlives tip; a short list misses drift silently:
git diff --name-only d1982de v3 -- \
  src db deploy RTM devops wwwroot infra scripts \
  CcDashboard.sln global.json appsettings.template.json | wc -l   # expect 0
# NOTE: wwwroot carries Shell static assets incl. widget-resize.js + app.css?v=32 (WIDGET-STICK).
# => 0 ⇒ building from v3 tip yields byte-identical d1982de product/deploy/db artifacts; no detached checkout.

## Git push
Do NOT run `git push`. Commit only. Branch stays put.

## BINDING preamble (.coord/cc/devops.md)
`## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_converge_234_d1982de.md | status: open`
`### DIRECTIVE: converge-deploy our stack @d1982de to 234 (backup->Compare->migrate->binaries->restart OUR services only). Claim: deploy/**, db/tools/**. Report artifacts. NO push.`

## ⛔ THREE TRAPS (coordinator directive — in force, verbatim)
1. **LEGACY NOT RESTARTED.** Bounce ONLY our `RTMService` + `RTMViewShell` (NSSM, Automatic + sc failure-recovery). The Twilio adapter RE-CONNECTS ITSELF — do NOT stop/start it, do NOT stop Garnet, do NOT touch legacy RTM. Orphan-kill filter must match ONLY `C:\RTMView\RTM\*` and `C:\RTMView\Shell\*` (trailing `\RTM\` / `\Shell\` — NEVER RTM.Twilio).
2. **EF-history table name FROM CONTEXT CODE.** On 234 it is `public."__ef_migrations_history"` (App) + `audit."__ef_migrations_history"` (Audit) with a live relic beside it; BackendEmulation uses `public."__BackendEmulationMigrationsHistory"` and is NOT covered by `migrate` (schema.sql owns it). Verified in InfrastructureServiceExtensions.cs:42/52/61/72 + DesignTimeDbContextFactory.cs:22/52. Do NOT invent a name; do NOT drop/recreate the relic.
3. **PROD ConfigJson UNTOUCHED.** 234 carries prod `ConfigJson` (schema b58e2c2) that fails deserialize → silent-catch in ParseWidgetConfig (open reject PR234-1a). Do NOT recreate, "fix on the way", or reset any widget config. The `[PROBE PR234-1a]` logging (present in d1982de, 11 markers) must survive so the loss is captured on 234. Losing the config makes the bug non-reproducible.

## BUILD (on DEV build box)
`powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full`
- Full = Shell + RTM + DB package. BUILD gate: **BUILD=0 AND unit-suite failed=0, WITH NUMBERS** ("build 0" alone does NOT pass).
- Record package path `Installations\<DDMMYYYY.HHMM>_Full.zip` + size.

## DEPLOY ORDER (on 234 — prod topology, no `dotnet run`, no manual foreground)
### 1. BACKUP 234 — no valid backup, no deploy
- DB: `pg_dump` (custom format, as postgres/owner) → `C:\RTMView-Ops\backup\rtmviewdb_<ts>.dump`.
- Files: copy `C:\RTMView\Shell` + `C:\RTMView\RTM` → `C:\RTMView\Backup\<date>\` (Twilio dir also copied for safety, NOT restarted).
- Verify dump size > 0 and file backup present. STOP on any failure. **This pair (dump + binaries) is the ONLY rollback source — see ABORT.**

### 2. Compare-ToBaseline against 234 — output is a presented ARTIFACT
- Run the PACKAGED `db\tools\Compare-ToBaseline.ps1` from the UNZIPPED package dir (drift-gate resolves relative `db\tools\`; the C:\Temp\db\tools\ WARN-skip is the known benign miss).
- Paste the full delta report into the RESULT. This yields the SERVER-SPECIFIC migration list AND catches drift. Do NOT reuse another server's -MigrationList.
- **BE coverage (explicit answer):** Compare covers BackendEmulation **objects** — tables via schema.sql (DIM-A), functions (DIM-B), RTSGrid_Metric data (DIM-C), and model-sync only with `-CheckEfModel` (DIM-E). It does **NOT** reconcile the BE migration HISTORY (`public."__BackendEmulationMigrationsHistory"`) against present objects. → see step-3 BE gate.

### 3. MIGRATIONS -> BINARIES
- **[§DB-INTAKE-01 gate, App+Audit]** Before EF migrate: as postgres, read `__ef_migrations_history` + probe each current migration's signature object (`to_regclass`). Objects-present + history-empty/partial → baseline the applied MigrationIds `ON CONFLICT DO NOTHING`, THEN migrate MUST be a no-op. If migrate wants to apply anything → STOP + escalate (genuinely missing object; do not force).
- **[§DB-INTAKE-01 gate, BackendEmulation — mandatory, same acceptance as App]** `migrate` does NOT touch BE. Before applying ANY `schema.sql`: probe `to_regclass('public."__BackendEmulationMigrationsHistory"')` AND a signature BE object (e.g. `to_regclass('public."RTSGrid_Grid"')`). If BE objects PRESENT → do NOT blind-run schema.sql (42P07 risk); apply ONLY the gaps Compare (DIM-A/B/C) shows, per object. If BE objects absent AND history empty → schema.sql is the create path.
- Apply the Compare-derived migration list (EF `CcDashboard.Web.exe migrate` for App+Audit; schema.sql/functions/data ONLY where Compare shows a gap — never blind re-run).
- Then swap binaries: backup dir already taken → Stop-Service `RTMViewShell` + `RTMService` → orphan-kill (filter §trap-1) → copy Shell + RTM binaries → **preserve** appsettings.json (both) + `data.sys`/`app.dat` (RTM) → Start-Service `RTMViewShell` + `RTMService`.
- ⛔ Adapter/Garnet/legacy: leave Running, untouched.

### ⛔ ABORT / ROLLBACK PATH (mandatory — this is converge WITH migrations)
Stop conditions: migrate wants to apply an unexpected object (§DB-INTAKE gate); binaries fail to start against the migrated schema; post-check shows Queue-Grid/WFM/health broken or the probe path gone. Decide the abort BEFORE the box runs, not under night load.
**Rollback is a PAIR, from step-1 backup — "revert binaries" alone is NOT a rollback** (old binaries may not run on the migrated schema):
1. Stop-Service `RTMViewShell` + `RTMService` (+ orphan-kill, §trap-1 filter). Legacy/Twilio/Garnet stay up.
2. Restore DB: drop/rename the migrated DB, `pg_restore` the step-1 `rtmviewdb_<ts>.dump` (as owner).
3. Restore binaries: copy the step-1 `C:\RTMView\Backup\<date>\Shell` + `\RTM` back into place; restore preserved appsettings + data.sys/app.dat.
4. Start-Service `RTMViewShell` + `RTMService`.
5. **Re-check EF-history after restore** (App/Audit `__ef_migrations_history` + BE `__BackendEmulationMigrationsHistory` reconcile vs objects, §DB-INTAKE-01) so the restored DB is not left in the objects-present/history-empty trap.
6. Verify /health + 3 services Running; report rollback done with numbers.

### 4. PRESERVE HTTPS / cert
- `insightense.com` cert binding on 8444 must survive (survived 2026-07-03). Do NOT overwrite Kestrel cert config; preserve the deployed appsettings that carries the real Subject. Verify binding post-start.

### 5. POST-CHECKS (present each as artifact)
- All 3 services Running (RTMViewShell, RTMService, RTM.Twilio) + health (Windows-safe form): `curl.exe -sk https://localhost:8444/health` (NOT PS `curl` alias) — OR `Invoke-WebRequest -Uri https://localhost:8444/health -SkipCertificateCheck`. Expect Healthy.
- **Queue Grid counters vs legacy** — US All / US-Support are the convergence baseline (`01dbc2c`). Numbers match legacy.
- **WFM loop** gives a NON-EMPTY snapshot (tick log clean; note: the `WFM key collision` WARN for name==Workgroup&BU, e.g. UK-Retail/UK-Support, is a KNOWN open item, not a blocker — the snapshot-store is keyed by BusinessUnitId per d1982de).
- **Max Wait survives F5** (`89feb34`+`16c6011`).
- **PROBE — TWO predicates, do not conflate:**
  (a) **PRESENCE** — grep the DEPLOYED build tree/binary for `[PROBE PR234-1a]` = 11 markers (as shown for d1982de). This proves the probe SHIPPED.
  (b) **FIRING** — FIRST open a screen that carries prod `ConfigJson` (triggers the deserialize silent-catch), THEN grep the live Shell log for `[PROBE PR234-1a]`.
  **An empty log grep WITHOUT passing (a) is NOT a conclusion** — the probe fires only on an unparseable ConfigJson; empty-before-(a) reads falsely as "probe didn't ship". Report (a) and (b) separately.

## DISCIPLINE
- §0.3 Python + os.fsync for any `.coord/` write; `tail`+`wc` after.
- commit.lock (§42.4) around any commit; NO push; journal + lock release + §0.7 re-sync.
- Passwords entered ON THE BOX, never in chat. Garnet pw (SF-SEC-001) rotation is NOT in this transfer — separate debt.
- Every "done" claim = object-store / live-log verified, WITH NUMBERS. Tool success != delivery.

## BINDING postamble
Append RESULT to `.coord/cc/devops.md`: build numbers, package path, backup paths, Compare delta (incl. BE gate outcome), migration list applied, service states, /health, Queue-Grid vs legacy numbers, WFM snapshot, Max-Wait F5, probe (a)+(b) separately. status: done|failed. verified: object-store + live-log. Then digest to inbox/coordinator.md.
