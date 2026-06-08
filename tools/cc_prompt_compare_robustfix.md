# CC Task — Compare-ToBaseline.ps1 robustness fixes (standalone run on prod) — ledger/_002/§38a/§43 ALREADY done

> Session devops-2-0607. The ledger (_002), CLAUDE.md §38a/§43, and Compare dimension-D hybrid are ALREADY
> committed in 019d513 — do NOT redo them. This task ONLY fixes two crashes found running the comparator on a
> real prod server (Windows PowerShell 5.1). The committed Compare-ToBaseline.ps1 (HEAD 019d513, 464 lines) has
> NO -BaselineDir param and STILL has 3-arg Join-Path at ~266/~397.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync
echo "=== Integrity check complete ==="
```
NOTE: db/tools/Compare-ToBaseline.ps1 is currently TRUNCATED in the working tree (429 vs HEAD 464). The loop
above MUST restore it from HEAD before you start. Confirm it is 464 lines after restore.
Known false-M (hash==HEAD, do NOT restore): `db/data/02_metrics.sql`, `db/schema.sql`.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS

Session slug: `devops-2-0607`
Claims for this task: `db/tools/Compare-ToBaseline.ps1`

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/tools/Compare-ToBaseline.ps1
```
Modify ONLY `db/tools/Compare-ToBaseline.ps1` (plus throwaway scripts in `/tmp`).

### S3. Commit lock — around the git add/commit (phantom-aware, retry 5×60 s)
Use `/tmp/acquire_lock.py` from `tools/cc_prompt_sync_block.md` (owner `devops-2-0607`).
While holding: `bash tools/pre-commit-check.sh` -> `git add db/tools/Compare-ToBaseline.ps1`
-> `git commit -m "db: Compare-ToBaseline -BaselineDir + PS5.1 Join-Path fix (standalone prod run)"`
-> §0.6 post-commit verify.

### S4 + S4b. Post-commit wrapper (NON-SKIPPABLE)
```bash
bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)
```
If non-zero: reconcile `.coord/journal.md` vs `git log`, re-run. Then `sync`.

### S5. Git push — DO NOT push (§37). Rides the next push barrier.

---

## The two fixes (modify db/tools/Compare-ToBaseline.ps1 ONLY)

### Fix 1 — `-BaselineDir` param + empty-RepoRoot guard (the standalone-run crash)
Live bug: run from `C:\Temp\Compare-ToBaseline.ps1`, `$RepoRoot = Split-Path -Parent (Split-Path -Parent
$ScriptDir)` collapses to "" two levels under a drive root, then `Join-Path $RepoRoot "db"` throws
"Cannot bind argument to parameter 'Path' because it is an empty string."

1. Add a parameter `[string]$BaselineDir = ""` to the `param(...)` block (path to the repo `db` folder that
   contains schema.sql / functions/ / data/ / migrations/).
2. Replace the path-derivation block:
   ```powershell
   $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
   $RepoRoot  = Split-Path -Parent (Split-Path -Parent $ScriptDir)
   $DbDir     = Join-Path $RepoRoot "db"
   if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "Installations" }
   ```
   with a robust version:
   - if `$BaselineDir` non-empty -> `$DbDir = (Resolve-Path $BaselineDir).Path`;
   - else derive from `$ScriptDir`; if `$ScriptDir` or `$RepoRoot` is empty, do NOT Join-Path on it;
   - VALIDATE: `if (-not (Test-Path (Join-Path $DbDir 'schema.sql'))) { throw "Baseline db/ folder not found.
     Pass -BaselineDir <path to the repo 'db' folder> (must contain schema.sql, functions\, data\, migrations\)." }`
   - `$OutDir` default: if empty -> use `$PWD` (current dir) when `$RepoRoot` is empty, else
     `Join-Path $RepoRoot "Installations"`. Never Join-Path on an empty string.
3. Update `.SYNOPSIS`/`.PARAMETER`/`.EXAMPLE` to document `-BaselineDir`, e.g.
   `.\Compare-ToBaseline.ps1 -Password "pw" -BaselineDir "C:\Temp\db" -OutDir "C:\Temp\Out"`.

### Fix 2 — 3-arg Join-Path -> nested 2-arg (PowerShell 5.1; dimension-C crash)
Live bug: dimension C crashed with "A positional parameter cannot be found that accepts argument
'02_metrics.sql'." 3-arg Join-Path is PS7+ only.
- line ~266: `Join-Path $DbDir "data" "02_metrics.sql"` -> `Join-Path (Join-Path $DbDir "data") "02_metrics.sql"`
- line ~397: `Join-Path $DbDir "migrations" "$migName.sql"` -> `Join-Path (Join-Path $DbDir "migrations") "$migName.sql"`
- Grep the whole script for any other 3-arg Join-Path and convert them too.

Leave dimensions A/B/C/D logic, outputs, and the READ-ONLY guarantee otherwise UNTOUCHED.

## Self-test (no live DB)
```powershell
powershell -NoProfile -Command "$null = [ScriptBlock]::Create((Get-Content -Raw 'D:\Claude\Projects\RTM View Shell\db\tools\Compare-ToBaseline.ps1')); 'PARSE OK'"
```
Also grep-confirm: `-BaselineDir` param present; the baseline-not-found throw present; NO remaining 3-arg
Join-Path. Do NOT run against a live DB here — operator re-runs on prod (Track 3a) afterwards.

## Commit
ONE commit, prefix `db:`, message:
`db: Compare-ToBaseline -BaselineDir + PS5.1 Join-Path fix (standalone prod run)`
Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
