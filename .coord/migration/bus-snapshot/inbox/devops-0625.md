
## 2026-07-06 | from: coordinator-0703 | to: devops [BATCH-2 BUILD — Shell pkg from v3 12480b2]
batch-2 origin/v3(adbf5d7)..v3(12480b2) = 3 commits: 7a8a4a8 ASD-BAR-BLUR (Chart.js devicePixelRatio supersampling + ?v=2), 21ecb84 ASD durable guard (QueueGridExistsAsync recreate), 12480b2 recreate/update unit-tests (+2, unit 260/260). Runtime = Shell only; NO migration, NO RTM change; binary-only Shell deploy path. All build0/unit260, object-store verified.
ЗАДАЧА: build Shell pkg from v3 tip 12480b2. Выполни задачу из файла tools/cc_prompt_build_shell_batch2.md
DoD: build 0 WITH counts + zip path/size/SHA + Update-RTMView.ps1 present + DPR/?v=2 verified from 12480b2. Deploy = binary-only Update-RTMView -SkipRTM -SkipDrift (same as batch-1, no migration). Report → cc/devops.md + inbox/coordinator.md. NO push.

## 2026-07-10 | from: coordinator-0703 | to: devops [GREENLIGHT — deploy run-box for 10072026.1309_Shell.zip (batch-2)]
Build accepted (10072026.1309_Shell.zip from 12480b2, SHA b4442f5a, DPR+?v=2 verified). Deploy path = SAME as batch-1 (pre-blessed): binary-only **Update-RTMView -SkipRTM -SkipDrift** (no migration in batch-2; drift = separate DBA track). ЗАДАЧА: produce the safe 234 deploy run-box for 10072026.1309_Shell.zip — backup-before FAIL-STOP (Shell app-dir + pg_dump) + rollback step, root path 10072026.1309\Update-RTMView.ps1. Hand to operator. After deploy: operator hard-refresh (?v=2) → I ЧП-p.4 LIVE-verify (crisp ASD bars + guard re-save self-heal on «12»). Re-verify /health on 234 via Chrome on your side. NO push. Report → inbox/coordinator.md.

## 2026-07-10 | from: coordinator-0703 | to: devops [BUILD RTM Service pkg from v3 7ae4507 — PORT-2026-07-10-A + build gate]
RTM UserManager legacy port 7ae4507 landed (object-store verified) but build-0 was NOT captured (CC binding dropped). This RTM publish IS the build-0 gate (truth-duty).
Выполни задачу из файла tools/cc_prompt_build_rtm_port.md
DoD: dotnet publish RTM = 0 err WITH counts (if compile FAILS — report verbatim + flag, do NOT package) + RTM pkg path/size/SHA + RTM deploy tooling present. Deploy = RTM Service (restart RTMService), NOT Shell. Report → cc/devops.md + inbox/coordinator.md. NO push.

## 2026-07-10 | from: coordinator-0703 | to: devops [GREENLIGHT — deploy run-box for 10072026.2209_RTM.zip (RTM Service, PORT-2026-07-10-A)]
Build-0 gate accepted (RTM.exe compiled from 7ae4507). ANSWER to your flag: the port 7ae4507 is **pure C# UserManager.cs status-computation logic — ZERO SQL-function / DB / schema / migration change**. → RTM-only binary swap is correct: **Update-RTMView -SkipShell** (restart RTMService), NO migration, NO -SkipDrift needed for DB (no DB touch). ЗАДАЧА: produce the safe 234 deploy run-box for Installations\10072026.2209_RTM.zip — backup-before (RTM app-dir; pg_dump optional since no DB change but keep for safety) + rollback, root Update-RTMView.ps1. Hand to operator. After deploy: RTMService Running + I run BASIC sanity (service up, /health, metrics flowing, log clean, no feature regression — NO live wait-for-call reproduction per operator). Re-verify /health on your side. NO push. Report → inbox/coordinator.md.

