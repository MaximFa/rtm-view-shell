# RUNBOOK — 140 SHELL redeploy (baf8968: search/filters + tune). BINARY-ONLY, NO migration.
> status: DRAFT (devops-0625) -> coordinator §4 -> operator. ЧП #3: do NOT run until §4-blessed. Run AFTER build (baf8968 Full pkg). ⚠ ALL commands ON THE 140 BOX (nayax.insightense.com), NOT DEV. Independent of the adapter redeploy.
> Ships Shell code/CSS only (admin search+filters + table offset + funnel top-align + app.css?v=32). NO schema change. RTMService already cf18c8b — do NOT redeploy its binaries.

## ⛔ PRESERVE — DO NOT TOUCH
- RTM.Twilio (Phase-0 live), Garnet, ALL legacy (RTM/RTM.Nayax/C:\IceDash/DNN/IIS 443), *.insightense.com cert.
- Ports 8088 / 9201 / 443 / 8444. RTMService cf18c8b binaries preserved (-SkipRTM; Update bounces the service — fine, verify Running after).
- DB DATA + SCHEMA — no migration (NO -MigrationList). appsettings (slug=nayax) preserved.

## STEP 0 — [ON 140] Pre-checks (STOP if any fails)
```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"; Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Get-Service RTMViewShell, RTMService | ft Name,Status    # RTMService Running (cf18c8b)
@'
SELECT "Id","Slug","Name" FROM tenants ORDER BY "Slug";
SELECT count(*) AS platform_named FROM tenants WHERE "Name"='Platform';
'@ | Set-Content C:\Temp\pre.sql -Encoding Ascii
& $psql -U ccdashboard_user -d rtmviewdb -f C:\Temp\pre.sql   # expect 019f58ea/nayax; platform_named=1
```
If platform_named != 1 -> STOP.

## STEP 1 — [ON 140] Stage the baf8968 Full package (operator transfers <pkg>.zip -> 140 C:\Temp)
```
Remove-Item -Recurse -Force C:\Temp\rtm140full -ErrorAction SilentlyContinue
Expand-Archive C:\Temp\14072026.1423.zip -DestinationPath C:\Temp\rtm140full -Force
Get-ChildItem -Recurse C:\Temp\rtm140full -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass -Force
Test-Path C:\Temp\rtm140full\Update-RTMView.ps1
```

## STEP 2 — [ON 140] Verify Seed:PlatformTenantSlug=nayax present
```powershell
Get-Content C:\RTMView\Shell\appsettings.json | Select-String 'PlatformTenantSlug|SuperadminEmail'
```
Expect PlatformTenantSlug=nayax. If missing -> re-inject before start.

## STEP 3 — [ON 140] Deploy Shell binaries (BINARY-ONLY, no migration). 3 conditions.
```powershell
powershell -ExecutionPolicy Bypass -File C:\Temp\rtm140full\Update-RTMView.ps1 -SkipRTM -SkipCacheMigration -DBPassword '<ccdashboard_pw>'
```
- -DBPassword MANDATORY (pg_dump overwrites PGPASSWORD default ""). -SkipCacheMigration -> Garnet untouched. NO -MigrationList.
- Shell start: auto-migrate no-op; G-fixed seed (admin skip, no 23505); RTMService bounced back cf18c8b. (drift-gate WARN-skip = known, harmless.)

## STEP 4 — [ON 140] Verify
```powershell
Start-Service RTMViewShell -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
Get-Service RTMViewShell, RTMService | ft Name,Status    # BOTH Running
Write-Host "--- /health ---";       curl.exe -sk https://localhost:8444/health
Write-Host "`n--- /health/ready ---"; curl.exe -sk https://localhost:8444/health/ready
Write-Host "--- Shell log tail ---"; Get-Content C:\Windows\System32\logs\log-20260714.txt -Tail 15 -ErrorAction SilentlyContinue
```
Expect: both Running, Healthy, NO superadmin 23505.

## POST — coordinator 140 visual: (a) Metrics/202 pagination fully visible + sticky header + internal scroll; (b) filter funnels top-aligned (1- and 2-line headers); (c) BU/SG/Sites/InfoSlots search narrows + per-field dropdown filters narrow + clear restores. (Hard-refresh Ctrl+F5 for app.css?v=32.)

## §0.6b binding + report to .coord/cc/devops.md. self-§4: PRESERVE incl RTMService(cf18c8b)+DB(no migration); pg_dump-first; -DBPassword+-SkipCacheMigration; single-Platform precheck; slug preserved; ALL [ON 140]; NO push. PASS.
