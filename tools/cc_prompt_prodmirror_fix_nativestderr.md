# CC TASK — FIX Seed-ProdMirror.ps1: native pg-tool stderr terminates under EAP=Stop  [⛔ЧП · branch v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. Bug surfaced on the BLESSED Mode=Inspect run.
> Defect: with global `$ErrorActionPreference='Stop'` (L63), native pg-tool calls whose stderr is PIPED to a cmdlet (`| Out-Null`, `| Tee-Object`) convert a BENIGN stderr line (e.g. dropdb's `NOTICE: database "..." does not exist, skipping`) into a TERMINATING `NativeCommandError`. Observed: Phase 2 dropdb (L260) aborted the run. Same class at risk: pg_dump (L246 Tee), createdb (L264), pg_restore (L279). Variable-capture calls (`$x = & psql @a 2>&1`, L99/112/565) are SAFE (records captured, not thrown) — do NOT change those.

## 0. Mandatory reads (before any work)
- `.claude/skills/role-dba/role-dba.md` — §A CORE (incl ⛔ЧП block) + run §C VERIFY (object-store; mismatch → superseded).
- `.claude/skills/session-coord/session-coord.md` — §1 runbook, §3 commit discipline, §4 review, §10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40 rule).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §35 (PS1 UTF-8 BOM+CRLF, PS5.1-safe), §39.

## 1. §0.6a INTEGRITY block (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
# branch v3 (object-store). For every M: git hash-object <f> vs git rev-parse HEAD:<f>; restore truncated via git show HEAD:<f> > <f>.
sync
```
S1: if `.coord/push/request.md` present (content-based) → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_fix_nativestderr.md | status: open
### DIRECTIVE (spec->CC): fix native-stderr-under-Stop in db/tools/Seed-ProdMirror.ps1 via Invoke-Native helper. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B capture). gate: PS5.1 parse OK + Mode=Inspect dry-reasoning. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` (fix) · `.claude/skills/role-dba/role-dba.md` (§B lesson capture). No other file.

## 4. FIX — db/tools/Seed-ProdMirror.ps1 (keep UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL)

### 4.1 Add helper `Invoke-Native` (insert AFTER Invoke-PsqlFile, ~L117)
PS5.1-safe (no ternary/??, 2-arg Join-Path, `[pscustomobject]` OK):
```powershell
function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$Exe,
        [string[]]$Arguments = @(),
        [string]$LogFile,
        [switch]$SoftFail   # log + return exit code; do NOT throw on non-zero
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # native stderr must NOT terminate
    try {
        $out = & $Exe @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($LogFile) { $out | Out-File -FilePath $LogFile -Encoding utf8 }
    if (($code -ne 0) -and (-not $SoftFail)) {
        throw ("{0} exited {1}: {2}" -f $Exe, $code, ($out -join [Environment]::NewLine))
    }
    return [pscustomobject]@{ Code = $code; Output = $out }
}
```

### 4.2 Phase 1 — pg_dump backup (replace L246-249)
```powershell
$backup = Invoke-Native -Exe $pgDump -Arguments $backupArgs   # must succeed -> throws on non-zero
```
(Keep the L250 size-print line as-is.)

### 4.3 Phase 2 — dropdb (replace L260)
```powershell
$null = Invoke-Native -Exe $dropdb -Arguments @("-U", $SuperUser, "--if-exists", $StagingDb) -SoftFail
```
(`--if-exists` + SoftFail: a NOTICE on stderr with exit 0 is normal; never terminates now.)

### 4.4 Phase 2 — createdb (replace L264-267)
```powershell
$null = Invoke-Native -Exe $createdb -Arguments @("-U", $SuperUser, "-O", $SuperUser, $StagingDb)  # must succeed
```

### 4.5 Phase 2 — pg_restore (replace L274-282; remove the manual Continue-wrap, helper handles it)
```powershell
$restore = Invoke-Native -Exe $pgRestore -Arguments (@("-U", $SuperUser) + $restoreArgs) -LogFile $restoreLog -SoftFail
$restoreExit = $restore.Code
```
(KEEP the existing L284-289 hard-error log scan unchanged — pg_restore soft-fails on benign role/owner notices; the log scan + Phase-3 row counts catch real failure.)

