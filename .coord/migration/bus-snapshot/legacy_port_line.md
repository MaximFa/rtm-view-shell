# Legacy → v3 bug-fix port line

> Standing process (operator directive 2026-07-10). The **legacy RTM branch keeps running at clients** and bugs are fixed there.
> Those fixes must be **forward-ported to v3** — but legacy files are built on an OLD base, so a naive whole-file replace REGRESSES v3.
> Rule: **NOTHING is deleted from v3; port ONLY genuine changes to existing logic, without loss of v3 functionality.**

## Process (per legacy file drop)
1. **Intake:** operator drops modified legacy files into `NNNNNNNN/RTM_new_cs_files/` (or names them). Log an entry below (date, files, source).
2. **Isolate (3-way):** find the git BASE commit closest to the legacy file's base; `diff(legacy, base) --ignore-all-space` isolates the operator's REAL edits (filters stale-base noise). Do NOT diff legacy vs v3 directly (noisy).
3. **Classify each edit:** GENUINE FIX (changes logic present in v3 → port) vs STALE-BASE ARTIFACT (only makes sense vs old code v3 refactored → skip) vs DIVERGENT (legacy-only behavior → operator decision).
4. **Operator decision** on DIVERGENT items (restore or skip).
5. **Port via CC prompt** onto current v3 files — surgical, preserving ALL v3 features; commit only (build 0 + object-store verify). **NO push yet.**
6. **Deploy to 234** (RTM Service package for RTM/* ports; Shell package for src/* ports).
7. **Sanity check on 234** — LIVE verify the fix works + no regression to preserved features. **NO push without this.** (established norm: batch-1/batch-2 all deployed+verified BEFORE push.)
8. **Barrier + push** (quorum) — ONLY after 234 sanity GREEN. Log closure-push.

> **IRON RULE (operator 2026-07-10):** commit → deploy 234 → sanity check → THEN push. Никогда push без проверки на 234.

## Guardrails
- Preserve v3 features by name in every port prompt (enumerate the v3-only code the legacy lacks → "DO NOT remove").
- Legacy files are CRLF+BOM; v3 is LF no-BOM → ignore whitespace/line-ending/BOM in analysis; keep v3 file's own encoding.
- Every port prompt lists the exact old→new snippets + v3 insertion points (no whole-file replace).

## Register

### PORT-2026-07-10-A — RTM Service (Call/Engine/UserManager)
- Source: `10072026/RTM_new_cs_files/` (Call.cs, Engine.cs, UserManager.cs), legacy base ≈ pre-`4500f89`.
- Isolation: subagent 3-way (2026-07-10).
- **Call.cs:** byte-identical → nothing.
- **Engine.cs:** NO operator logic edits (legacy diff vs its base = only BOM + absent v3 ForceRefreshMetrics) → port NOTHING.
- **UserManager.cs — port:**
  1. FIX `st→st1` (~L1210, TimeInStatus wrong-var / wrong elapsed baseline).
  2. FIX `TotalStatusGroupPercent` div0/NaN/range hardening (~L1231-1240) — MERGE to KEEP v3 `fmt2` default-format (371593e).
  3. RESTORE wait-for-call status state machine (legacy ~L160 SIGNOFF-init, ~L293-300 fields _isWaitForCall/statusBeforeWait, ~L364-409 logic incl. Hebrew literals בשיחה/ממתין לשיחה, ~L465 _statusName/_userStatusGroup TryAdd variant) — operator: RESTORE (needed fix). Preserve v3 calc-quarantine + tz-fallback + fmt defaults.
- DO NOT port: calc-quarantine removal, getLocalDateTime tz revert, ForceRefreshMetrics removal, fmt default reverts.
- Commit 7ae4507 (object-store verified) → build-0 gate PASSED (RTM.exe compiled) → RTM Service deployed 234 (10072026.2209, Update-RTMView -SkipShell -SkipDrift, RTMService Running /health 200) → BASIC sanity PASS 2026-07-11 (relay live, clean render, features intact; live values 0 = ~01:00 no activity). Acks: Sec/DBA/TW READY; QA pending my-sanity-basis → GREEN. Order kept: commit→deploy→sanity→push. Closure-push: **origin/v3 = 7ae4507 (PUSHED 2026-07-11)**. Full cycle complete: commit→build-0→deploy 234→basic sanity→quorum 4/4→push. Status: ✅ DONE (wait-for-call live-observe deferred to 234 working hours).


## PARALLEL-RUN config (operator 2026-07-11) — RTM.Twilio Part A + RTM Service Part B
Goal: run OUR RTM Service side-by-side with LEGACY, one adapter feeds BOTH (validation → eventual replace, PROLONGED side-by-side).
| Component | REST port | pipe | service |
|---|---|---|---|
| Legacy RTM Service (unpatched) | 8089 (moved from 8088 — CONFIG, not code) | rtmpipe | legacy |
| Our RTM Service (116416c, on origin/v3) | 8088 (stays) | rtmpipe_v3 (set RTM:PipeName on box) | ours |
| Adapter RTM.Twilio (multi-target, build 0) | — | fan-out to both | **RTM.Test** (REPLACES legacy adapter) |
Adapter RTM:Targets = [{Url: legacy:8089, Pipe: rtmpipe}, {Url: ours:8088, Pipe: rtmpipe_v3}]; preserve live Twilio secrets.
End-state: our RTM eventually replaces legacy after prolonged side-by-side.


## PARALLEL-RUN topology CORRECTED (operator 2026-07-11) — ALL co-located on 234
- Legacy RTM Service: already on 234 → move REST 8088→8089 (config-only, NOT patched), pipe stays "rtmpipe".
- OUR RTM Service (Part B 116416c): already on 234 + RUNNING → REST 8088 (stays), set RTM:PipeName="rtmpipe_v3".
- OLD adapter = Windows service **RTM.Test** (running, feeds legacy) → STOP/REPLACE.
- NEW adapter = Windows service **RTM.Twilio** (multi-target, build 0) → INSTALL, feeds BOTH.
- Adapter RTM:Targets = [{Url: http://localhost:8089, Pipe:"rtmpipe"}(legacy), {Url: http://localhost:8088, Pipe:"rtmpipe_v3"}(ours)]; PRESERVE live Twilio secrets.
- (Correction: RTM.Test = OLD adapter to replace; RTM.Twilio = NEW adapter name.)


## 2026-07-13 — NEW PROD SERVER (Nayax / 140) — Phase 0 DONE (swap-first, blip 1 verified)
Server: legacy on 140 (RTM 8088 + RTM.Nayax adapter 9201 HTTPS profit-twilio-new.nayax.com + DNN/IIS 443 + MSSQL H_RTM). PG18 present.
Cleaned prior half-install (services RTMService+RTMView.Nayax deleted; C:\RTMView junk gone; inert C:\Program Files\RTM\RTM.Nayax left, Defender-locked, harmless).
Phase 0 (swap-first, operator strategy): built multi-target RTM.Twilio (adapters 8abd19a) → staged C:\RTMView\RTM.Twilio; appsettings = legacy Kestrel HTTPS 9201 + *.nayax.com cert KEPT (Twilio webhook dep), RTM.Targets [{https://profit-twilio-new.nayax.com:8088,rtmpipe}(legacy),{http://localhost:8089,rtmpipe_v3}(ours)], Twilio block copied verbatim from RTM.Nayax; log4net→C:\Logs\RTM.Twilio. Service RTM.Twilio (LocalSystem, auto).
Cutover: stop+disable RTM.Nayax → restart legacy RTM (fresh single-shot pipe) → start RTM.Twilio. VERIFIED: 9201 bound, target1(rtmpipe/legacy) sends clean (no error), target2(rtmpipe_v3/ours) errors "Pipe hasn't been connected yet" = EXPECTED (our RTM absent) — per-target isolation proven; LEGACY VISUAL populated with our stack fully absent.
Adapter target IPs are the nayax DOMAIN over HTTPS (not localhost like 234) — legacy RTM REST is https://profit-twilio-new.nayax.com:8088.
NEXT Phase A: our cert (export insightense wildcard from 234 → 140), drop rtmviewdb, Install-RTMView Full -SkipDB (RTM 8089/Shell 8444), Create-FreshDb. Phase B: restart adapter (blip 2) → target2 connects → verify Shell on live feed.


### 140 (Nayax) — network/cert facts (operator 2026-07-13)
- Our Shell web: **port 8444**, URL **https://nayax.insightense.com** → mapped to 140 in EuroDNS (operator configured).
- Cert: `*.insightense.com` (thumbprint 828718535E6A558F48DBBCCC7E7B1467BFD3C26D, exp 2027-01-03) exported from 234, imported to 140 LocalMachine\My — covers nayax.insightense.com → Shell HTTPS 8444 uses it.
- Ports on 140 (final): legacy RTM 8088 (untouched, DNN visual reads it) | our RTM 8089 | our Shell 8444 | adapter inbound 9201 HTTPS (*.nayax.com, Twilio webhook). Operator has set ports.
- Legacy adapter feed is now our multi-target RTM.Twilio (Phase 0 done); our RTM target (8089/rtmpipe_v3) pending Phase A install + Phase B adapter restart.


## 2026-07-13 — FRESH-INSTALL DB PROCESS: Design B decided (clean repeatable deploy) — 140 shakedown
Diagnosis (subagent): 3 DbContexts (App, Audit, BackendEmulation/beDb). beDb owns RTSGrid_Metric/RTSData_Interaction/NGC_*/RTSUserGrid_*, separate history table __BackendEmulationMigrationsHistory. DatabaseInitializer.cs:41 gates beDb.MigrateAsync to dev/test ONLY → in PROD migrate runs App+Audit only. Architecture is ALREADY Design B (ADR-007): backend tables owned by db/schema.sql, not EF, in prod.
ROOT of the failed install: we used Create-FreshDb.ps1 which does NOT apply schema.sql (Restore-All.ps1 does). PLUS App migration chain historically CREATES stale backend tables (RTSGrid_Metric w/o CatalogCategory, NGC_*, RTSUserGrid_*) — SeparateBackendTablesToBeDb (App) was a NO-OP that never dropped them. So even schema.sql collides with migrate's stale copies.
DECISION: Design B (matches codebase grain). Canonical fresh-install = init -> migrate(shell only) -> schema.sql(backend) -> functions -> data. Repeatable, git-native, no dump, no cleanup.
BUILD PUNCH-LIST (all issues hit on 140 install):
 1. [backend CC v3] NEW App migration: DROP TABLE IF EXISTS backend tables the App chain created -> migrate = shell-only.
 2. [devops CC] one canonical install script (fold into Install-RTMView / fix Create-FreshDb): apply schema.sql.
 3. inject Seed:SuperadminPassword into Shell appsettings (else no superadmin).
 4. inject Redis/Garnet password into Shell Redis connstr (else Shell can't reach cache).
 5. run Web.exe migrate FROM the Shell dir (content-root/CWD else null connectionString).
 6. RTM appsettings params: Kestrel 8089, PipeName rtmpipe_v3, TenantId, AdaptorServiceName.
 7. ErrorActionPreference=Continue around psql (NOTICE-as-error must not abort).
 8. do not start services before DB ready.
140 WIPE scope: remove services RTMViewShell+RTMService, dirs C:\RTMView\Shell + C:\RTMView\RTM, db rtmviewdb. PRESERVE: RTM.Twilio (Phase 0, feeding legacy!), Garnet, legacy, *.insightense.com cert.
Then fresh deploy via canonical script on 140 = the process shakedown.
