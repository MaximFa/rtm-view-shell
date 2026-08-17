# RUNBOOK — Server 140 CLEAN FRESH-INSTALL (Design-B shakedown of the canonical process)

> status: DRAFT (devops-0625) -> coordinator §4 -> operator (ADMIN on 140). ЧП #3: do NOT hand a run until §4-blessed.
> Goal: shake down the canonical prod-tooling fresh install of OUR stack on 140, alongside (NOT disturbing) the live legacy + RTM.Twilio(Phase 0). Package: Installations\13072026.0323.zip (SHA bd6079..., db/ tree in zip, unit 260/260).

## ⛔ PRESERVE — DO NOT TOUCH (Phase-0 live on 140)
- **RTM.Twilio** service (feeding LEGACY right now). Garnet cache. ALL legacy: RTM / RTM.Nayax / C:\IceDash / DNN / IIS :443. `*.insightense.com` cert.
- Ports 8088 / 9201 / 443 — untouched. Inert leftover `C:\Program Files\RTM\RTM.Nayax` = IGNORE.
- ONLY OUR stack is wiped: svc `RTMViewShell` + `RTMService`; dirs `C:\RTMView\Shell` + `C:\RTMView\RTM`; DB `rtmviewdb` (dropped by Provision-FreshDb via -FreshDb).

## STEP 0 — Pre-flight (operator; confirm before ANY wipe)
```
Get-Service | ? { $_.Name -in 'RTMViewShell','RTMService','RTM.Twilio','Garnet' -or $_.DisplayName -match 'RTM|Garnet' } | ft Name,Status,StartType
Get-NetTCPConnection -LocalPort 8088,8089,9201,443,8444 | ft LocalAddress,LocalPort,State,OwningProcess
```
Confirm: RTM.Twilio + Garnet + legacy RUNNING and will NOT be touched; 8089 + 8444 FREE for ours.

## STEP 1 — WIPE OUR stack ONLY (operator, ADMIN). ⚠ Close services.msc / Task Manager FIRST (clears DELETE_PENDING so STEP 3 sc-create succeeds).
```
Stop-Service RTMViewShell,RTMService -ErrorAction SilentlyContinue

Write-Host "Waiting 60s for processes to release file locks..."
Start-Sleep -Seconds 60   # operator-requested pause between stop and delete

# Kill ORPHAN exes that survive Stop-Service and LOCK the DLLs (lesson deploy_kestrel_orphan_exe).
# ⛔ Filter on trailing \Shell\ and \RTM\ ONLY — must NEVER match C:\RTMView\RTM.Twilio\* (Phase-0 live).
Get-CimInstance Win32_Process | ? { $_.ExecutablePath -like 'C:\RTMView\Shell\*' -or $_.ExecutablePath -like 'C:\RTMView\RTM\*' } | % { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

sc.exe delete RTMViewShell ; sc.exe delete RTMService
Remove-Item -Recurse -Force C:\RTMView\Shell, C:\RTMView\RTM -ErrorAction SilentlyContinue
```
(rtmviewdb is dropped by Provision-FreshDb in STEP 3 — do NOT drop it by hand. Do NOT delete C:\RTMView\RTM.Twilio, nor Garnet, nor anything legacy. If Remove-Item still fails on a lock: confirm services.msc/Task Manager are closed, then elevated retry.)

## STEP 2 — Stage the package
```
Copy Installations\13072026.0323.zip -> 140 C:\Temp\
Expand-Archive C:\Temp\13072026.0323.zip -DestinationPath C:\Temp\rtm140 -Force
Get-ChildItem -Recurse C:\Temp\rtm140 -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass -Force
```

## STEP 3 — Install (canonical prod tooling ONLY — zero hand-runs). Passwords: operator enters on the box, NEVER in chat.
```
powershell -ExecutionPolicy Bypass -File C:\Temp\rtm140\Install-RTMView.ps1 -Mode Full -FreshDb -NoStartServices `
  -RTMPort 8089 -RTMPipeName rtmpipe_v3 -AdaptorServiceName RTM.Twilio `
  -ShellHttpsPort 8444 -Fqdn nayax.insightense.com -CertSubject insightense.com `
  -RedisPassword <op> -SuperadminPassword <op> -DBAppPassword <op> -DBPassword <op>
```
- ⚠ PARAM CORRECTION (verified vs Install-RTMView.ps1): the postgres SUPERUSER password param is **-DBPassword** (NOT -SuperPassword). Install-RTMView maps -DBPassword -> Provision-FreshDb -SuperPassword and -DBAppPassword -> -AppPassword internally (L489-495). Passwords: -DBPassword=postgres super; -DBAppPassword=ccdashboard_user; -RedisPassword=Garnet; -SuperadminPassword=Shell superadmin.
- ⚠ **-RedisPassword = the password of the EXISTING live Garnet** on 140 (Garnet is PRESERVED, NOT reinstalled — the Garnet [2/6] branch skips when the service already exists). The operator MUST pass the live Garnet pw so the Shell Redis conn-string injected in [4b] matches the running cache; a wrong value = Shell cannot reach cache.
- -FreshDb -> Provision-FreshDb: drop rtmviewdb -> init -> migrate(shell exe) -> schema.sql -> functions -> data.
- -NoStartServices: register RTMViewShell+RTMService but do NOT start (RTM DB/TenantId not ready).

## STEP 4 — Post: start Shell + verify (operator captures; I re-verify /health via Chrome)
```
Start-Service RTMViewShell
```
- https://nayax.insightense.com:8444/health = 200 AND /health/ready = 200.
- Superadmin login OK at the Shell.
- `psql -U ccdashboard_user -d rtmviewdb -c 'SELECT COUNT(*) FROM \"RTSGrid_Metric\";'` > 0.
- Shell log clean (no startup errors).
- RTMService stays STOPPED / config-pending: its RTM:TenantId is set AFTER the Nayax tenant is created in the Shell UI (= Phase B). Do NOT start RTMService now.

## ROLLBACK / SAFETY
- Failure impact is contained to OUR stack (fresh); legacy + RTM.Twilio + Garnet untouched -> 140 legacy keeps serving. If the install fails: re-run after fixing, or leave our services absent (legacy unaffected). No prod-data rollback needed (rtmviewdb is fresh/ours).

## FLAGS for coordinator (§4)
1. Corrected -SuperPassword -> **-DBPassword** (Install-RTMView has no -SuperPassword; it maps -DBPassword to Provision's -SuperPassword).
2. GARNET preserve: Install-RTMView [2/6] Garnet branch SKIPS when the service already exists (`Get-Service Garnet` -> "already exists"), so -Mode Full will NOT clobber the live Garnet. It passes -RedisPassword but does NOT re-register/reconfig an existing Garnet. If you want a hard guarantee, add **-SkipRedis** (but confirm the Shell still gets the Redis conn-string). Recommend: keep as-is (branch skips) OR -SkipRedis + verify conn-string.
3. SECURITY (SF-SEC-001-class, non-blocking): db/tools/Provision-FreshDb.ps1 has a HARDCODED default -AppPassword "!@#qweASDzxc" (L31). Install passes -DBAppPassword so the operator value overrides it, but the hardcoded default should be scrubbed (security-track).

## §0.6b binding + report to .coord/cc/devops.md. self-§4: preserve-scope explicit, wipe-scope narrow, backup N/A (fresh), verify present, passwords operator-side, NO push. PASS.
