# CC task — BUILD prod-release (Shell only) from v3 tip adbf5d7 — for 234 deploy (rejects fix pack)

> Deploy barrier batch (WIDGET-STICK x2 + ASD-B; b81ccb5 is dev-tooling, NOT built). Runtime artifact = Shell (web) only.
> No DB migration, no RTM Service change in this batch. Owner: devops. Executor: native CC. Branch v3. **NO push** (§37). Report-scoped.

## Mandatory — read before starting
Read: .claude/skills/role-devops/role-devops.md (§A CORE + §C VERIFY)
Read: .claude/skills/session-coord/session-coord.md
Read: CLAUDE.md §24 (DEPLOY), §35 (prod-release: BOM+CRLF, no Read-Host, -Password direct), §DEPLOY-16 (Update over Install)

## INIT — §0.6a integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD        # MUST be v3
git rev-parse v3                        # MUST be adbf5d7...
git status --short
sync
```
Confirm HEAD == v3 tip adbf5d7 before building. If not — STOP, report.

## §0.6b BINDING preamble → .coord/cc/devops.md (Python+fsync)
```
## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_build_shell_v3.md | status: open
### DIRECTIVE (spec->CC): build prod-release Shell-only pkg from v3 adbf5d7 for 234 deploy. Report build=0 WITH counts + zip path + SHA. NO push.
```

## THE WORK — build Shell package
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Shell
```
- This publishes CcDashboard.Web (self-contained win-x64 → publish\web) and packages the zip under Installations\ with Install-RTMView.ps1 + Update-RTMView.ps1.
- Deploy on 234 will use **Update-RTMView** (§DEPLOY-16 — preserves appsettings/cert/config; Install-Full re-templates placeholders and crashes Shell). The package must include Update-RTMView.ps1.

## VERIFY / DoD — REPORT NUMBERS
- `dotnet build` inside publish = **0 errors** (report warning count). If publish fails → report verbatim, do NOT package.
- Confirm the zip exists: `Get-ChildItem Installations\*_Shell.zip | Sort LastWriteTime | Select -Last 1` → report full path + size + SHA256.
- Confirm the zip contains Update-RTMView.ps1 (Shell-preserving deploy) + the web publish payload.
- Report the published widget-resize.js carries `?v=2` wiring (App.razor) and the ScreenEditorPage/asd changes are in the build (spot: build is from adbf5d7 commit).
- All PS1/TXT in zip UTF-8 BOM+CRLF (§35).

## NO commit needed (build artifact only; Installations/ is not committed). NO push.

## §0.6b BINDING postamble → .coord/cc/devops.md
```
### RESULT (CC->spec): build 0 err/W n . pkg Installations\<name>_Shell.zip (size, SHA256) . contains Update-RTMView.ps1 . from adbf5d7 . status done|failed . blockers . verified: object-store (deploy+LIVE = operator/coordinator on 234)
```
