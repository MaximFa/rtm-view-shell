# CC Task — db_patch_history ledger: exact migration tracking + Compare dimension D upgrade

> Session devops-2-0607. Add a `public.db_patch_history` ledger so the migration-applied state is EXACT
> instead of heuristic. Then upgrade db/tools/Compare-ToBaseline.ps1 dimension D to read the ledger when
> present (exact), falling back to the existing object-presence probes for pre-ledger migrations (hybrid).
> Establish the convention: every NEW migration self-records its name on apply.
> Design choice (SAFE): we do NOT blind-backfill all 14 existing migrations as "applied" — that would make
> Compare trust them without verification and MASK real drift. The ledger is authoritative for what it
> contains; Compare probes anything not yet in the ledger. Over time the ledger becomes complete.

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
Known false-M (hash==HEAD, do NOT restore): `db/data/02_metrics.sql`, `db/schema.sql` — verify with
`git hash-object <f>` vs `git rev-parse HEAD:<f>` before touching.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS

Session slug: `devops-2-0607`
Claims for this task: `db/migrations/20260607_002_db_patch_history.sql`, `db/tools/Compare-ToBaseline.ps1`, `CLAUDE.md`

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
python3 tools/coord_check_claims.py devops-2-0607 db/migrations/20260607_002_db_patch_history.sql db/tools/Compare-ToBaseline.ps1 CLAUDE.md
# exit 1 -> STOP (another active session holds a path -> queue, skill §9)
```
Modify ONLY the three claimed files (plus throwaway scripts in `/tmp`). The new migration must appear under
`git status --short | grep "^??"`; add it explicitly when committing. CLAUDE.md is an append-only §-section.

### S3. Commit lock — around the git add/commit (phantom-aware, retry 5×60 s)
Use the standard `/tmp/acquire_lock.py` from `tools/cc_prompt_sync_block.md` (owner `devops-2-0607`).
If FAILED: abort commit, report lock owner. Stale > 15 min: report contents, WAIT — never auto-delete.
While holding: `bash tools/pre-commit-check.sh` -> `git add` (the 3 claimed files) ->
`git commit` (single `db:` commit; CLAUDE.md may ride a db: commit per §39.5) -> §0.6 post-commit verify.

### S4 + S4b. Post-commit wrapper (NON-SKIPPABLE)
```bash
bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)
```
If non-zero: reconcile `.coord/journal.md` vs `git log`, re-run before continuing. Then `sync`.

### S5. Git push — DO NOT push (§37). Rides the next push barrier.

---

## 1. New migration — db/migrations/20260607_002_db_patch_history.sql

Idempotent, BOM-less UTF-8, run as postgres (DDL). Content:

```sql
-- 20260607_002_db_patch_history.sql
-- Creates the migration ledger. From this migration onward, every migration self-records
-- its filename here on apply, so Compare-ToBaseline dimension D becomes EXACT (not heuristic).
-- Pre-ledger migrations are NOT backfilled here (Compare probes them); see CLAUDE.md §38a.
\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS public.db_patch_history (
    migration_name text PRIMARY KEY,
    applied_at     timestamptz NOT NULL DEFAULT now()
);

