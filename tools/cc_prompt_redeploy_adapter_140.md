# RUNBOOK — 140 RTM.Twilio adapter redeploy (6ebd39f auto-reconnect). ⚠ SHARED adapter — touches LIVE legacy.
> status: DRAFT (devops-0625) -> coordinator §4 -> operator (MAINTENANCE WINDOW). ЧП #3: do NOT run until §4-blessed AND operator-timed. Run AFTER the build+WIRE gate (6ebd39f) is GREEN. ⚠ ALL commands ON THE 140 BOX.
> Swaps ONLY the RTM.Twilio binaries with the 6ebd39f build. Adapter is STATELESS (no DB, no pg_dump).

## ⛔ OPERATOR CONSTRAINT (2026-07-14): NEVER restart legacy RTM as part of this procedure (live prod, not ours). The adapter MUST self-reconnect to a STILL-RUNNING legacy pipe-server; only OUR RTMService may be bounced. If the adapter cannot reconnect to a running legacy -> that is a DEFECT to fix in the adapter, NOT a reason to restart legacy.

## ⛔⛔ CRITICAL — RTM.Twilio is the SHARED adapter feeding BOTH feeds
RTM.Twilio on 140 fans out to TWO targets: **legacy RTM (pipe/8088)** AND **our RTMService (rtmpipe_v3)**. Stopping/replacing it = a BRIEF interruption of BOTH feeds — **including the LIVE legacy production feed**. On restart the NEW per-target supervisor (6ebd39f) auto-reconnects both targets + re-sends per-target snapshots (that is the fix's purpose). **This is operator-timed in a maintenance window** (brief legacy blip). Get explicit operator go before STEP 2.

## ⛔ PRESERVE — DO NOT TOUCH
- **Legacy RTM (svc, 8088), our RTMService (cf18c8b, rtmpipe_v3)** — not stopped/replaced by this runbook.
- Garnet, ALL legacy (RTM.Nayax/C:\IceDash/DNN/IIS 443), *.insightense.com cert, ports 443/8088/8089/8444/9201.
- **RTM.Twilio appsettings.json on 140** — RTM:Targets (legacy {8088/rtmpipe} + our {8089/rtmpipe_v3}), the LIVE Twilio secrets, inbound Kestrel 9201. PRESERVE — swap binaries only.
- DB — untouched (adapter stateless; NO pg_dump).

## STEP 0 — [ON 140] Pre-checks + operator GO
```powershell
Get-Service RTM.Twilio, RTMService | ft Name,Status    # RTM.Twilio Running (feeding both), RTMService Running
Test-Path C:\RTMView\RTM.Twilio\appsettings.json
Get-Content C:\RTMView\RTM.Twilio\appsettings.json | Select-String 'Targets|Pipe|Url|9201'   # confirm both targets + 9201 present (do NOT print secrets aloud)
```
⚠ Confirm with operator: maintenance window OK for a brief legacy+our feed blip. If NO -> STOP/defer.

## STEP 1 — [ON 140] Stage + BACKUP current adapter binaries (no pg_dump — stateless)
```powershell
# operator transfers the published twilio\ output -> 140 C:\Temp\twilio_6ebd39f\
Test-Path C:\Temp\twilio_6ebd39f\RTM.Twilio.exe
# BACKUP current binaries dir (keep appsettings out of the swap)
$bk = "C:\RTMView\Backup\twilio_" + (Get-Date -Format yyyyMMdd_HHmm)
New-Item -ItemType Directory -Force -Path $bk | Out-Null
Copy-Item -Recurse -Force C:\RTMView\RTM.Twilio\* $bk
"backup: $bk"
```

## STEP 2 — [ON 140] Stop + swap binaries (PRESERVE appsettings) + start. (maintenance window)
```powershell
Stop-Service RTM.Twilio
Start-Sleep -Seconds 5
# preserve the live appsettings; replace only the binaries
Copy-Item C:\RTMView\RTM.Twilio\appsettings.json C:\Temp\twilio_appsettings_keep.json -Force
# swap: copy new published files over, then restore the kept appsettings
Copy-Item -Recurse -Force C:\Temp\twilio_6ebd39f\* C:\RTMView\RTM.Twilio\
Copy-Item C:\Temp\twilio_appsettings_keep.json C:\RTMView\RTM.Twilio\appsettings.json -Force
Start-Service RTM.Twilio
Start-Sleep -Seconds 10
Get-Service RTM.Twilio | ft Name,Status
```

## STEP 3 — [ON 140] Verify adapter + BOTH feeds restored
```powershell
# adapter running + inbound 9201 listening
Get-Service RTM.Twilio | ft Name,Status
Get-NetTCPConnection -LocalPort 9201 -State Listen -ErrorAction SilentlyContinue | ft LocalPort,State,OwningProcess
# adapter log: per-target supervisor connected to BOTH targets (reconnect -> connected), no wire errors
Get-Content C:\RTMView\RTM.Twilio\logs\*.log -Tail 30 -ErrorAction SilentlyContinue
```
Expect: RTM.Twilio Running; 9201 listening; log shows both targets connected (legacy + rtmpipe_v3).

## POST — RUNTIME SEAL (coordinator/operator): the auto-reconnect proof
Restart OUR RTMService (NOT the adapter): the adapter log must show "reconnecting in Ns" -> "connected" for the rtmpipe_v3 target WITHOUT an adapter restart; our RTM re-registers workgroups/users; **legacy target unaffected** throughout.
```powershell
# (operator) Restart-Service RTMService ; then watch adapter log for reconnect->connected on rtmpipe_v3
```

## §0.6b binding + report to .coord/cc/devops.md. self-§4: SHARED-adapter legacy-blip FLAGGED + operator-window-gated; PRESERVE appsettings(Targets+secrets+9201)+legacy+our-RTM+Garnet+DB; binaries backed up (no pg_dump, stateless); binary-only swap; all [ON 140]; NO push. PASS.