### 4.7 PS5.1 BUG — `Join-String` is PS7-only (replace at L556 + L571)
`Join-String` does NOT exist in Windows PowerShell 5.1 → the Load path breaks ("term not recognized"). Replace both with the PS5.1-safe `-join` operator:
- L556: `$selectExpr = @($intCols | ForEach-Object { "`"$_`"" }) -join ", "`
- L571: `$colList    = @($intCols | ForEach-Object { "`"$_`"" }) -join ", "`
(Wrap the ForEach output in `@(...)` so a single-column table yields an array, not a scalar — `-join` on a scalar still works but `@()` keeps it uniform.)

### 4.8 Phase-3 INSPECT additions — RTSData_* timestamp range + re-stamp confirmation (coordinator 01:35/02:05)
In PHASE 3 (Inspect), AFTER the per-table count/TenantId loop, add — for the chosen/likely client `$srcTenant` (or per distinct tenant if not yet resolved):
1. Emit min/max of the business timestamps on `RTSData_Interaction` (drives bi's hist backfill range, ROUTE 1a [min,max]):
   ```
   SELECT min("InQueueDateTime"), max("InQueueDateTime"),
          min("AnsweredDateTime"), max("AnsweredDateTime"),
          min("UpdateTime"), max("UpdateTime")
   FROM "RTSData_Interaction" WHERE "TenantId" = '<srcTenant>'
   ```
   Append to the inspect report as: `RTSData_Interaction InQueueDateTime [min..max]: ...` (+ Answered/Update lines). Also emit the RTSData_UserStatus time-range if it has a timestamp column (discover via information_schema; do NOT hardcode a missing name).
2. Append a CONFIRMATION line to the report (verbatim):
   `RE-STAMP POLICY: TenantId-ONLY — business timestamps (InQueueDateTime/AnsweredDateTime/UpdateTime) are PRESERVED at their ORIGINAL historical values (NOT re-stamped). hist_* backfill must cover the [min,max] above (DEFAULT partition covers old months for the one-time proof).`
Guard each timestamp query with a column-existence check (information_schema) so it no-ops cleanly if a column is absent in the prod-234 staging schema.

### 4.6 Do NOT touch
Invoke-Psql / Invoke-PsqlFile (L88-117), the `& $tool --version` lines (L199/201/203 — stdout only), the L565 `$copyResult = & $psql ... 2>&1` variable-capture (safe). Bare `--version` calls may stay; if any emits stderr in your env, route through Invoke-Native too — but they are stdout-only.

## 5. §B CAPTURE (NORM-CUR-11 — append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
Append ONE dated line under §B LESSONS:
TWO lines (native-stderr + Join-String):
`- 2026-06-25 · PS native pg-tool call whose stderr is PIPED to a cmdlet (| Out-Null / | Tee-Object) under $ErrorActionPreference='Stop' turns BENIGN stderr (dropdb NOTICE) into a terminating NativeCommandError; variable-capture ($x = & tool 2>&1 + $LASTEXITCODE) is safe. FIX: route native calls through an Invoke-Native helper (EAP='Continue' local + $LASTEXITCODE), never pipe native stderr under Stop. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 (dropdb L260) · status: active`
`- 2026-06-25 · `Join-String` is a PS7-only cmdlet — absent in Windows PowerShell 5.1; use the `-join` OPERATOR (wrap source in @() for single-item uniformity). Grep new PS1 for Join-String before ship. · SOURCE: Seed-ProdMirror.ps1 L556/L571 · status: active`

## 6. Acceptance (THIS task)
- Invoke-Native helper present; L246/L260/L264/L274-282 routed through it; UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe.
- **Join-String removed** (L556+L571 → `-join`); NO PS7-only constructs remain (grep `Join-String` = 0).
- **Phase-3 Inspect** emits RTSData_Interaction InQueueDateTime/AnsweredDateTime/UpdateTime [min,max] + the TenantId-only re-stamp confirmation line (guarded by column-existence).
- Parse: `powershell -NoProfile -Command "$null=[System.Management.Automation.Language.Parser]::ParseFile('db\tools\Seed-ProdMirror.ps1',[ref]$null,[ref]$null);'PARSE-OK'"` → PARSE-OK.
- role-dba.md §B has the new lesson line(s).
- NO execution of the seed/restore (operator re-runs Mode=Inspect after commit).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md` (gitignore blocks .claude/). NEVER `git add -A`; do NOT sweep the stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 — Invoke-Native native-stderr + Join-String->-join (PS5.1) + Phase-3 [min,max] emit + role-dba §B`.
- §0.6 post-commit verify; journal via `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
