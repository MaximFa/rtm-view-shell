# CC task — BUILD prod-release -Mode Full from v3 tip 0f270bd (Defect K + grid headers) — BUILD-0 + UNIT gate
> v3 HEAD 0f270bd. Batch since f486e4c: 0364a71 (metric QueueNumberOfCompletedIncomingCalls) + d30e9b4 (Defect K: NGC config flush beDb) + 0f270bd (grid headers As-Is/wrap/top). Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §35, §MAINT-05.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be 0f270bd7fce84f6d771eefd60c15117fdd664d09
git status --short; sync
```
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_shell_full_0f270bd.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -SkipDB
dotnet test tests\CcDashboard.Tests.Unit --nologo
```

## DoD — REPORT NUMBERS
- Build = **0 errors** (report W). Unit = **Failed 0** WITH counts (coordinator expects 263/263).
- newest Installations\*.zip -> full path + size + SHA256.
- **CONFIRM the PACKAGED catalog contains the metric** (GAP-1 for 140 Deploy-New-Metrics tab, routing 3c). The Shell serves the catalog from `<AppBase>\docs\metrics-catalog.json` (MetricsPage.razor:337-345); Build packages it as `Shell\docs\metrics-catalog.json` (source = repo-root docs/metrics-catalog.json, updated by 0364a71). Verify in the built package:
  ```powershell
  $z=[IO.Compression.ZipFile]::OpenRead((gci Installations\*.zip|sort LastWriteTime|select -last 1).FullName)
  ($z.Entries|?{$_.FullName -like '*Shell/docs/metrics-catalog.json'}) | % { $r=New-Object IO.StreamReader($_.Open()); ($r.ReadToEnd() -match 'QueueNumberOfCompletedIncomingCalls') }
  $z.Dispose()
  ```
  -> MUST be True. If the served path differs from docs/metrics-catalog.json -> flag.
- PS1 UTF-8 BOM+CRLF (§35).

## NO commit/push. §0.6b postamble -> RESULT (build 0/W + unit Failed0/counts + pkg path/size/SHA + catalog-has-metric True . from 0f270bd . status).
