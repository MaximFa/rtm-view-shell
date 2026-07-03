# Prod-parity local validation env — RUNBOOK ("собираем и проверяем")

> Purpose: stand up the LOCAL validation env IDENTICAL to prod — Garnet + Shell + RTM as Windows
> services via the SAME `Install-RTMView.ps1` the prod deploy uses [VALIDATION-ENV-01]. QA validates
> exactly what ships to 234. Return here any time by saying **"собираем и проверяем"**.
> Password below = LOCAL dev ccdashboard_user (SF-SEC-001, local only — never a prod secret).

## S0 — ONE-TIME host setup (binaries into the DEFAULT cache — do once)
Build reads Garnet+nssm from `tools\cache\` by default. Place them ONCE with the correct **FLAT**
layout — `GarnetServer.exe` must sit at the TOP of the cache folder, NOT inside a `net8.0` subfolder
(both Build and Install expect `<dir>\GarnetServer.exe` flat):
```
robocopy "C:\Garnet\net8.0" "D:\Claude\Projects\RTM View Shell\tools\cache\garnet-1.1.10-win-x64-net8" /E
# nssm was NOT used in the POC (Garnet ran foreground) — obtain ONCE (free, public-domain):
#   download https://nssm.cc/release/nssm-2.24.zip, extract, then copy win64\nssm.exe:
copy "<extracted>\nssm-2.24\win64\nssm.exe" "D:\Claude\Projects\RTM View Shell\tools\cache\nssm\nssm.exe"
```
Verify (must exist, FLAT): `dir "D:\Claude\Projects\RTM View Shell\tools\cache\garnet-1.1.10-win-x64-net8\GarnetServer.exe"`

## "собираем" — build the Full package from current v3
```
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -SkipDB
```
→ produces `Installations\<ts>_Full.zip`. Unzip to `C:\RTMView-Staging` (overwrite).

## "проверяем" — stand up services + verify
1. Stop hand-run dev + free ports (Soma `POST /shell/stop`; kill any foreground `GarnetServer`; confirm 5238/5239/6379 free).
2. Install ALL as prod services (ADMIN PowerShell):
```
powershell -ExecutionPolicy Bypass -File C:\RTMView-Staging\Install-RTMView.ps1 -Mode Full -GarnetNoAuth -SkipDB -ShellPort 5238 -RTMPort 8088 -DBAppPassword "!@#qweASDzxc"
```
`-SkipDB` preserves the reconciled rtmviewdb. `-GarnetNoAuth` = local bare Garnet.
3. Acceptance — paste back:
```
Get-Service Garnet, RTMViewShell, RTMService    # all Running / Automatic
```
→ coordinator re-verifies `/health` + `/health/ready` = 200 SUSTAINED (live via Chrome) → unblocks QA.

## Notes
- Same `Installations\<ts>_Full.zip` deploys to **234** via `Update-RTMView.ps1` (Memurai→Garnet migration). Local == 234.
- 234 prereqs: dba Compare-ToBaseline on 234 → migration delta (operator `out\`); DB-INTAKE-01 reconcile wired; Garnet stable as a service (flap root closed).
- If Garnet still flaps as a SERVICE → devops STEP6 root-cause (flap root is OPEN, not assumed).
