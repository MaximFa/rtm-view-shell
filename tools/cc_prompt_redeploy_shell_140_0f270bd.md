# RUNBOOK — 140 SHELL redeploy (0f270bd: Defect K + grid headers). BINARY-ONLY, NO migration.
> status: DRAFT (devops-0625) -> coordinator §4 -> operator. ЧП #3: do NOT run until §4-blessed. Run AFTER build (0f270bd Full pkg).
> Ships Shell code (Defect K NGC-flush + CSS headers) + the updated catalog. NO schema change this batch (GAP-1 metric goes via the UI Deploy tab AFTER). RTMService already cf18c8b — do NOT redeploy its binaries.

## ⛔ PRESERVE — DO NOT TOUCH
- RTM.Twilio (Phase-0 live), Garnet, ALL legacy (RTM/RTM.Nayax/C:\IceDash/DNN/IIS 443), *.insightense.com cert.
- Ports 8088 / 9201 / 443 / 8444. **RTMService cf18c8b binaries preserved (-SkipRTM skips only the binary redeploy; Update DOES bounce the service stop+start — that's fine, verify Running after).**
- **DB DATA + SCHEMA — no migration this batch (NO -MigrationList).**

## STEP 0 — Pre-checks (STOP if any fails)
```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"; Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
Get-Service RTMViewShell, RTMService | ft Name,Status    # RTMService Running (cf18c8b)
# find-by-Name seed idempotency still needs exactly ONE Platform-named tenant
@'
SELECT "Id","Slug","Name" FROM tenants ORDER BY "Slug";
SELECT count(*) AS platform_named FROM tenants WHERE "Name"='Platform';
'@ | Set-Content C:\Temp\pre.sql -Encoding Ascii
& $psql -U ccdashboard_user -d rtmviewdb -f C:\Temp\pre.sql   # expect 019f58ea/nayax; platform_named=1
```
If platform_named != 1 -> STOP (seed would dup on Shell start).

## STEP 1 — Stage new Full package (operator transfers the 0f270bd Full *.zip -> 140 C:\Temp)
```
Remove-Item -Recurse -Force C:\Temp\rtm140full -ErrorAction SilentlyContinue
Expand-Archive C:\Temp\14072026.1041.zip -DestinationPath C:\Temp\rtm140full -Force
Get-ChildItem -Recurse C:\Temp\rtm140full -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass -Force
```

## STEP 2 — Verify appsettings still carries Seed:PlatformTenantSlug=nayax (Update preserves it; no set needed)
```powershell
Get-Content C:\RTMView\Shell\appsettings.json | Select-String 'PlatformTenantSlug|SuperadminEmail'
```
Expect PlatformTenantSlug=nayax present. If MISSING (unexpected) -> re-inject as in the prior runbook before start.

## STEP 3 — Deploy Shell binaries (BINARY-ONLY, no migration). Same 3 conditions.
```powershell
powershell -ExecutionPolicy Bypass -File C:\Temp\rtm140full\Update-RTMView.ps1 -SkipRTM -SkipCacheMigration -DBPassword '<ccdashboard_pw>'
```
- -DBPassword MANDATORY (internal pg_dump overwrites PGPASSWORD with $DBPassword default "" -> abort AFTER both stopped -> both DOWN).
- -SkipCacheMigration -> Garnet untouched.
- NO -MigrationList (no schema change). Shell start auto-migrate = no-op (no pending); seed G-fixed (find Platform by Name -> admin skip). RTMService bounced back to cf18c8b.
- (Known non-blocker: drift-gate WARN-skips due to Update path bug — harmless, binary-only.)

## STEP 4 — Verify
```powershell
Start-Service RTMViewShell -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
Get-Service RTMViewShell, RTMService | ft Name,Status    # BOTH Running
Write-Host "--- /health ---";       curl.exe -sk https://localhost:8444/health
Write-Host "`n--- /health/ready ---"; curl.exe -sk https://localhost:8444/health/ready
# no NEW startup errors (superadmin 23505 must NOT appear)
Write-Host "--- Shell log tail ---"; Get-Content C:\Windows\System32\logs\log-20260714.txt -Tail 15 -ErrorAction SilentlyContinue
```
Expect: both Running, /health + /health/ready Healthy, NO superadmin 23505.

## POST — coordinator visual: SG/BU/Site persist (Defect K d30e9b4) + grid headers As-Is/wrap/top (0f270bd). Then operator places the metric-deploy-package + Deploy tab (GAP-1 QueueNumberOfCompletedIncomingCalls hot-compile) — separate step, NOT in this runbook.

## §0.6b binding + report to .coord/cc/devops.md. self-§4: PRESERVE incl RTMService(cf18c8b)+DB(no migration); pg_dump-first; -DBPassword+-SkipCacheMigration; single-Platform-tenant precheck; slug preserved; passwords operator-side; NO push. PASS.
