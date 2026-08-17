# RUNBOOK (FINAL, §4-BLESSED) — 234 PARALLEL-RUN: our RTM (116416c) side-by-side with LEGACY, one adapter feeds BOTH

> status: §4-BLESSED (coordinator 2026-07-11) — operator host-admin on 234. Report-scoped, NO v3 barrier, NO git push.
> Source: .coord/legacy_port_line.md + .coord/parallel_run_box.md (box facts). End-state: PROLONGED side-by-side → eventual cutover to ours.

## CONCRETE TOPOLOGY (234)
| Component | service | exe / config | REST | pipe |
|---|---|---|---|---|
| LEGACY RTM (unpatched, MSSQL H_RTM) | **RTM** | C:\IceDash\RTM\RTM.exe · C:\IceDash\RTM\appsettings.json | 8088 → **8089** (config-only) · currently **STOPPED** | rtmpipe |
| OUR RTM (116416c) | **RTMService** | C:\RTMView\RTM\RTM.exe · C:\RTMView\RTM\appsettings.json | 8088 (stays) · Running | rtmpipe → **rtmpipe_v3** |
| OLD adapter (REMOVE) | **RTM.Test** | C:\IceDash\RTM.AmanSupport\RTM.Twilio.exe | inbound Kestrel **9201** · Running | — |
| NEW adapter (INSTALL) | **RTM.Twilio** | C:\RTMView\RTM.Twilio\RTM.Twilio.exe | inbound Kestrel **9201** (match RTM.Test) | fan-out BOTH |
- NEW adapter RTM:Targets = [{Url:"http://localhost:8089",Pipe:"rtmpipe"}(legacy), {Url:"http://localhost:8088",Pipe:"rtmpipe_v3"}(ours)].
- PRESERVE the LIVE Twilio block copied verbatim from RTM.Test's appsettings (this box's — AccountSid/AuthToken/WorkspaceSid + WorkgroupAttName="routing.skills" + Hebrew StatusGroups).
- PORT-STATE (confirmed): legacy STOPPED → ours holds 8088 uncontested, 8089 free → clean.

## STEP 0 — Pre-flight
1. Verify state: `Get-NetTCPConnection -LocalPort 8088,8089` (expect 8088=RTMService, 8089 free); `Get-Service RTM,RTMService,RTM.Test`.
2. BACKUP before any change → C:\RTMView\Backup\parallel_<ts>\: C:\IceDash\RTM\appsettings.json, C:\RTMView\RTM\appsettings.json, C:\IceDash\RTM.AmanSupport\appsettings.json.

## STEP 1 — Publish + stage NEW RTM.Twilio (build box → 234)
```
dotnet publish "10072026\RTM.Twilio\RTM.Twilio.csproj" -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtmtwilio"
```
Zip → copy to 234 → unzip to C:\RTMView\RTM.Twilio\. (RTM.Twilio.exe self-hosts as a Windows service via UseWindowsService().)

## STEP 2 — OUR RTM: PipeName=rtmpipe_v3 FIRST (frees the 'rtmpipe' name for legacy)
Edit C:\RTMView\RTM\appsettings.json, RTM section: add `"PipeName": "rtmpipe_v3"`. `Restart-Service RTMService`. Verify log `AppConfig.PipeName = rtmpipe_v3`. REST stays 8088.

## STEP 3 — LEGACY RTM: 8088→8089 (config-only) + START
Edit C:\IceDash\RTM\appsettings.json → Kestrel:Endpoints:Http:Url → http://<host>:8089 (legacy NOT code-patched). `Start-Service RTM` (was Stopped). Verify it listens on 8089 + pipe rtmpipe. (Now: ours=rtmpipe_v3/8088, legacy=rtmpipe/8089 — no pipe or port clash.)

## STEP 4 — Stop + disable OLD adapter RTM.Test
```
Stop-Service RTM.Test ; Set-Service RTM.Test -StartupType Disabled
```
(Keep installed for rollback. Frees inbound Kestrel 9201 for the new adapter — brief switchover gap: legacy momentarily unfed until STEP 5 starts; maintenance-window OK, stage fully first.)

## STEP 5 — Install + config + start NEW adapter RTM.Twilio
1. C:\RTMView\RTM.Twilio\appsettings.json:
```json
"Kestrel": { "Endpoints": { "Http": { "Url": "http://*:9201" } } },
"RTM": { "LogConfig": "C:\\RTMView\\RTM.Twilio\\log4net.config",
  "Targets": [ {"Url":"http://localhost:8089","Pipe":"rtmpipe"}, {"Url":"http://localhost:8088","Pipe":"rtmpipe_v3"} ] },
"Twilio": { <COPY VERBATIM from C:\IceDash\RTM.AmanSupport\appsettings.json — live AccountSid/AuthToken/WorkspaceSid/WorkgroupAttName=routing.skills/StatusGroups> }
```
2. Register + harden + start:
```
sc.exe create RTM.Twilio binPath= "C:\RTMView\RTM.Twilio\RTM.Twilio.exe" start= auto DisplayName= "RTM.Twilio (multi-target adapter)"
sc.exe failure RTM.Twilio reset= 86400 actions= restart/5000/restart/10000/restart/60000
Start-Service RTM.Twilio
```
3. ⚠ Verify Twilio's webhook URL points at this box:9201 (inherited from RTM.Test) — else inbound Twilio events stop.

## STEP 6 — VERIFY (both RTM instances fed)
- RTM.Twilio log: `CLIENT[rtmpipe] => connected to server` AND `CLIENT[rtmpipe_v3] => connected to server`.
- Our RTM: `AppConfig.PipeName = rtmpipe_v3`; dashboard platform.insightense.com LIVE (I re-verify /health 200 via Chrome).
- Legacy RTM (RTM): Running on 8089, receiving. Get-Service: RTM, RTMService, RTM.Twilio Running; RTM.Test Stopped/Disabled.

## ROLLBACK
```
Stop-Service RTM.Twilio ; sc.exe delete RTM.Twilio
Set-Service RTM.Test -StartupType Manual ; Start-Service RTM.Test
Stop-Service RTM   # legacy back to Stopped
# revert C:\IceDash\RTM\appsettings.json Url 8089->8088
# revert C:\RTMView\RTM\appsettings.json RTM:PipeName rtmpipe_v3 -> rtmpipe (or remove) ; Restart-Service RTMService
```
Restore configs from C:\RTMView\Backup\parallel_<ts>\.

## NOTES
- NO git push (deploy/config only). RTM.Twilio = separate module; our RTM Part B (116416c) already on origin/v3.
- ⚠ SECURITY (SF-SEC-001-class, NON-blocking, security-track): copying the live Twilio AuthToken into appsettings = plaintext; Twilio AuthToken + legacy MSSQL password were exposed in chat → rotate later.
- Keep RTM.Test installed (disabled) + all backups until side-by-side proven stable.
