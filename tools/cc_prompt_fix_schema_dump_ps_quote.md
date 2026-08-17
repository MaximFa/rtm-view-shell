# CC TASK — FIX PS5.1 quote-strip in RTM schema dump (Export-All + Compare, symmetric)  [⛔v3 · DBA · tooling]

> Authored by dba-0625 for coordinator §4-bless. NOT urgent (EDIT-500 closed, 234 live; degenerate baseline NOT committed). Fixes the root that made the regen schema.sql degenerate AND caused the recurring E1 "438 missing".
> ROOT: both db/tools/Export-All.ps1 (schema-phase, L82) and db/tools/Compare-ToBaseline.ps1 (Dim-A server dump, L196/L209) pass `-t 'public."NGC_Site"'` to pg_dump.exe. Under Windows PowerShell 5.1 the embedded `"` are STRIPPED → pg_dump gets `-t public.NGC_Site` → folds lowercase → matches NONE of the 24 PascalCase RTM tables (only lowercase bookkeeping tables survive). Symptom: baseline=2 tables (degenerate) AND server-dump=0 RTM → A=0 by empty-set match (or 438 'missing' when baseline still had 26). pwsh7 is NOT on 234 → must be version-INDEPENDENT. PICK=(c): full `pg_dump --schema-only` + PS post-filter to the whitelist, applied SYMMETRICALLY to BOTH sides + a SINGLE-SOURCE whitelist (kills the existing duplicate-list drift).

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE + §C VERIFY.
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §35 (PS1 UTF-8 BOM+CRLF, PS5.1-safe), §39 (db module), §38.5.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # v3 object-store; M hash-verify vs HEAD
sync
```
S1: if `.coord/push/request.md` active → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_fix_schema_dump_ps_quote.md | status: open
### DIRECTIVE (spec->CC): single-source RTM-schema filter helper + wire into Export-All schema-phase & Compare Dim-A (full dump + filter, no -t). claim: db/tools/. gate: PS5.1 parse + operator re-regen 24 tables. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/RtmSchemaDump.ps1` (NEW helper), `db/tools/Export-All.ps1` (edit schema-phase), `db/tools/Compare-ToBaseline.ps1` (edit Dim-A server dump), `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX (all .ps1 UTF-8 BOM+CRLF, PS5.1-safe: no ternary/??, 2-arg Join-Path, @() wraps on .Count)

### 4.1 NEW `db/tools/RtmSchemaDump.ps1` — SINGLE SOURCE of the RTM whitelist + version-independent dump
```powershell
# Single source of the RTM-canonical table whitelist (was duplicated in Export-All + Compare).
$script:RtmTableNames = @(
  'public."NGC_AgentGroups"','public."NGC_BusinessUnit"','public."NGC_BusinessUnitQueueClassification"',
  'public."NGC_BusinessUnitSupergroup"','public."NGC_Queues"','public."NGC_Site"','public."NGC_Supergroup"',
  'public."NGC_SupergroupAgentgroup"','public."NGC_UserAgentgroup"','public."RTSData_ChatMessage"',
  'public."RTSData_Interaction"','public."RTSData_UserStatus"','public."RTSData_UserStatusLog"',
  'public."RTSGrid_Cell"','public."RTSGrid_Column"','public."RTSGrid_Grid"','public."RTSGrid_Metric"',
  'public."RTSGrid_MetricTranslation"','public."RTSGrid_Row"','public."RTSGrid_Statistic"','public."RTSGrid_UserStatus"',
  'public."RTSUserGrid_Column"','public."RTSUserGrid_ColumnsSet"','public."RTSUserGrid_Grid"'
)
# COPY the EXACT unique names from the current Export-All $rtmTables (L82-onward) so scope is identical;
# if that list has 26 -t entries with 2 dupes, keep the UNIQUE set here (verify against object-store).

