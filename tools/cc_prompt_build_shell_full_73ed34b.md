# CC task — BUILD prod-release -Mode Full from v3 tip 73ed34b (4 UI edits) — BUILD-0 + UNIT gate
> v3 HEAD 73ed34b. Batch since 0f270bd: ebbc229 (grid header text-transform:none + no mid-word break) + 0b96607 (charts no-anim on live refresh, DayTrend+ASD, ?v=3) + 73ed34b (tables internal-scroll sticky header, app.css?v=31). All code/CSS/JS. Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §35, §MAINT-05.

## INIT
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be 73ed34b4bf65c847e994cf090d9146e64a6aaa68
git status --short; sync
```
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_shell_full_73ed34b.md.

## THE WORK
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -SkipDB
dotnet test tests\CcDashboard.Tests.Unit --nologo
```

## DoD — REPORT NUMBERS
- Build = **0 errors** (report W). Unit = **Failed 0** WITH counts (coordinator expects 263/263).
- newest Installations\*.zip -> full path + size + SHA256.
- **Confirm the ?v bumps** are compiled in (App.razor @73ed34b object-store-confirmed: `app.css?v=31`, `daytrendChart.js?v=3`, `agentStateDistributionChart.js?v=3`). Build compiles App.razor, so a 73ed34b build ships them -> browsers pull fresh CSS/JS. (Optional: `git show 73ed34b:src/CcDashboard.Web/Components/App.razor | grep '?v='` to re-confirm.)
- Catalog unchanged from last (still has GAP-1 QueueNumberOfCompletedIncomingCalls).
- PS1 UTF-8 BOM+CRLF (§35).

## NO commit/push. §0.6b postamble -> RESULT (build 0/W + unit Failed0/counts + pkg path/size/SHA + ?v bumps confirmed . from 73ed34b . status).
