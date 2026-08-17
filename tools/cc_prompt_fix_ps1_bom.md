# CC task — FIX §35 regression: CC-2 saved PS1 files WITHOUT UTF-8 BOM → PS 5.1 parse failure

> **Defect (RED, ЧП):** commits `0966263` + `88f4888` saved `db/tools/Provision-FreshDb.ps1`,
> `deploy/Install-RTMView.ps1`, `tools/Build-ProdRelease.ps1` **without the UTF-8 BOM**. On the target
> box (Windows PowerShell **5.1**, no BOM → Windows-1252 codepage) the 47 non-ASCII chars (em-dashes) are
> mis-decoded and the scripts **fail to parse** (`Build-ProdRelease.ps1` errored on run). Reference good
> PS1 (`Restore-All.ps1`, `Update-RTMView.ps1`) start with `EF BB BF`. §35: **all PS1 = UTF-8 BOM + CRLF**.
>
> Branch: **v3 ONLY**. Commit `fix:`. **NO push** (§37). Territory: devops.

## Mandatory — read before starting (§40)
Read file: .claude/skills/role-devops/role-devops.md (§A CORE + §C VERIFY)
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md

## INIT — §0.6a integrity + branch v3
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git status --short
```

## §0.6b BINDING PREAMBLE — .coord/cc/devops.md (Python+fsync)
```
## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_fix_ps1_bom.md | status: open
### DIRECTIVE (spec->CC): re-save the 3 PS1 (Provision-FreshDb, Install-RTMView, Build-ProdRelease) as UTF-8 BOM + CRLF; VERIFY each parses in Windows PowerShell 5.1 (NOT pwsh7); scan repo for other NO-BOM PS1. v3, fix:, NO push. Report PS5.1 parse err-count per file.
```

## THE WORK
1. For each of `tools/Build-ProdRelease.ps1`, `deploy/Install-RTMView.ps1`, `db/tools/Provision-FreshDb.ps1`:
   read the current bytes, and re-write with **UTF-8 BOM (EF BB BF) + CRLF** line endings, content otherwise
   byte-identical (do NOT change any code — encoding only). Use an atomic write (§0.3 Python or PowerShell
   `[System.IO.File]::WriteAllText(path, $text, (New-Object System.Text.UTF8Encoding($true)))` after
   normalising newlines to CRLF). Preserve all non-ASCII chars (em-dashes) as real UTF-8 bytes.
2. **Sweep** the whole repo for other PS1 missing the BOM: `Get-ChildItem -Recurse -Filter *.ps1` -> check first 3 bytes. There ARE ~15 others besides these three (docs/, scripts/, RTM/deployment/, db/tools/*, staging/, devops/tools/). Do NOT auto-fix them here: many are cross-territory or pure-ASCII (PS 5.1 parses ASCII fine without BOM). **THIS fix's scope = the 3 named devops-territory files ONLY.** REPORT the full NO-BOM list (path + whether it has non-ASCII) so the coordinator can route a separate §35 cleanup per owner.

## VERIFY / DoD — PARSE IN WINDOWS POWERSHELL 5.1 (this is the gate CC-2 missed)
For EACH of the three files, run under **Windows PowerShell 5.1** (`powershell.exe`, NOT `pwsh`):
```powershell
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile("<abs-path>", [ref]$null, [ref]$errs)
"<file>: parse errors = $($errs.Count)"
```
Report the error count per file — **all must be 0**. Also confirm first-3-bytes = `EF BB BF` per file
(`Format-Hex <file> | Select -First 1`). Do NOT rely on pwsh7 (it defaults to UTF-8 and hides the defect).
Optional: `.\tools\Build-ProdRelease.ps1 -Mode Full -SkipDB` should now start without a ParserError
(it may proceed to build — that's the coordinator's batched-rebuild step, not required here; just confirm no parse error).

## COMMIT (commit.lock + journal + NO push)
- `bash tools/pre-commit-check.sh` → 0. commit.lock. Stage the re-saved PS1 files only.
- Commit `fix(deploy): restore UTF-8 BOM on PS1 (Provision-FreshDb/Install-RTMView/Build-ProdRelease) — §35, PS 5.1 parse [devops]`.
- §0.6 verify. **NO push.** §0.7 re-sync.

## §0.6b BINDING POSTAMBLE + CAPTURE
- RESULT to .coord/cc/devops.md: commit hash, per-file PS5.1 parse err-count (0), BOM-confirmed list.
- CAPTURE → role-devops §B: "PS1 saved without UTF-8 BOM parses in pwsh7 (UTF-8 default) but FAILS in Windows PowerShell 5.1 (codepage decodes UTF-8 multibyte as Win-1252 → broken string literals). §35 PS1-parse DoD MUST be verified with powershell.exe (5.1) + first-bytes EF BB BF, never pwsh7 alone. SOURCE: CC-2 0966263/88f4888 stripped BOM → Build-ProdRelease ParserError on box, 2026-07-13."
