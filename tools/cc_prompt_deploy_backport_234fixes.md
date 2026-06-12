# CC Task — Backport the 234 deploy firefight fixes into the repo (deploy script + packaging + db)

> During the 234 iter-1 deploy, 9 defects were fixed MANUALLY on the package copy / on 234. They are NOT in the repo.
> Backport ALL of them so a freshly-built package deploys cleanly (next target: server 45, PG17, in-place upgrade).
> ApplyService UseWindowsService is already committed (7ba6250) — do NOT redo it. NO push (§37). Commit prefix: deploy: / db:.
> WRITES: Python read->replace->write+os.fsync (CLAUDE.md §0.3, Edit BANNED). Verify each with grep/tail. Keep UTF-8 BOM + CRLF.

## 0. Integrity
cd "D:\Claude\Projects\RTM View Shell"; git status --short  # restore truncated M vs HEAD before editing.

## FILE A — deploy/Apply-Server45Upgrade.ps1  (7 fixes)

### A1 — StrictMode .Count on single-migration (Phase 4, ~L414)
KEEP Set-StrictMode. Wrap the split result in @() so .Count works for a 1-item list:
  FROM: $migrations = $MigrationList.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  TO:   $migrations = @($MigrationList.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
Apply the same @() wrap to the built-in default-list branch (~L424) if it also pipes into $migrations.

### A2 — $ReleaseCommit undefined (manifest L891 + INSTALL.txt arg)
Add to param(): [string]$ReleaseCommit = ""
Use it in the manifest line (L891) as-is. This makes INSTALL.txt's -ReleaseCommit "<hash>" valid AND stamps SERVER.md.

### A3 — JSON add-property by direct assignment (PS5) at L570, L626, L769
Replace each `$x.A.B.C = <val>` with Add-Member -Force (adds-or-overwrites; PS5 cannot add a prop by assignment):
  L570: $applyJson.Kestrel.Endpoints.Http | Add-Member -NotePropertyName "Url" -NotePropertyValue "http://127.0.0.1:$ApplyServicePort" -Force
  L626: $shellJson.MetricsApply        | Add-Member -NotePropertyName "BaseUrl" -NotePropertyValue "http://127.0.0.1:$ApplyServicePort" -Force
  L769: $rtmJson.Kestrel.Endpoints.Http | Add-Member -NotePropertyName "Url" -NotePropertyValue $loopbackUrl -Force

### A4 — icacls bare service name -> NT SERVICE\ (5 occurrences of "${ApplySvcName}:)
Global replace in the file:  "${ApplySvcName}:   ->   "NT SERVICE\${ApplySvcName}:
(virtual service account only resolves with the NT SERVICE\ prefix; bare name = 'No mapping between account names and SIDs').

### A5 — orphan-exe kill by PATH + verify + no respawn (Stop-ServiceAndExe ~L150 + Phase 1)
Root cause: kill-by-exe-NAME (from service PathName) missed RTMViewShell's Kestrel child; it falsely logged 'exe clear';
AND service recovery respawned killed orphans.
 - Stop-ServiceAndExe: accept a $componentDir param. After Stop-Service, sweep+kill via CIM (sees LocalSystem procs):
     Get-CimInstance Win32_Process | ? { $_.ExecutablePath -like ($componentDir.TrimEnd('\')+'\*') } | % { Stop-Process -Id $_.ProcessId -Force }
   then VERIFY none remain; if any survive -> throw (do NOT log 'exe clear' falsely).
 - Phase 1: before killing, neutralise recovery so the kill can't trigger a restart — for RTMService & RTMViewShell:
     Set-Service <svc> -StartupType Manual ; sc.exe failure <svc> reset= 0 actions= ""
   and in Phase 6/7 restore: Set-Service <svc> -StartupType Automatic. Pass $shellDir/$rtmDir/ApplyService dir into the kills.

### A6 — RTM appsettings clobbered (TenantId zeroed on 234) — Phase 3 RTM copy not preserving (the $preservedRTM ~L366 logic failed)
RTM/RTM/appsettings.json was overwritten by the package's (TenantId -> 00000000..., AdaptorServiceName -> 'RTMView.Nayax').
 - Mirror the Shell preserve: BEFORE copying bin/RTM/*, save the server's RTM appsettings.json; AFTER copy, restore it
   (preserve at least: RTM:TenantId, RTM:AdaptorServiceName, ConnectionStrings, RTM section machine/tenant values).
   Investigate why $preservedRTM (~L366) didn't cover appsettings.json — fix it to actually preserve+restore RTM appsettings.
 - POST-deploy ASSERT: read RTM:TenantId from the deployed appsettings; if it is Guid.Empty -> throw (fail the deploy).
 - The PACKAGED RTM appsettings must NOT carry a real customer value: change default AdaptorServiceName 'RTMView.Nayax'
   to a neutral placeholder (e.g. "REPLACE_AT_DEPLOY"); keep TenantId default 00000000 only as a never-used sentinel.

### A7 — F-3 RTM B1 block (L769) is inside the @() fix already (A3). Confirm B1 still asserts loopback after the Add-Member fix.

## FILE B — catowner provisioning (db/setup/02_catowner_role.sql + the wiring in Apply-Server45Upgrade.ps1)
Bug: repeated runs regenerate the env catowner password each run, but the ROLE password is only set on CREATE
(IF NOT EXISTS) -> role pw != env pw -> ApplyService DB auth fails. FIX: generate the catowner password ONCE per run and
 - ALTER ROLE ccdashboard_catowner WITH PASSWORD '<that value>'  (idempotent — set every run, not just on create), AND
 - write the SAME value into the ApplyService service env (ConnectionStrings__CatalogueOwner) in the SAME run.
Ensure the SQL does CREATE ROLE IF NOT EXISTS then unconditional ALTER ROLE ... PASSWORD.

## FILE C — packaging: ship docs/metrics-catalog.json to the Shell
The Shell MetricsPage reads docs/metrics-catalog.json relative to its content root; the package didn't ship it ->
'Metrics catalog not found. Using database metrics as fallback.' Include docs/metrics-catalog.json in the Shell publish/
package at a path the Shell resolves (e.g. copy into <ShellPublish>\docs\metrics-catalog.json), in the build/package script
(tools/Build-ProdRelease.ps1 or the package assembly step). Verify the Shell finds it (no fallback).

## D — e2e deploy smoke (build self-test) — so these can't ship broken again
Add to the build/package self-test (or a doc'd post-build check): on a throwaway box, after install/upgrade ASSERT:
 (1) 1-item -MigrationList runs (catches StrictMode), (2) the installed Windows service STARTS and stays Running
 (catches UseWindowsService + catowner), (3) metrics catalog resolves (no fallback), (4) RTM:TenantId preserved != Empty,
 (5) icacls grant to NT SERVICE\<svc> succeeds. NOT-RUN must be reported, never silent-pass.

## Commit (NO push, §37)
bash tools/pre-commit-check.sh
Stage explicitly: deploy/Apply-Server45Upgrade.ps1 ; db/setup/02_catowner_role.sql ; the build/package script ; (any test/smoke file).
Commit deploy: "deploy: backport 234 firefight fixes (StrictMode @, ReleaseCommit param, JSON Add-Member, icacls NT SERVICE, orphan-kill-by-path+no-respawn, RTM appsettings preserve+assert, catowner idempotent, catalog packaging, e2e smoke)"
(separate db: commit for 02_catowner_role.sql if cleaner). Post-commit verify clean. Do NOT push.

## Report
Per-fix A1..A7 + B + C + D: file+location changed, before/after snippet, grep proof. Commit hash(es). Confirm StrictMode KEPT.
