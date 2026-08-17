# Parallel-run box specifics (234) — answers as collected

## (a) OLD adapter RTM.Test — COLLECTED 2026-07-11
- Service: RTM.Test | State: Running | StartMode: **Manual**
- exe: C:\IceDash\RTM.AmanSupport\RTM.Twilio.exe  (old RTM.Twilio build, single-target)
- folder: C:\IceDash\RTM.AmanSupport\
- Kestrel INBOUND (Twilio webhook target): **http://*:9201**  → NEW RTM.Twilio MUST listen on 9201 (runbook said 9200 — CORRECT to 9201)
- RTM:RTM_URL = http://localhost:8088  (current single target on 8088)
- Twilio block: PRESENT (AccountSid/AuthToken/WorkspaceSid + WorkgroupAttName="routing.skills" + AgentStatusIgnoreList + StatusNames + StatusGroups[SIGNOFF/PAPERWORK/...]). SECRETS stay box-side (copy from this file into new config box-side; NOT in any coord/chat).
- ⚠ AuthToken was pasted in chat once → treat as EXPOSED → rotate later (security follow-up).
- NOTE: WorkgroupAttName here = "routing.skills" (differs from the staging sample "workgroups") — the NEW RTM.Twilio must inherit THIS box's live Twilio block verbatim, not the staging appsettings.

## (b) LEGACY RTM Service — COLLECTED 2026-07-11
- Service name: **RTM** | REST port: **http://*:8088** (this is the CURRENT 8088 owner) → move to **8089** (config-only)
- Backend: MSSQL H_RTM (ConnectionString: Data Source=localhost, Catalog=H_RTM, User RTM_User) — LEGACY DB, distinct from our PostgreSQL.
- RTM section: AgentWGPerfixList (ק_,מוקד_), CalcInterval 2, DefaultTimeZone "+03:00". NO TenantId, NO PipeName (older single-tenant build).
- Pipe: legacy hosts "rtmpipe" (unpatched, unchanged).
- folder: **C:\IceDash\RTM\** (RTM.exe). Service STATE = **Stopped** (Manual) — currently NOT bound to 8088.
- ⚠ MSSQL password pasted in chat → EXPOSED → rotate later (security follow-up). NOT stored here.
- CONFIRMS: 8088 = legacy "RTM" now; our RTMService(8088) can't co-bind → the 8089 move is required. RTM.Test RTM_URL=8088 → feeds legacy RTM. Consistent.
## (c) OUR RTM Service — COLLECTED 2026-07-11
- Service: **RTMService** @ C:\RTMView\RTM\RTM.exe | Running (Auto) | port **8088** | pipe currently "rtmpipe" (Part B default) → set RTM:PipeName="rtmpipe_v3".
- (RTMViewShell @ C:\RTMView\Shell Running; RTMApplyService Running — our stack.)
## (d) PORT-STATE — RESOLVED 2026-07-11 (from service list)
- Legacy "RTM" = **STOPPED** → 8088 currently held by OUR RTMService uncontested. 8089 free.
- RTM.Test (RTM_URL=8088) currently feeds OUR RTMService (legacy off). No live clash right now.
- ⇒ port move is clean: legacy config 8088→8089 then START legacy; ours stays 8088.

## FULL SERVICE MAP (234)
| Service | State | Path | Role |
|---|---|---|---|
| RTM | Stopped | C:\IceDash\RTM\RTM.exe | LEGACY RTM (8088→8089, MSSQL H_RTM, pipe rtmpipe) |
| RTM.Test | Running | C:\IceDash\RTM.AmanSupport\RTM.Twilio.exe | OLD adapter (9201 inbound, →replace) |
| RTMService | Running | C:\RTMView\RTM\RTM.exe | OUR RTM (8088, →pipe rtmpipe_v3) |
| RTMViewShell | Running | C:\RTMView\Shell\... | our Shell |

## ORDER REFINEMENT (avoid double-"rtmpipe" window)
Our RTMService currently hosts "rtmpipe". Legacy will host "rtmpipe" on start. To avoid two servers on the same pipe:
SEQUENCE: (1) our RTMService PipeName=rtmpipe_v3 + restart (frees "rtmpipe"; REST 8088 unaffected) → (2) legacy RTM config 8088→8089 + START (takes "rtmpipe" + 8089) → (3) stop RTM.Test → (4) install+start RTM.Twilio (inbound 9201, Targets both). RTM.Twilio inbound MUST be 9201 (Twilio webhook target); inherit RTM.Test's LIVE Twilio block (WorkgroupAttName="routing.skills").


## ⚠ TOPOLOGY CLARIFIED 2026-07-11 — TWO boxes
- **234** (prod server): RTMService + legacy RTM + RTM.Test + live Twilio feed. STEP 0 (backup+box-specifics) done HERE. STEP 2-6 run HERE.
- **DEV** (has git repo + dotnet SDK + adapters worktree): STEP 1 publish done HERE → RTM.Twilio published, zipped (RTM.Twilio_adapters_dfe6f17.zip), transferred + unpacked to 234 C:\RTMView\RTM.Twilio\.
- The RTMService appsettings shown mid-STEP2 (Kestrel 8088, no PipeName) was the **DEV** copy — 234's may differ; STEP 2 on 234 must re-show 234's config before editing.
- Box-specifics (a/b/c/d) = 234's (correct). Publish artifact came from DEV.


## ✅ PARALLEL-RUN LIVE 2026-07-12 — both RTM fed by RTM.Twilio (one live Twilio feed)
- Final topology on 234: legacy RTM (svc RTM) rtmpipe/8089 Running (fed, C:\Logs\RTM\log.txt fresh); our RTMService rtmpipe_v3/8088 Running (fed, C:\RTMView\RTM\Logs\RTM.log fresh interactions/status); RTM.Twilio (multi-target adapter, inbound 9201) Running, fan-out to BOTH; RTM.Test Stopped+Disabled.
- Recovery done: initial legacy-pipe fail (legacy single-shot pipe died when RTM.Test disconnected) → fixed by restart RTMService→legacy→RTM.Twilio (both servers fresh, adapter reconnected to both). pipe=rtmpipe errors ceased; both RTM logs show live data.
- Architecture validated end-to-end: RTM.Adapter.Common (minimal RTM-independent lib) + multi-target fan-out + configurable pipe-name (rtmpipe_v3) + WIRE contract — all working on prod live feed.

## ⚠ OPERATIONAL FRAGILITY (must fix for durable side-by-side)
- Adapter has NO auto-reconnect + legacy pipe server is SINGLE-SHOT (no re-listen after a client disconnects).
- ⇒ ANY restart (RTMService / legacy RTM / RTM.Twilio / reboot) breaks the fan-out → needs the manual recovery sequence (restart RTMService + legacy + RTM.Twilio, in order, ~15s for legacy pipe to come up).
- REAL FIX (queued): add AUTO-RECONNECT to the adapter (our code, adapters branch, full cycle) → adapter self-heals pipe drops → restarts stop being fragile.
- AdaptorServiceName on our RTMService = "RTM.Test" (disabled) left AS-IS (changing→restart→recovery-dance). Revisit with the auto-reconnect fix.

## SECURITY follow-ups (non-blocking, security-track): Twilio AuthToken + MSSQL/PG passwords exposed in chat (rotate); adapter logs full webhook payload incl. account_sid (redact in adapter logging).