## 2026-07-10 | from: coordinator-0703 | to: devops [CONFIRM — -SkipDrift IS required; your correction accepted]
You're right, I was wrong. The [E1] drift gate runs regardless of -SkipShell and would abort on 234's pre-existing 440-line drift (like b03b870). My 'no DB touch' only justifies WHY skipping the gate is SAFE — the flag is still needed to not block. CONFIRMED: **Update-RTMView -SkipShell -SkipDrift -DBPassword <op>** (backup RTM app-dir + pg_dump FAIL-STOP; -SkipShell = RTM-only restart RTMService; -SkipDrift = skip E1 gate, safe because ZERO DB/migration in 7ae4507; drift = separate DBA track). Hand the operator your corrected run-box + rollback (Stop-Service RTMService; restore Backup\<ts>\RTM; Start-Service). After deploy → I run basic sanity (no live wait-for-call repro). Good catch. NO push.

## 2026-07-11 | from: coordinator-0703 | to: devops [BUILD-CONFIRM — RTM.Twilio multi-target (truth-duty gate)]
Backend refactor of 10072026/RTM.Twilio (multi-target fan-out) is object-store-verified (SendToAllAsync x10, PostToAllAsync, RtmTarget, RTM:Targets, snapshot semaphore; 0 old client.Send left). But build-0 NOT captured (backend can't run dotnet from Cowork). ЗАДАЧА (native/host): run
  dotnet build "10072026/RTM.Twilio/RTM.Twilio.csproj" -c Release
Report **0 errors WITH warning count** (if FAILS → paste the exact compile errors verbatim + flag; the refactor would need a fix). This is a SEPARATE module (not v3) — NO commit/push/barrier, just the build-count. After GREEN, RTM.Twilio is ready for the operator's separate deploy. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: devops [BUILD RTM pkg from v3 116416c — Part B pipe-name + build gate]
Part B (configurable pipe-name 116416c) landed object-store-verified; build-0 not captured. This RTM publish = build gate.
Выполни задачу из файла tools/cc_prompt_build_rtm_partb.md
DoD: dotnet publish RTM 0 err WITH counts (if FAILS — verbatim + flag) + RTM pkg path/size/SHA. Deploy = RTM Service Update-RTMView -SkipShell -SkipDrift (default pipe rtmpipe → 234 unchanged). Report → cc/devops.md + inbox/coordinator.md. NO push.

## 2026-07-11 | from: coordinator-0703 | to: devops [GREENLIGHT — deploy run-box for 11072026.1028_RTM.zip (Part B pipe-name)]
Build-0 gate accepted (RTM.exe compiled from 116416c). Part B = pure config/pipe-name, ZERO DB/migration. Same proven path as PORT-A (7ae4507): **Update-RTMView -SkipShell -SkipDrift -DBPassword <op>** (backup RTM app-dir + pg_dump FAIL-STOP; -SkipShell = RTM-only restart RTMService; -SkipDrift = skip E1 gate, safe/zero-DB). ЗАДАЧА: produce the safe 234 deploy run-box for Installations\11072026.1028_RTM.zip + rollback. Hand operator. Default pipe "rtmpipe" = backward-compat → 234 (single, no legacy) unchanged. After deploy: RTMService Running + I run basic sanity (service up, /health, metrics flow, log clean, AppConfig.PipeName=rtmpipe in log). Re-verify /health your side. NO push. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: devops [DRAFT — parallel-run deploy runbook (RTM.Twilio Part A + our RTM Part B side-by-side vs legacy)]
Operator decisions locked (see .coord/legacy_port_line.md PARALLEL-RUN config):
- REPLACE legacy adapter with RTM.Twilio multi-target; adapter Windows service name on the box = **RTM.Test**.
- Ports: OUR RTM Service stays 8088; LEGACY RTM Service moves to 8089 (config-only port change, legacy NOT patched).
- OUR RTM Service: set RTM:PipeName = "rtmpipe_v3" on the box (Part B 116416c supports it; default was rtmpipe). Legacy keeps rtmpipe.
- Adapter RTM:Targets = [{Url: http://<host>:8089, Pipe: "rtmpipe"} (legacy), {Url: http://<host>:8088, Pipe: "rtmpipe_v3"} (ours)]; PRESERVE live Twilio AccountSid/AuthToken/WorkspaceSid + Hebrew StatusGroups.
- End-state: prolonged side-by-side → eventual cutover to ours.
ЗАДАЧА: draft the parallel-run deploy runbook (report-scoped, NOT a v3 barrier — RTM.Twilio is separate; Part B our-RTM already on origin/v3). Flag the box specifics you need: (a) legacy adapter's current service name + install path (to stop/replace), (b) legacy RTM Service config path for the 8089 port change + confirm legacy is on the SAME box, (c) our RTM Service current state on the box (is it the 234 deploy or a separate parallel box?), (d) rollback (restore legacy adapter + legacy RTM port 8088 if the side-by-side misbehaves). Draft → your self-§4 → my §4 → operator. NO push. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: devops [CORRECTION + go — parallel-run runbook, all on 234]
Topology corrected (operator): ALL co-located on 234.
- Legacy RTM Service: ALREADY on 234 → move REST 8088→8089 (config-only, NOT patched), pipe "rtmpipe".
- OUR RTM Service (Part B 116416c): ALREADY on 234 + RUNNING → REST 8088 stays; set RTM:PipeName="rtmpipe_v3" (+ restart).
- OLD adapter = Windows service **RTM.Test** (running, feeds legacy) → STOP/DISABLE/REPLACE.
- NEW adapter = Windows service **RTM.Twilio** (RTM.Twilio multi-target, build 0, from 10072026/RTM.Twilio) → INSTALL as new service; RTM:Targets=[{localhost:8089,rtmpipe}(legacy),{localhost:8088,rtmpipe_v3}(ours)]; preserve live Twilio AccountSid/AuthToken/WorkspaceSid + Hebrew StatusGroups.
- (Earlier I had it backwards: RTM.Test = OLD to replace; RTM.Twilio = NEW.)
ЗАДАЧА: draft the parallel-run deploy runbook (report-scoped; RTM.Twilio separate, our-RTM already on origin/v3). Sequence carefully: (1) confirm current ports (is legacy currently on 8088? our RTM on 8088?) — the 8088/8089 swap must avoid a bind clash; (2) move legacy RTM → 8089 + restart; (3) set our RTM PipeName=rtmpipe_v3 + restart; (4) stop RTM.Test; (5) install RTM.Twilio (RTM:Targets both) + start; (6) verify BOTH RTM Services receive data (our dashboard Live + legacy still works). Rollback: RTM.Twilio off, legacy RTM→8088, RTM.Test back, our PipeName→rtmpipe. Flag any port/bind conflict. Draft → self-§4 → my §4 → operator. NO push.

## 2026-07-11 | from: coordinator-0703 | to: devops [§4 VERDICT — parallel-run runbook = BLESS + 2 additions]
§4-review of tools/parallel_run_runbook_234.md → **BLESS**. Sequence sound; port-gate (STEP0-d) correctly precedes any change; backup-before + full rollback; Twilio secrets operator-side.
ADD to the runbook (STEP5 + NOTES):
1. RTM.Twilio Kestrel INBOUND port MUST match RTM.Test's (Twilio webhook target = 9200 per appsettings). Inherit the Kestrel:Endpoints:Http:Url from RTM.Test's config; verify Twilio's webhook URL points to it — else inbound events stop.
2. NOTE the brief switchover gap: STEP4 stop RTM.Test → STEP5 start RTM.Twilio, legacy is momentarily unfed (both can't hold 9200) — expected, maintenance-window OK. Stage RTM.Twilio fully (STEP1 done) so the gap is minimal.
3. NOTE: copying Twilio secrets into RTM.Twilio/appsettings.json = plaintext (SF-SEC-001-class follow-up, non-blocking).
Otherwise APPROVED. HOLDING on operator box-specifics: (a) RTM.Test path+appsettings, (b) legacy RTM svc name+appsettings path (distinct from C:\RTMView\RTM), (d) port-state `Get-NetTCPConnection 8088,8089` → current 8088 owner. Once operator fills (a)/(b)/(d), add the 3 items above + finalize → hand operator. NO push.

## 2026-07-11 | from: coordinator-0703 | to: devops [BOX-SPECIFICS COMPLETE → finalize runbook]
All box facts collected (.coord/parallel_run_box.md). Concrete:
- LEGACY RTM = service **RTM** @ C:\IceDash\RTM\RTM.exe, **STOPPED**, config port 8088 (→8089), MSSQL H_RTM, pipe rtmpipe. appsettings: C:\IceDash\RTM\appsettings.json.
- OUR RTM = **RTMService** @ C:\RTMView\RTM\RTM.exe, Running, 8088, pipe currently rtmpipe → set RTM:PipeName=rtmpipe_v3.
- OLD adapter = **RTM.Test** @ C:\IceDash\RTM.AmanSupport\RTM.Twilio.exe, Running, **inbound Kestrel 9201** (NOT 9200), RTM_URL=8088, LIVE Twilio block here (WorkgroupAttName="routing.skills") → copy box-side into new adapter.
- PORT-STATE (d): legacy STOPPED → ours holds 8088 uncontested, 8089 free → clean move.
FINALIZE the runbook with:
1. NEW adapter RTM.Twilio inbound Kestrel = **9201** (correct from 9200); inherit RTM.Test's LIVE Twilio block verbatim (this box's, not staging).
2. ORDER REFINEMENT to avoid double-"rtmpipe": (1) ours PipeName=rtmpipe_v3 + restart FIRST (frees rtmpipe) → (2) legacy config 8088→8089 + START (legacy is currently Stopped; takes rtmpipe+8089) → (3) stop+disable RTM.Test → (4) install+start RTM.Twilio (Targets [{8089,rtmpipe},{8088,rtmpipe_v3}]).
3. Legacy appsettings 8089 change at C:\IceDash\RTM\appsettings.json (Kestrel:Endpoints:Http:Url).
4. Keep backup + full rollback (incl. legacy back to Stopped/8088, ours pipe→rtmpipe, RTM.Test back to Manual/Running).
5. SECURITY follow-ups noted (NON-blocking): Twilio AuthToken + legacy MSSQL password were exposed in chat → rotate later (route to security-track).
Update tools/parallel_run_runbook_234.md → hand operator. NO push. Report → inbox/coordinator.md.

## 2026-07-11 | from: coordinator-0703 | to: devops [BUILD+WIRE-TEST confirm — RTM.Adapter.Common extraction (truth-duty gate)]
Backend extracted RTM.Adapter.Common (minimal RTM-independent adapter lib) + re-pointed RTM.Twilio + added WireContractTests. Object-store verified (9 files, namespaces preserved, csproj re-pointed, real WIRE test). But build/test-0 not captured (backend can't run dotnet from Cowork). ЗАДАЧА (native/host):
```
dotnet build "10072026\RTM.Twilio\RTM.Twilio.csproj" -c Release
dotnet test  "10072026\RTM.Adapter.Common.Tests\RTM.Adapter.Common.Tests.csproj" -c Release
```
Report: (1) RTM.Twilio build = 0 err WITH warning count — this proves the minimal 9-file lib is a SUFFICIENT closure (if a missing-type compile error → paste it verbatim + flag: closure bigger than analysis). (2) WIRE test = passed/failed counts (the [WIRE-01/02/03] §48 contract guard). Separate module (not v3) — NO commit/push/barrier, just the counts. After GREEN, the adapter is ready for the branch `adapters` step. Report → inbox/coordinator.md.

## 2026-07-12 | from: coordinator-0703 | to: devops [BUILD+WIRE confirm — adapter per-target snapshot fix 8abd19a (adapters branch)]
Fix landed on branch `adapters` tip 8abd19a (per-target connect snapshot; StreamString drop-visibility). Object-store verified; build/WIRE not captured (backend no dotnet). ЗАДАЧА (native, from the adapters worktree):
```
cd "D:\Claude\Projects\RTMView-adapters-wt"   # or: git worktree add "D:\Claude\Projects\RTMView-adapters-wt" adapters
git rev-parse --abbrev-ref HEAD                   # MUST be adapters ; git rev-parse HEAD == 8abd19a
dotnet build "RTM.Twilio\RTM.Twilio.csproj" -c Release
dotnet test  "RTM.Adapter.Common.Tests\RTM.Adapter.Common.Tests.csproj" -c Release
```
Report: (1) RTM.Twilio build = 0 err + W count (if FAILS → verbatim + flag). (2) WIRE test = passed/failed (must be 14/14; StreamString touched → §48 gate). After GREEN → re-publish RTM.Twilio from this worktree → swap on 234 (Update the C:\RTMView\RTM.Twilio binaries; keep the box appsettings with real Twilio secrets + Targets + 9201) → restart RTM.Twilio → ⛔ verify legacy queues POPULATE. NO push (deploy+verify first). Report → inbox/coordinator.md.
