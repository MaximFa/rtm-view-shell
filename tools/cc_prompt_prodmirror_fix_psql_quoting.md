# CC TASK — FIX Seed-ProdMirror.ps1: psql `-c` double-quote stripping + SQL-file BOM  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. ROOT CAUSE proven on real staging (read-only):
> psql echoed `FROM "NGC_Site"` as `FROM NGC_Site` → `relation "ngc_site" does not exist`. PowerShell STRIPS embedded double-quotes when passing `-c "...\"Ident\"..."` to a native exe; PG PascalCase identifiers REQUIRE double-quotes → folded to lowercase → not found. (Confirmed harmless tables: NGC_*/RTSData_* exist PascalCase, all carry TenantId; permission_groups HINT proved the column exists.) Plus: `Set-Content -Encoding UTF8` (PS5.1) writes a BOM → `psql -f` errors `syntax error at or near "ï»¿"`.
> FIX = never pass quoted identifiers via `psql -c`; route ALL queries through `psql -f <tempfile>` written UTF-8 **NO-BOM**.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §35 (PS1 UTF-8 BOM+CRLF for the .ps1 itself; PS5.1-safe), §39.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M files hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_fix_psql_quoting.md | status: open
### DIRECTIVE (spec->CC): route psql queries through -f no-BOM temp files (kill -c quote-stripping + SQL BOM) in db/tools/Seed-ProdMirror.ps1. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1 + grep no `-c $`. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` (fix) · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX — db/tools/Seed-ProdMirror.ps1 (keep the .ps1 itself UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL)

### 4.1 Add helper `Write-SqlFile` (after Invoke-Native)
Writes SQL as UTF-8 **NO BOM** (psql -f chokes on a BOM):
```powershell
function Write-SqlFile {
    param([Parameter(Mandatory=$true)][string]$Sql, [Parameter(Mandatory=$true)][string]$Path)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Sql, $utf8NoBom)
}
```

### 4.2 Rewrite `Invoke-Psql` (L88-104) — use -f temp file, NOT -c
```powershell
function Invoke-Psql {
    param([string]$Database, [string]$Query, [switch]$TuplesOnly, [switch]$NoHeaders)
    $env:PGPASSWORD = $SuperPassword
    $tmpq = Join-Path $env:TEMP ("pm_q_" + ([guid]::NewGuid().ToString('N')) + ".sql")
    Write-SqlFile -Sql $Query -Path $tmpq
    $args = @("-U", $SuperUser, "-d", $Database, "-v", "ON_ERROR_STOP=1", "-f", $tmpq)
    if ($TuplesOnly) { $args += "-t" }
    if ($NoHeaders)  { $args += "--no-align" }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & $psql @args 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
        Remove-Item $tmpq -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) { throw ("psql failed ({0}): {1}" -f $code, ($result -join [Environment]::NewLine)) }
    return $result
}
```

### 4.3 `Invoke-PsqlFile` (L106-117) — EAP wrap (clean throw) ; callers must pass NO-BOM files
Wrap the `& $psql ... -f $FilePath 2>&1` in `$prev=$ErrorActionPreference; $ErrorActionPreference='Continue'; try{...;$code=$LASTEXITCODE}finally{$ErrorActionPreference=$prev}` and `throw` on `$code -ne 0`.

### 4.4 Phase-4 `\copy` export (L637) — route via -f (it has quoted identifiers → same -c bug)
Replace `$copyResult = & $psql -U $SuperUser -d $StagingDb -c $copyToQ 2>&1` with: write `$copyToQ` to a temp file via Write-SqlFile then run `-f`:
```powershell
$tmpCopy = Join-Path $env:TEMP ("pm_copy_" + ([guid]::NewGuid().ToString('N')) + ".sql")
Write-SqlFile -Sql $copyToQ -Path $tmpCopy
$prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try { $copyResult = & $psql -U $SuperUser -d $StagingDb -v ON_ERROR_STOP=1 -f $tmpCopy 2>&1; $copyCode = $LASTEXITCODE }
finally { $ErrorActionPreference = $prev; Remove-Item $tmpCopy -ErrorAction SilentlyContinue }
if ($copyCode -ne 0) { throw "Export failed for $tbl : $copyResult" }
```
(Keep the COPY-FROM load via the main loadSql file — §4.5.)

### 4.5 loadSql file (L658) — write NO-BOM (psql -f BOM bug)
Replace `$loadSql | Set-Content -Path $loadSqlPath -Encoding UTF8` with:
```powershell
Write-SqlFile -Sql ($loadSql -join [Environment]::NewLine) -Path $loadSqlPath
```
(The load is then run via Invoke-PsqlFile -f → now BOM-free.)

### 4.6 Leave as-is
Inspect/proof report writes (L462/L796 Set-Content UTF8) — human-read .txt, not fed to psql; BOM harmless. `& $tool --version` (L226 etc) — no SQL. Invoke-Native (Phase 1/2 native tools) — unchanged.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`) — TWO lines
```
- 2026-06-25 · PowerShell STRIPS embedded double-quotes when passing `psql -c "...\"Ident\"..."` to the native exe → PG PascalCase identifiers fold to lowercase → `relation "ident" does not exist` (proven: `FROM "NGC_Site"` echoed as `FROM NGC_Site`). FIX: never pass quoted identifiers via -c; write the query to a temp .sql and run `psql -f`. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 · status: active
- 2026-06-25 · PS5.1 `Set-Content -Encoding UTF8` writes a BOM; `psql -f` then errors `syntax error at or near "ï»¿"`. Write SQL files UTF-8 NO-BOM via [System.IO.File]::WriteAllText($p,$sql,(New-Object System.Text.UTF8Encoding($false))). · SOURCE: prodmirror_diag.sql 2026-06-25 · status: active
```

## 6. Acceptance
- `Write-SqlFile` present; `Invoke-Psql` uses `-f` (NOT `-c`); Phase-4 \copy export uses `-f`; loadSql written no-BOM.
- grep: NO `& $psql ... -c ` remains (all query execution via -f). `psql --version` may stay.
- .ps1 itself UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse: `powershell -NoProfile -Command "$null=[System.Management.Automation.Language.Parser]::ParseFile('db\tools\Seed-ProdMirror.ps1',[ref]$null,[ref]$null);'PARSE-OK'"` → PARSE-OK.
- role-dba §B has the 2 new lessons.
- NO execution (operator re-runs Mode=Inspect after commit).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 — psql -f temp-file (kills PS -c quote-stripping + SQL BOM) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . no `-c` query exec . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
