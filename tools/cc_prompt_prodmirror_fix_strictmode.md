# CC TASK — FIX Seed-ProdMirror.ps1: StrictMode `.Count` on scalar/null  [⛔ЧП · v3 · DBA]

> Authored by dba-0625 for coordinator §4-bless. The psql-quoting fix WORKED (Phase 3 now runs the queries). New runtime error: `The property 'Count' cannot be found on this object ... PropertyNotFoundStrict`. Cause: `Set-StrictMode -Version Latest` (L64) + `.Count` on a value that is a SCALAR or `$null` — PowerShell unwraps a single-element `@()` to a scalar AND an empty `@()` to `$null` on FUNCTION RETURN, so `$x.Count` throws under StrictMode (DEPLOY-16 / §35 class). This task ONLY edits db/tools/Seed-ProdMirror.ps1. No execution.

## 0. Mandatory reads
- `.claude/skills/role-dba/role-dba.md` §A CORE (⛔ЧП) + §C VERIFY (object-store).
- `.claude/skills/session-coord/session-coord.md` §1/§3/§4/§10.
- `.claude/skills/widget-planner/widget-planner.md` + `.claude/skills/widget-creator/widget-creator.md` (§40).
- CLAUDE.md §0.2/§0.3/§0.4/§0.5, §24/§35 (StrictMode @() wraps; PS5.1-safe; PS1 UTF-8 BOM+CRLF), §39.

## 1. §0.6a INTEGRITY (Step 0)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short   # branch v3 object-store; M files hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
sync
```
S1: if `.coord/push/request.md` present → STOP.

## 2. §0.6b BINDING preamble (.coord/cc/dba.md, Python+os.fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_prodmirror_fix_strictmode.md | status: open
### DIRECTIVE (spec->CC): harden all StrictMode .Count sites in db/tools/Seed-ProdMirror.ps1 with @() wraps + array-assign function results. claim: db/tools/Seed-ProdMirror.ps1 + .claude/skills/role-dba/role-dba.md (§B). gate: parse PS5.1 + grep audit. NO push.
```

## 3. CLAIM (db file-mode)
- `db/tools/Seed-ProdMirror.ps1` (fix) · `.claude/skills/role-dba/role-dba.md` (§B). No other file.

## 4. FIX (keep .ps1 UTF-8 BOM+CRLF, PS5.1-safe, 0 NUL)

### 4.1 Array-assign function results that feed `.Count` / `-contains`
- L365: `$stagCols = @(Get-TableColumns -Database $StagingDb -TableName $tbl)`
- L366: `$ourCols  = @(Get-TableColumns -Database $DbName    -TableName $tbl)`
- L(Phase-4, where `$intCols = Get-IntersectionColumns ...`, ~L607/619 context): `$intCols = @(Get-IntersectionColumns ...)`
(Get-TableColumns/Get-IntersectionColumns build `@(...)` internally but PowerShell UNWRAPS single/empty arrays on return → wrap at the call site.)

### 4.2 Wrap every remaining `.Count` whose target may be scalar/null with `@(...)`
Apply to these (and any others a final grep finds):
- L367: `if (@($ourCols).Count -eq 0)`
- L422: `$hasInQueueDateTime = @($colCheckResult | Where-Object { $_ -and $_.Trim() }).Count -gt 0`
- L436: `if (@($tsVals).Count -ge 6)`
- L450: `if (@($usTimestampCols).Count -gt 0)`
- L457: `if (@($usVals).Count -ge 2)`
- L619: `if (@($intCols).Count -eq 0)`
- L755: `... $(@($bus).Count)`  · L757: `if (@($bus).Count -gt 0)`
- L770: `... $(@($qs).Count)`   · L790: `... $(@($ags).Count)`
Also array-assign $tsVals/$usVals/$usTimestampCols/$bus/$qs/$ags where they come from a query/pipeline (e.g. `$bus = @(Invoke-Psql ...)`), so `-join` and indexing are also safe.

### 4.3 LEAVE AS-IS (already safe)
- L370-372 (`$intersection`/`$stagOnly`/`$ourOnly` already `@()`-wrapped) → L373/374/377 fine.
- L484/485 `$srcTenantIds.Keys.Count` (hashtable KeyCollection has .Count) — fine.
- L584 `$t.Count` (hashtable entry property) — fine.

### 4.4 Final self-audit (report in RESULT)
Grep the file for `\.Count` and confirm EVERY occurrence is either `@(...).Count`, `.Keys.Count`, or a hashtable-property `.Count`. List any intentionally left.

## 5. §B CAPTURE (append to .claude/skills/role-dba/role-dba.md §B; `git add -f`)
```
- 2026-06-25 · Under `Set-StrictMode -Version Latest`, `$x.Count` THROWS PropertyNotFoundStrict when $x is a scalar (single-item) or $null (empty) — PowerShell unwraps single/empty @() on FUNCTION RETURN. FIX: assign function/pipeline results via `$x = @(...)` AND wrap every count read as `@($x).Count`. Leave hashtable .Keys.Count / property .Count. · SOURCE: Seed-ProdMirror.ps1 Inspect run 2026-06-25 · status: active
```

## 6. Acceptance
- Every `.Count` is `@(...).Count` / `.Keys.Count` / hashtable-property; Get-TableColumns + Get-IntersectionColumns results array-assigned.
- .ps1 UTF-8 BOM+CRLF, 0 NUL, PS5.1-safe; parse: `powershell -NoProfile -Command "$null=[System.Management.Automation.Language.Parser]::ParseFile('db\tools\Seed-ProdMirror.ps1',[ref]$null,[ref]$null);'PARSE-OK'"` → PARSE-OK.
- role-dba §B has the new lesson.
- NO execution (operator re-runs Mode=Inspect after commit).

## 7. Commit (commit.lock; NO push — §37)
- Acquire `.coord/locks/commit.lock` (atomic x, retry 5×60s, content-based stale).
- `pre-commit-check.sh`; NARROW add: `git add db/tools/Seed-ProdMirror.ps1` + `git add -f .claude/skills/role-dba/role-dba.md`. NEVER `git add -A`; do NOT sweep stray 20260606100233 / Installations/*.
- Prefix `fix:` — `fix(db): Seed-ProdMirror.ps1 — StrictMode @() wraps on .Count (scalar/null) + role-dba §B`.
- §0.6 post-commit verify; journal `bash tools/cc_post_commit.sh dba-0625 <hash>` (else Python+fsync journal+flush+lock-release); §0.7 re-sync. NO push.

## 8. §0.6b BINDING postamble (.coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files Seed-ProdMirror.ps1 + role-dba.md . .Count audit clean . parse PS5.1 OK . status done . blockers <none|...> . verified: object-store
```
