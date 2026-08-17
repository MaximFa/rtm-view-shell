# RUNBOOK — 140 BINARY-ONLY RTMService redeploy (cf18c8b NGC_Queues fix). NOT a fresh install.
> status: AMENDED (devops-0625) per coordinator §4 BLESS-WITH-COND (03:00Z) -> resubmit for quick re-confirm. Run AFTER build A produces the package. ЧП #3.
> Swaps ONLY RTMService binaries on 140 with the cf18c8b RTM package; preserves 140 config + DB. Flag#2 RESOLVED: RTM.Twilio on 140 already fans out to rtmpipe_v3 -> seal achievable.

## ⛔ PRESERVE — DO NOT TOUCH
- RTM.Twilio (Phase-0 live, already feeding rtmpipe_v3), Garnet, ALL legacy (RTM/RTM.Nayax/C:\IceDash/DNN/IIS 443), *.insightense.com cert.
- Ports 8088 / 9201 / 443 / 8444. **The DB rtmviewdb** (no schema change — binary-only).
- 140 RTMService appsettings: PipeName rtmpipe_v3, Kestrel Port 8089, AdaptorServiceName (⚠ KEEP EMPTY in parallel-run — see note), AgentWGPerfixList (Hebrew).

## STEP 1 — Stage new RTM package (operator transfers the cf18c8b *_RTM*.zip -> 140 C:\Temp)
```
Expand-Archive C:\Temp\13072026.0605_RTM.zip -DestinationPath C:\Temp\rtm140rtm -Force
Get-ChildItem -Recurse C:\Temp\rtm140rtm -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass -Force
```

## STEP 2 — ⚠ COND#1: SET RTM:TenantId = 019f58ea BEFORE any redeploy/start (deterministic; Update auto-starts at end)
Update-RTMView -SkipShell PRESERVES the existing C:\RTMView\RTM\appsettings.json AND auto-starts RTMService at the END of its run. So RTM:TenantId MUST already be the 140 platform tenant = **019f58ea-0c56-7792-a5f2-dafacec8a848** BEFORE Update runs, else the auto-start hits §33.2 FATAL (TenantId=Guid.Empty).
```powershell
# VERIFY current, then SET if not 019f58ea (atomic UTF-8; preserve PipeName/Port/AdaptorServiceName/AgentWGPerfixList)
Get-Content C:\RTMView\RTM\appsettings.json | Select-String 'TenantId|PipeName|Port|AdaptorServiceName'
```
If TenantId != 019f58ea-0c56-7792-a5f2-dafacec8a848 -> operator sets it (UTF-8 save). (RTMService may already be running with it set — if so, verify only.) DoD of this step: appsettings TenantId == 019f58ea before proceeding.

## STEP 3 — Stop RTMService + orphan-kill ONLY under C:\RTMView\RTM\ (so binaries aren't locked during swap)
```powershell
Stop-Service RTMService -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
# Filter trailing \RTM\ ONLY — must NEVER match C:\RTMView\RTM.Twilio\*
Get-CimInstance Win32_Process | ? { $_.ExecutablePath -like 'C:\RTMView\RTM\*' } | % { Write-Host "Kill PID $($_.ProcessId): $($_.ExecutablePath)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
```

## STEP 4 — COND#3: ensure DB creds available, then binary swap (Update-RTMView -SkipShell)
Update-RTMView runs a MANDATORY pg_dump backup + Compare-ToBaseline drift gate (needs PGPASSWORD / DB creds). It aborts SAFELY (pre-swap) if creds absent. Operator: stage PGPASSWORD (or the postgres creds) on 140 before running.
```powershell
$env:PGPASSWORD='<postgres-or-app-pw>'   # operator sets on box, not in chat
powershell -ExecutionPolicy Bypass -File C:\Temp\rtm140rtm\Update-RTMView.ps1 -SkipShell
```
- COND#2 note: `-SkipShell` PRESERVES Shell binaries + config, but the Shell service IS briefly BOUNCED during the update run — expect a short Shell blip (health returns after). RTM binaries only are swapped.
- DRIFT GATE [E1]: 140 DB was fresh-provisioned from the package baseline (shakedown) -> Compare-ToBaseline should be CLEAN. If it unexpectedly ABORTS on drift -> STOP + report to coordinator (do NOT blanket -SkipDrift).
- Update preserves appsettings (incl the STEP 2 TenantId) and auto-starts RTMService at the end.

## STEP 5 — Verify
```powershell
Get-Service RTMService | ft Name,Status
# RTM startup log: AppConfig.TenantId = 019f58ea-... and NO FATAL (TenantId not Guid.Empty)
```

## POST — RUNTIME SEAL (coordinator/operator; achievable — adapter already feeds rtmpipe_v3)
- After redeploy, RTM.Twilio re-sends workgroups -> getOrCreateQueue (cf18c8b) fires -> NGC_Queues populates.
- `SELECT COUNT(*) FROM "NGC_Queues" WHERE "TenantId"='019f58ea-0c56-7792-a5f2-dafacec8a848';` > 0
- Shell UI: BU Edit -> Queues picker lists queues.

## §0.6b binding + report to .coord/cc/devops.md. self-§4: preserve-scope explicit; TenantId set BEFORE any start (COND#1); -SkipShell bounce noted (COND#2); DB creds staged for pg_dump+drift (COND#3); orphan-kill scoped \RTM\ only; binary-only, DB untouched; passwords operator-side; NO push. PASS.

## ⚠ PARALLEL-RUN SAFETY — AdaptorServiceName MUST stay EMPTY on 140
RTMAdapter.cs (77-142): if RTM:AdaptorServiceName is set, OUR RTMService RESTARTS/STOPS that service on its own start/stop. Setting it = RTM.Twilio would make our RTM bounce the SHARED adapter that currently feeds LEGACY -> PRESERVE violation. Empty -> 'skipping service restart/stop'. The NGC_Queues seal does NOT need it: the adapter re-sends its snapshot on pipe (rtmpipe_v3) RECONNECT when our RTMService restarts. So KEEP AdaptorServiceName empty; do NOT set RTM.Twilio. (Supersedes the earlier 'preserve AdaptorServiceName=RTM.Twilio' expectation for parallel-run.)
