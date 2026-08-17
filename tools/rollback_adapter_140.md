# ROLLBACK — 140 RTM.Twilio adapter (restore pre-swap state from latest backup)
> HELD — hand to operator ONLY if a redeploy step fails. Restores the exact pre-swap adapter (binaries + appsettings). Auto-finds the latest twilio_* backup made in STEP 1. ALL [ON 140].

```powershell
# [ON 140] ROLLBACK adapter RTM.Twilio -> latest backup
$bk = (Get-ChildItem C:\RTMView\Backup -Directory -Filter 'twilio_*' | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
if (-not $bk) { throw "No twilio_* backup found under C:\RTMView\Backup — STOP, do not proceed" }
"Restoring adapter from: $bk"

Stop-Service RTM.Twilio -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
# kill orphan exe under the adapter dir ONLY (filter \RTM.Twilio\ — never legacy / our RTMService)
Get-CimInstance Win32_Process | ? { $_.ExecutablePath -like 'C:\RTMView\RTM.Twilio\*' } | % { Write-Host "kill $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3

# restore full backup (old binaries + old appsettings with live Targets/secrets/9201)
Remove-Item -Recurse -Force C:\RTMView\RTM.Twilio\* -ErrorAction SilentlyContinue
Copy-Item -Recurse -Force "$bk\*" C:\RTMView\RTM.Twilio\

Start-Service RTM.Twilio
Start-Sleep -Seconds 10
Get-Service RTM.Twilio | ft Name,Status
Get-NetTCPConnection -LocalPort 9201 -State Listen -ErrorAction SilentlyContinue | ft LocalPort,State
Get-Content C:\RTMView\RTM.Twilio\logs\*.log -Tail 20 -ErrorAction SilentlyContinue
```

Expect after rollback: RTM.Twilio Running, 9201 listening, adapter log shows both targets (legacy + rtmpipe_v3) reconnected. Do NOT touch legacy RTM / RTMService / Garnet / DB.
