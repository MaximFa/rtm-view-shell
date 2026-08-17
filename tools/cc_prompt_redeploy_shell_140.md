# RUNBOOK — 140 SHELL redeploy (Defect F/G/H fix: f486e4c) + migration H. Clears the Shell restart-crash.
> status: DRAFT (devops-0625) -> coordinator §4 -> operator. ЧП #3: do NOT run until §4-blessed. Run AFTER build (f486e4c Full pkg).
> Redeploys SHELL binaries + applies the per-tenant username index migration (H). RTMService is already cf18c8b/Running — LEAVE IT.

## ⛔ PRESERVE — DO NOT TOUCH
- RTM.Twilio (Phase-0 live, feeding rtmpipe_v3), Garnet, ALL legacy (RTM/RTM.Nayax/C:\IceDash/DNN/IIS 443), *.insightense.com cert.
- Ports 8088 / 9201 / 443 / 8444. **RTMService: cf18c8b BINARIES preserved (-SkipRTM skips only the binary redeploy) — but Update-RTMView DOES stop+start (BOUNCE) the service (stop@106-115/start@392-401 ignore -SkipRTM). ⭐ That bounce re-triggers the adapter feed on rtmpipe_v3 -> getOrCreateQueue(cf18c8b) -> NGC_Queues seal is delivered by THIS redeploy. Do NOT replace RTM binaries; verify RTMService=Running after (COND-B1).**
- DB DATA (only the H migration alters SCHEMA — adds per-tenant username index, drops global UserNameIndex).

## STEP 0 — Pre-checks (STOP if any fails)
```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
# (a) RTMService must be Running cf18c8b — do NOT touch
Get-Service RTMService | ft Name,Status
# (b) dup platform tenant 019f5978 MUST be deleted -> exactly ONE tenant Name='Platform' (find-by-Name idempotency needs this)
@'
SELECT "Id","Slug","Name" FROM tenants ORDER BY "Slug";
SELECT count(*) AS platform_named FROM tenants WHERE "Name"='Platform';
'@ | Set-Content C:\Temp\pre.sql -Encoding Ascii
& $psql -U ccdashboard_user -d rtmviewdb -f C:\Temp\pre.sql   # expect: 019f58ea/nayax only; platform_named = 1
# (c) C1 pre-migration probe — MUST be 0 rows or STOP (per-tenant unique index can't build with dups)
@'
SELECT "NormalizedUserName","TenantId",count(*) FROM identity.users WHERE "IsActive"=true GROUP BY 1,2 HAVING count(*)>1;
'@ | Set-Content C:\Temp\c1.sql -Encoding Ascii
& $psql -U ccdashboard_user -d rtmviewdb -f C:\Temp\c1.sql    # expect: 0 rows
```
If platform_named != 1 (dup not deleted) OR C1 returns any row -> STOP, report to coordinator. Do NOT proceed.

## STEP 1 — Stage new Full package (operator transfers the f486e4c Full *.zip -> 140 C:\Temp)
```
Expand-Archive C:\Temp\13072026.0802.zip -DestinationPath C:\Temp\rtm140full -Force
Get-ChildItem -Recurse C:\Temp\rtm140full -Filter *.ps1 | Unblock-File
Set-ExecutionPolicy -Scope Process Bypass -Force
```

## STEP 2 — Set Seed:PlatformTenantSlug=nayax in the DEPLOYED Shell appsettings BEFORE start
a261840 finds the platform tenant by Name=='Platform' and syncs its slug to Seed:PlatformTenantSlug. If unset, G would re-sync slug nayax->platform. Set it to nayax to KEEP slug=nayax (FQDN resolution).
```powershell
# operator edits C:\RTMView\Shell\appsettings.json Seed section: add "PlatformTenantSlug": "nayax" (atomic UTF-8; preserve ConnectionStrings/Redis/Kestrel/cert)
Get-Content C:\RTMView\Shell\appsettings.json | Select-String 'Seed|PlatformTenantSlug|SuperadminEmail'
```

## STEP 3 — Deploy Shell binaries only (RTMService untouched). Update-RTMView -SkipRTM (pg_dump backup mandatory).
Update-RTMView takes a pg_dump backup FIRST, backs up the Shell dir, deploys Shell binaries, preserves appsettings (incl the STEP2 edit), and restarts RTMViewShell. RTMService (-SkipRTM) is not touched.
```powershell
# COND-B2 (CRITICAL): -DBPassword is MANDATORY. Update-RTMView's internal pg_dump (@140) OVERWRITES $env:PGPASSWORD with $DBPassword (default "") -> without it the backup aborts @[2b/5] AFTER both services are stopped -> both DOWN + no backup.
# COND-B3: -SkipCacheMigration so the Full pkg's Extras\Garnet [4b/5] step does not Set/Start the live Garnet service.
powershell -ExecutionPolicy Bypass -File C:\Temp\rtm140full\Update-RTMView.ps1 -SkipRTM -SkipCacheMigration -DBPassword '<ccdashboard_pw>'
```
- Mode Full pkg includes db/ tools -> Compare-ToBaseline.ps1 should be found this time (last round's gap was RTM-mode zip). If drift gate still WARN-skips, that's OK (binary+single-migration).
- The H migration (PerTenantUserNameIndex) is applied when RTMViewShell STARTS (DatabaseInitializer migrate = migrate-only path, Defect-B-safe), THEN seed (G-fixed: finds 019f58ea by Name='Platform' -> admin found -> skip; NO 23505) -> clean start.
- ⚠ If -SkipRTM leaves RTMViewShell Stopped at [5/5] (as -SkipShell did for the other service), run: `Start-Service RTMViewShell`.

## STEP 4 — Verify (clears Defect F)
```powershell
Start-Service RTMViewShell -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
Get-Service RTMViewShell, RTMService | ft Name,Status    # BOTH Running (RTMService bounced but back up on cf18c8b — COND-B1)
Write-Host "--- /health ---";       curl.exe -sk https://localhost:8444/health
Write-Host "--- /health/ready ---"; curl.exe -sk https://localhost:8444/health/ready
# NO 23505 in the service log; migration H applied
Get-Content C:\Windows\System32\logs\log-20260713.txt -Tail 20
```
Expected: RTMViewShell Running, /health + /health/ready = Healthy, NO 23505 / NO 'duplicate key', seed skipped admin (found by Name), migration H in place.

## POST — NGC_Queues seal is delivered by the RTMService bounce (adapter re-feeds rtmpipe_v3 -> getOrCreateQueue cf18c8b). Hand coordinator §A#4 (superadmin login / dashboards / clean log) + `SELECT COUNT(*) FROM "NGC_Queues" WHERE "TenantId"='019f58ea-0c56-7792-a5f2-dafacec8a848';` > 0 + BU->Queues picker.

## §0.6b binding + report to .coord/cc/devops.md. self-§4: PRESERVE incl RTMService(cf18c8b)+DB-data; pg_dump backup FIRST; C1 probe gates the index migration; dup-tenant precheck (find-by-Name); Seed:PlatformTenantSlug=nayax before start; -SkipRTM (RTM untouched); passwords operator-side; NO push. PASS.