-- self-record this migration
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260607_002_db_patch_history')
ON CONFLICT (migration_name) DO NOTHING;
```

(Do NOT blind-insert the other 14 migration names — that is the deliberate safety choice above.)

## 2. Self-record convention — append to CLAUDE.md (new sub-section §38a, after §38)

Add a short section documenting: every NEW migration file MUST end with
```sql
INSERT INTO public.db_patch_history (migration_name)
VALUES ('<this-file-name-without-.sql>') ON CONFLICT (migration_name) DO NOTHING;
```
so applying it records itself. The ledger is created by 20260607_002. Migrations applied before the ledger
existed are tracked heuristically by Compare-ToBaseline.ps1 (object-presence probes) until they are
(optionally, later) backfilled. Note that Create-FreshDb.ps1 / Restore-All.ps1 apply migrations name-ordered,
so _002 creates the table before any later migration self-records. Keep this section ~12 lines, prose, no code
dump beyond the one INSERT snippet.

## 2b. CLAUDE.md §43 pointer (bonus — same commit, CLAUDE.md already claimed)

Append a new `## 43. External-server ops layout` section to CLAUDE.md (~6 lines, prose pointer — do NOT
duplicate the doc content). It must point to `docs/External-Server-Ops-Layout.md` as the authoritative
source and note the gist: every external/deployed server has a user-writable ops root `C:\RTMView-Ops\`
(separate from the app install) with `incoming\` / `applied\` (+ `_ledger.txt`) / `output\` / `backup\`;
PG version per server (PG17 on Server 45, PG18 on the others); CC produces scripts into the repo, the
operator places them on the server (CC has no direct external-server access). End with: "See
docs/External-Server-Ops-Layout.md for the full layout."

## 3. Compare-ToBaseline.ps1 — standalone-run robustness fix (Track 3a live finding) (claimed file)

> IMPORTANT: dimension D ledger-hybrid is ALREADY implemented in the committed script (lines ~336-410:
> reads `to_regclass('public.db_patch_history')` + `migration_name`, then ledger/probe/unknown). Do NOT
> re-implement it. This section fixes a CRASH found running the comparator on a real prod server.

BUG (live, 2026-06-07): run standalone from `C:\Temp\Compare-ToBaseline.ps1`, the script crashed with
"Cannot bind argument to parameter 'Path' because it is an empty string." Cause: `$RepoRoot = Split-Path
-Parent (Split-Path -Parent $ScriptDir)` collapses to "" when the script sits two levels below a drive root
(`C:\Temp` -> parent `C:\` -> parent ""), then `Join-Path $RepoRoot "db"` fails. Also: on a prod server the
repo baseline files (db/schema.sql, db/functions, db/data, db/migrations) are NOT present next to the script,
so even past the crash there is nothing to compare against.

FIX — make the baseline location explicit and validated:
1. Add a parameter `[string]$BaselineDir = ""` (path to the repo `db` folder containing schema.sql / functions/
   / data/ / migrations/).
2. Resolve `$DbDir` robustly:
   - if `$BaselineDir` is non-empty -> `$DbDir = $BaselineDir` (Resolve-Path; trim trailing slash);
   - else derive from script location as today, BUT guard each step: if `$ScriptDir` / `$RepoRoot` is empty
     OR the derived `db` folder does not exist, do NOT call Join-Path on an empty string.
   - After resolving, VALIDATE: `if (-not (Test-Path (Join-Path $DbDir 'schema.sql'))) { throw "Baseline not
     found. Pass -BaselineDir <path to the repo 'db' folder> (must contain schema.sql, functions\, data\,
     migrations\)." }` — a clear, actionable error instead of the cryptic Path-binding crash.
3. `$OutDir` default: if empty AND `$RepoRoot` empty -> fall back to the current directory (`$PWD`) or the
   system temp, never Join-Path on empty. (Operator already passes -OutDir; just don't crash without it.)
4. Update the `.SYNOPSIS`/`.EXAMPLE` + the param help to document `-BaselineDir` and a prod example:
   `.\Compare-ToBaseline.ps1 -Password "pw" -BaselineDir "C:\Temp\db" -OutDir "C:\Temp\Out"`.
5. Leave dimensions A/B/C/D logic, outputs, and the READ-ONLY guarantee otherwise UNTOUCHED.
6. SECOND LIVE BUG (Track 3a, after the BaselineDir interim): dimension C crashed with "A positional parameter
   cannot be found that accepts argument '02_metrics.sql'." Cause: 3-argument `Join-Path` is PowerShell 7+ only;
   on Windows PowerShell 5.1 (the prod target, #Requires -Version 5.1) `Join-Path` takes only -Path + -ChildPath.
   FIX both occurrences to NESTED 2-arg form:
   - line ~266: `Join-Path $DbDir "data" "02_metrics.sql"` -> `Join-Path (Join-Path $DbDir "data") "02_metrics.sql"`
   - line ~397: `Join-Path $DbDir "migrations" "$migName.sql"` -> `Join-Path (Join-Path $DbDir "migrations") "$migName.sql"`
   Grep the whole script for any other 3-arg Join-Path and convert them too. (Dimensions A + B already ran clean
   on prod: A=134 missing/103 extra lines, B=13 prokind mismatches — so only C/D were blocked by this.)

NOTE for the ops layout (covered by §43/the ops doc): to run on an external server the operator must ship the
`db/` baseline tree alongside the script (a small bundle) and point `-BaselineDir` at it. Mention this one-liner
in the §43 pointer text (step 2b): "comparator runs on a server need the db/ baseline shipped next to it
(-BaselineDir)."

Do NOT regenerate db/schema.sql in this task (that needs a live dump + DB credentials). Fresh installs get the
db_patch_history table because Create-FreshDb.ps1 / Restore-All.ps1 apply db/migrations/*.sql; existing servers
get it by applying _002. Note this in the migration header comment.

## 4. Self-test (no live DB)
- Dry-parse the modified script for syntax:
  ```powershell
  powershell -NoProfile -Command "$null = [ScriptBlock]::Create((Get-Content -Raw 'D:\Claude\Projects\RTM View Shell\db\tools\Compare-ToBaseline.ps1')); 'PARSE OK'"
  ```
- Confirm the migration file is valid SQL by eye (idempotent CREATE TABLE IF NOT EXISTS + INSERT ON CONFLICT).
- Confirm the new `-BaselineDir` param exists and the baseline-not-found guard throws a clear message (grep the script).
- Do NOT run Compare against a live DB here — the operator runs it separately (Track 3a) with credentials.

## Commit
ONE commit, prefix `db:`, message:
`db: db_patch_history ledger (_002) + Compare-ToBaseline -BaselineDir/standalone-run fix + CLAUDE.md §38a/§43`
(includes CLAUDE.md §38a per §39.5). Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
