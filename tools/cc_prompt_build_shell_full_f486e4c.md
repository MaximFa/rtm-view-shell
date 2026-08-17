# CC task — BUILD prod-release -Mode Full from v3 tip f486e4c (Defect G+H fix) — BUILD-0 + UNIT evidence gate
> v3 HEAD f486e4c = a261840 (G: parametrize platform slug + idempotency by Name==Platform) + f486e4c (H: per-tenant username unique index, migration 20260713041952_PerTenantUserNameIndex). This build confirms build-0 + unit failed=0 WITH COUNTS for BOTH (backend couldn't run dotnet from Cowork). Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §35, §MAINT-05, §DEPLOY-16.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be f486e4c51b57189221f78ebaa82a2326d5e7c6fa
git status --short; sync
```
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_shell_full_f486e4c.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -SkipDB
dotnet test tests\CcDashboard.Tests.Unit --nologo
```

## DoD — REPORT NUMBERS (evidence gate for G a261840 + H f486e4c)
- Build = **0 errors** (report W). If fails -> verbatim + flag, do NOT package.
- Unit = **Failed 0** WITH counts (Passed/Total). This is the §A evidence gate for G+H.
- newest Installations\*.zip -> full path + size + SHA256; db/ tree in zip (schema.sql + setup + functions + data + tools incl Compare-ToBaseline.ps1); Update-RTMView.ps1 present.
- Confirm migration **20260713041952_PerTenantUserNameIndex** compiled into CcDashboard.Infrastructure (build success implies; optional `dotnet ef migrations list` shows it as latest App migration).
- PS1 UTF-8 BOM+CRLF (§35).

## NO commit/push. §0.6b postamble -> RESULT (build 0/W + unit Failed0/counts + pkg path/size/SHA + PerTenantUserNameIndex present . from f486e4c . status).