function Export-RtmSchema {
    param([string]$PgDump,[string]$DBHost,[string]$DBPort,[string]$DBUser,[string]$Database,[string]$OutFile)
    # FULL public schema-only dump (NO -t -> no PS quote-strip), then filter to the whitelist.
    $tmp = [System.IO.Path]::GetTempFileName() + ".sql"
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { & $PgDump -h $DBHost -p $DBPort -U $DBUser -d $Database --schema-only --no-owner --no-acl -n public -f $tmp 2>&1 | Out-Null; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prev }
    if ($code -ne 0) { throw "pg_dump full schema failed (exit $code)" }
    $raw = Get-Content -LiteralPath $tmp -Raw -Encoding UTF8
    Remove-Item $tmp -ErrorAction SilentlyContinue
    # pg_dump separates each object with a blank line + a "-- Name: ...; Type: ...;" header.
    # Split on the blank-line boundary; KEEP a block iff it contains a full-quoted whitelist name
    # (full-quoted -> "NGC_BusinessUnit" does NOT substring-match "NGC_BusinessUnitSupergroup").
    $blocks = $raw -split "(?ms)\r?\n\r?\n"
    $keep = New-Object System.Collections.Generic.List[string]
    foreach ($b in $blocks) {
        foreach ($name in $script:RtmTableNames) {
            $q = ($name -replace '^public\.', '')   # the "NGC_Site" quoted part
            if ($b.Contains($q)) { [void]$keep.Add($b.TrimEnd()); break }
        }
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM for the SQL baseline file
    [System.IO.File]::WriteAllText($OutFile, ($keep -join "`r`n`r`n") + "`r`n", $utf8)
    Write-Host ("Export-RtmSchema: {0} object-blocks kept for {1} whitelist tables" -f @($keep).Count, @($script:RtmTableNames).Count)
}
```
NOTE to CC: VERIFY $script:RtmTableNames = the EXACT unique set from Export-All's current $rtmTables (object-store) — do not add/drop tables; single-source it.

### 4.2 `db/tools/Export-All.ps1` schema-phase (L80-~110) — use the helper
Replace the `$rtmTables = @('-t', ...)` + `& $pgdump ... @rtmTables ... -f $schemaFile` with:
```powershell
. (Join-Path $PSScriptRoot 'RtmSchemaDump.ps1')
Export-RtmSchema -PgDump $pgdump -DBHost $DBHost -DBPort $DBPort -DBUser $DBUser -Database $Database -OutFile $schemaFile
```
(Delete the local $rtmTables -t array here — now single-sourced in the helper.)

### 4.3 `db/tools/Compare-ToBaseline.ps1` Dim-A server dump (L194-209) — use the SAME helper (symmetry)
Replace the `$rtmTables = @('-t', ...)` + `& $pgdump ... @rtmTables -f $ServerSchemaFile` with:
```powershell
. (Join-Path $PSScriptRoot 'RtmSchemaDump.ps1')
Export-RtmSchema -PgDump $pgdump -DBHost $DBHost -DBPort $DBPort -DBUser $User -Database $Database -OutFile $ServerSchemaFile
```
(Note Compare's user param is `$User`; Export-All's is `$DBUser` — pass each script's own var. Delete Compare's local $rtmTables.)
=> Both sides now dump via the SAME full-dump+filter+whitelist → symmetric scope → A=0 is FAITHFUL (both contain the 24), not empty-match.

### 4.4 Do NOT touch
The [A-R] routine-presence / functions phase (deferred, separate prompt), Compare gate logic (L775), data phase, migrations.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`) — 2 lessons
```
- 2026-07-04 · Windows PowerShell 5.1 STRIPS embedded double-quotes when passing `-t 'public."NGC_Site"'` to pg_dump.exe -> pg_dump folds to lowercase -> matches NO PascalCase RTM tables (only lowercase survive) -> degenerate schema.sql / false '438 missing'. pwsh7 preserves quotes but is not everywhere. FIX version-independent: full `pg_dump --schema-only -n public` + PS post-filter to the quoted whitelist (Export-RtmSchema helper), NEVER rely on -t quoting under PS5.1. · SOURCE: Export-All/Compare schema dump 2026-07-04 · status: active
- 2026-07-04 · Export-All (baseline gen) and Compare (server dump) MUST use the IDENTICAL RTM whitelist + dump mechanism or they desync (baseline-has-26 vs server-has-0 -> phantom drift). Single-source the whitelist (RtmSchemaDump.ps1) so both sides are provably symmetric. · SOURCE: 234 E1 438-missing 2026-07-04 · status: active
```

## 6. Acceptance
- db/tools/RtmSchemaDump.ps1 created (single-source whitelist = exact unique set from old Export-All $rtmTables; Export-RtmSchema helper full-dump+filter, UTF-8-no-BOM output for schema.sql).
- Export-All + Compare both call Export-RtmSchema; their local $rtmTables -t arrays removed.
- All 3 .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse (Parser::ParseFile) = PARSE-OK for each.
- role-dba §B has the 2 lessons.
- NO 234 apply; NO push. NO degenerate schema.sql committed (this run only fixes the tools).
- DoD (operator, AFTER commit): re-run Export-All on 234 -> schema.sql has the 24 RTM `CREATE TABLE "NGC_*/RTSData_*/RTSGrid_*/RTSUserGrid_*"` (not 2); re-Compare against it -> GATE CLEAN + A=0 FAITHFUL (grep schema.sql for CREATE TABLE count ~24, size ~29KB). Report counts to prove symmetry.

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5x60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/RtmSchemaDump.ps1 db/tools/Export-All.ps1 db/tools/Compare-ToBaseline.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT add schema.sql/data.
- Prefix `fix:` — `fix(db): version-independent RTM schema dump (full+filter) in Export-All & Compare - kills PS5.1 -t quote-strip + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . RtmSchemaDump.ps1 + Export-All + Compare-ToBaseline + role-dba.md . parse PS5.1 OK . status done . verified: object-store
```
