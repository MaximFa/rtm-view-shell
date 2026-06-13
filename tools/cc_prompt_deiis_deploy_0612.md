# CC TASK — Remove ALL IIS machinery from deploy scripts (Kestrel-only) + repackage 45 (devops-2-0607)

> Operator: "all on Kestrel, remove every IIS mention." The IIS app-pool code in Apply-Server45Upgrade.ps1 is
> pure vestigial no-op — services are already handled by the Kestrel service model (Stop-ServiceAndExe +
> Start-Service for RTMViewShell / RTMService / RTMApplyService; Invoke-Rollback Stop/Start-Service). Removing
> the IIS blocks loses NOTHING. This SUPERSEDES the Test-IISAvailable guard (87dc034) — delete it, don't guard.
> Fix repo, commit fix: (NO push), repackage 45 from the new HEAD.
> [coordinator-0612 §4 PASS 2026-06-12: amendments applied — STEP4 $AppPools==0 check (anti-StrictMode), report to inbox/coordinator.md, param-boundary manual check if no pwsh. 87dc034 pkg is a working fallback if deploying now.]

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md ; .claude/skills/widget-creator/widget-creator.md ; .claude/skills/session-coord/session-coord.md

## §0.6a Step 0
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
git log --oneline -2   # expect HEAD=87dc034 (verify object store, not mount)
sync
```

## Sync (tools/cc_prompt_sync_block.md) — slug devops-2-0607
Claims: `deploy/Apply-Server45Upgrade.ps1, deploy/Update-RTMView.ps1`
- S1 barrier (FREEZE ACTIVE -> STOP). S2 coord_check_claims devops-2-0607 deploy/Apply-Server45Upgrade.ps1 deploy/Update-RTMView.ps1 (deploy module = yours; expect PASS). S3 commit.lock; S4 cc_post_commit.sh; S5 NO push.
ALL writes Python+os.fsync (§0.3). Edit tool BANNED. After write: sync + tail -3 + wc -l.

---

## STEP 1 — RESTORE Apply-Server45Upgrade.ps1 from HEAD first (PD-007 mount-drift)
```bash
git show HEAD:deploy/Apply-Server45Upgrade.ps1 > deploy/Apply-Server45Upgrade.ps1
sync; tail -3 deploy/Apply-Server45Upgrade.ps1; wc -l deploy/Apply-Server45Upgrade.ps1
```

## STEP 2 — remove ALL IIS machinery from Apply-Server45Upgrade.ps1 (via Python+fsync; preserve everything else)
Remove exactly these (the only IIS surfaces — verify by grep after):
1. The param `[string[]]$AppPools = @("CcDashboard.Web", "CcDashboard.Api"),` (delete the whole param line; fix trailing comma of the previous param if needed so the param block still parses).
2. The `function Test-IISAvailable { ... }` definition (the helper, ~3 lines).
3. In `Invoke-Rollback`: the two `if (Test-IISAvailable) { foreach ($pool in $AppPools) { Stop-WebAppPool ... } }` / `... Start-WebAppPool ... }` lines — delete them entirely (Stop-Service/Start-Service lines in Invoke-Rollback stay).
4. Phase 1: the whole "Stop IIS App Pools" block (`if (Test-IISAvailable) { Import-Module WebAdministration ... Stop-WebAppPool ... } else { Log "IIS not available..." }`). Delete entirely. The Stop-ServiceAndExe calls for RTM/Shell/Apply stay.
5. Phase 6: the whole "Start IIS App Pools" block (`if (Test-IISAvailable) { ... Start-WebAppPool ... } else { Log "IIS not available..." }`). Delete entirely. Start-Service calls stay.
6. Remove `"web.config"` from the `$shellPreserve` array (line ~374) — it is an IIS artifact (no web.config on Kestrel). Keep appsettings*.json + nlog.config.
DO NOT touch: Stop-ServiceAndExe, Start-Service, the service names ($ShellSvcName/$RTMSvcName/$ApplySvcName), DB/migration/function/F-3/ApplyService-provision logic.

## STEP 3 — Update-RTMView.ps1: remove web.config from its preserve list (~line 104) — `@("appsettings.Production.json", "nlog.config")` (drop "web.config").

## STEP 4 — verify (ZERO IIS surface remains)
```bash
echo "IIS surface (must be 0): $(grep -ciE 'IIS|WebAppPool|AppPool|WebAdministration|Test-IISAvailable|web\.config' deploy/Apply-Server45Upgrade.ps1)"
echo "$AppPools orphan refs (must be 0 — StrictMode runtime bug class, parse-OK will NOT catch): $(grep -c '\$AppPools' deploy/Apply-Server45Upgrade.ps1)"
echo "Update-RTMView web.config (must be 0): $(grep -ci 'web\.config' deploy/Update-RTMView.ps1)"
# service model still intact:
grep -cE 'Stop-ServiceAndExe|Start-Service' deploy/Apply-Server45Upgrade.ps1   # must be > 0
pwsh -NoProfile -Command "try{[scriptblock]::Create((Get-Content -Raw deploy/Apply-Server45Upgrade.ps1));'PARSE-OK'}catch{'PARSE-FAIL: '+\$_.Exception.Message}" 2>/dev/null || echo "pwsh unavailable - rely on tail/wc"
# If pwsh unavailable: manually confirm the param line BEFORE the deleted $AppPools ends with a correct trailing comma / the param block closes with `)` — tail/wc will NOT catch a broken param block.
tail -3 deploy/Apply-Server45Upgrade.ps1; wc -l deploy/Apply-Server45Upgrade.ps1
```
Both IIS counts MUST be 0; service-model count > 0; parse OK.

## STEP 5 — COMMIT (single fix:, NO push) under commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1 deploy/Update-RTMView.ps1
git add deploy/Apply-Server45Upgrade.ps1 deploy/Update-RTMView.ps1
git commit -m "fix: remove all IIS app-pool machinery from deploy scripts — Kestrel-only (supersedes Test-IISAvailable guard)"
```
Then §0.6 post-commit verify + cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h) + PD-007 re-sync. NO push.

## STEP 6 — REPACKAGE 45 from the new HEAD (same process as Installations/45_87dc034_20260612-1236.zip; see tools/cc_prompt_build_45.md). New -ReleaseCommit = new HEAD. Output Installations/. Report exact path + verify in-package Apply-Server45Upgrade.ps1 has 0 IIS surface.

## STEP 7 — REPORT to coordinator-0612 (Python+fsync append .coord/inbox/coordinator.md): commit hash; IIS-surface=0 (both files); service-model intact; parse-OK; new package path + in-package IIS=0; unpushed count; NO push.
