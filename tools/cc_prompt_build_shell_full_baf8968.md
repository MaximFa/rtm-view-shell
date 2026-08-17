# CC task — BUILD prod-release -Mode Full from v3 tip baf8968 (search/filters + tune) — BUILD-0 + UNIT gate
> v3 HEAD baf8968. Batch since 73ed34b: db5af40 (edit-3 tune: table offset ?v=32 + funnel top-align) + baf8968 (admin search + per-field filters BU/SG/Sites/InfoSlots). Code/CSS. Owner: devops. Native CC. Branch v3. NO push (§37).

## Mandatory reads
Read: .claude/skills/role-devops/role-devops.md (§A+§C); .claude/skills/session-coord/session-coord.md; CLAUDE.md §24, §35, §MAINT-05.

## INIT  [ON DEV]
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # v3
git rev-parse v3                    # MUST be baf8968b0da4533ac634171c9c5fe5395d75f72e
git status --short; sync
```
## §0.6b BINDING preamble -> .coord/cc/devops.md: status open, directive tools/cc_prompt_build_shell_full_baf8968.md.

## THE WORK  [ON DEV]
```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -SkipDB
dotnet test tests\CcDashboard.Tests.Unit --nologo
```

## DoD — REPORT NUMBERS
- Build = **0 errors** (report W). Unit = **Failed 0** WITH counts (expect 263/263).
- newest Installations\*.zip -> full path + size + SHA256.
- Confirm **app.css?v=32** compiled in App.razor @baf8968 (object-store-confirmed) -> browsers pull fresh CSS. (Optional: `git show baf8968:src/CcDashboard.Web/Components/App.razor | grep 'app.css?v='`.)
- Catalog unchanged (GAP-1 present). PS1 UTF-8 BOM+CRLF (§35).

## NO commit/push. §0.6b postamble -> RESULT (build 0/W + unit Failed0/counts + pkg path/size/SHA + app.css?v=32 . from baf8968 . status).
