# CC Task — Create db/tools/Compare-ToBaseline.ps1 (DB drift comparator: installed server vs repo baseline)

> Session devops-2-0607. Build a READ-ONLY PowerShell comparator that diffs a live PostgreSQL
> server against the repo baseline (db/schema.sql, db/functions/*.sql, db/data/*.sql, db/migrations/*.sql)
> and emits (1) a human-readable delta report and (2) an IDEMPOTENT alignment SQL the operator runs
> as postgres to bring the server up to baseline. The script NEVER writes to the target DB.
> Motivation: the _009 FUNCTION-vs-PROCEDURE drift (error 42809) must be a first-class check (prokind).

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
Claims for this task: `db/tools/Compare-ToBaseline.ps1` (new file — explicit file claim)

### S1. Push barrier check — before ANY work
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."
    exit 1
fi
```
(A phantom dirent that is EMPTY is not a barrier — the `-s` content check above handles L-SC-10.)

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/tools/Compare-ToBaseline.ps1
# exit 1 -> STOP (another active session holds it -> queue, skill §9)
```
Modify ONLY `db/tools/Compare-ToBaseline.ps1` (plus throwaway scripts in `/tmp`). New file — it must
appear under `git status --short | grep "^??"`; add it explicitly when committing.

### S3. Commit lock — around EVERY git add/commit (phantom-aware, retry 5×60 s)
Use the standard `/tmp/acquire_lock.py` from `tools/cc_prompt_sync_block.md` (owner `devops-2-0607`).
If FAILED: abort commit, report lock owner. Stale > 15 min: report contents, WAIT — never auto-delete.
While holding: `bash tools/pre-commit-check.sh` -> `git add db/tools/Compare-ToBaseline.ps1`
-> `git commit -m "db: add Compare-ToBaseline.ps1 DB drift comparator"` -> §0.6 post-commit verify.

### S4 + S4b. Post-commit wrapper (NON-SKIPPABLE)
```bash
bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)
```
If non-zero: reconcile `.coord/journal.md` vs `git log`, re-run before continuing. Then `sync`.

### S5. Git push — DO NOT push (§37). Rides the next push barrier.

---

## File to write — db/tools/Compare-ToBaseline.ps1

A `#Requires -Version 5.1`, `[CmdletBinding()]` script. **READ-ONLY on the target** — it may only run
`SELECT` / `pg_dump --schema-only`; it must NEVER execute DDL/DML against the target. The only writes are
the two output files in `-OutDir`.

Add a header comment block at the top of the .ps1 with a TODO: "Dimension D (migration ledger) is heuristic
(per-migration object-presence probes) because this project has no `public.db_patch_history` table yet. If/when
such a ledger is introduced, D should read applied migration names directly from it for an exact result."

### Parameters
```powershell
param(
    [string]$DBHost   = "localhost",
    [string]$DBPort   = "5432",
    [string]$Database = "rtmviewdb",
    [string]$User     = "ccdashboard_user",   # read-only role is sufficient
    [string]$Password = "",
    [string]$OutDir   = ""                      # default: <repo>/Installations
)
$ErrorActionPreference = "Stop"
```

### Conventions to REUSE from db/tools/Export-All.ps1 (copy the patterns verbatim, do not reinvent)
- `Find-PGTool` helper (Get-Command fallback to `C:\Program Files\PostgreSQL\{18,17,16,15}\bin\<tool>.exe`).
  Resolve BOTH `psql` and `pg_dump`; throw if either missing.
- `$env:PGPASSWORD = $Password` when non-empty; clear it at the end (`$env:PGPASSWORD = ""`).
- `$ScriptDir` / `$RepoRoot` derivation (`Split-Path` twice from `$MyInvocation.MyCommand.Path`).
- `$DbDir = Join-Path $RepoRoot "db"`. Default `$OutDir = Join-Path $RepoRoot "Installations"` (create if absent).
- A `Run-SQL` helper that writes the query to a temp .sql (no BOM) and runs
  `& $psql -h $DBHost -p $DBPort -U $User -d $Database -t -A -F '|' -f $tmp 2>&1`, returning rows.
- BOM-less UTF-8 for any file fed to `psql -f` (the alignment SQL) — `[System.Text.UTF8Encoding]::new($false)`.
  CRLF line endings.

### Output file names (in $OutDir)
- `baseline_delta_<Database>_<yyyyMMdd-HHmmss>.txt` — human-readable delta, all dimensions A–D.
- `align_<Database>_<yyyyMMdd-HHmmss>.sql` — IDEMPOTENT alignment script (header comment with run instruction:
  `psql -h <host> -U postgres -d <db> -v ON_ERROR_STOP=1 -f <thisfile>`, run as postgres). If there is NO drift,
  still write the file with a `-- No drift detected. Server matches baseline.` body and report that clearly.

### Compare dimensions — report EACH, in this order

**A. SCHEMA**
- `pg_dump -h ... -U $User -d $Database --schema-only --no-owner --no-acl --schema=public --schema=identity --schema=audit`
  to a temp file. Normalise (strip comments `^--`, `SET ...`, blank lines, `OWNER TO`, trailing whitespace; keep
  statement order but compare statement SETS) and diff vs `db/schema.sql` normalised the same way.
- Report: tables present in baseline but missing on target; tables on target not in baseline; for common tables,
  columns missing/extra (parse `CREATE TABLE` column lists); indexes missing/extra (`CREATE INDEX` / `CREATE UNIQUE INDEX`).
- Keep it pragmatic: a line-set difference of the normalised dumps is acceptable as the core signal, with a
  best-effort breakdown by object. Do NOT attempt a perfect SQL parser.
- Alignment contribution: schema drift is reported but NOT auto-fixed by raw ALTERs (too risky). Instead, the
  alignment file lists the UNAPPLIED MIGRATIONS (dimension D) that are the proper source of schema changes, and
  for anything not covered by a migration, emit a `-- MANUAL REVIEW:` comment block (never a guessed ALTER).

**B. ROUTINE KIND (CRITICAL — the _009 / 42809 class)**
- Build the expected routine inventory by scanning `db/functions/*.sql` for
  `CREATE (OR REPLACE )?(PROCEDURE|FUNCTION) <name>(<args>)` — capture name, expected kind (p/f), and arg count.
- Query the target once:
  ```sql
  SELECT n.nspname, p.proname, p.prokind, p.pronargs
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('public','identity','audit')
  ORDER BY 1,2;
  ```
- For every expected routine: FLAG if absent; FLAG if `prokind` differs (repo PROCEDURE 'p' but target FUNCTION 'f',
  or vice-versa); FLAG if `pronargs` differs. This is the §33.8 [RTM-SEC-002] check — make it prominent in the report.
- Alignment contribution (idempotent): for each kind-mismatch emit
  `DROP FUNCTION IF EXISTS <schema>.<name>(<argtypes>);` then the canonical `CREATE PROCEDURE ...` (or the reverse),
  taken VERBATIM from the matching `db/functions/*.sql` definition. For a missing routine, emit the canonical
  `CREATE OR REPLACE ...` from the function file. (Cannot REPLACE a function with a procedure — DROP first; that is
  exactly the _009 lesson, CLAUDE.md §33.8.)

**C. DATA — RTSGrid_Metric + RTSGrid_MetricTranslation**
- Parse the expected `MetricId` set (and a few key cols: `MetricFunction`, `MetricParameter`, `MetricType`,
  `DisplayName` presence) from `db/data/02_metrics.sql` (COPY block). Query the target
  `SELECT "MetricId","MetricFunction","MetricParameter","MetricType",("DisplayName" IS NOT NULL) FROM "RTSGrid_Metric"`.
  Report: MetricIds missing on target, extra on target, and changed key cols.
- Same for `RTSGrid_MetricTranslation` vs `db/data/05_metric_translations.sql` (key: MetricId + Locale).
- Alignment contribution (idempotent): for missing rows emit
  `INSERT INTO "RTSGrid_Metric" (...) VALUES (...) ON CONFLICT ("MetricId") DO NOTHING;` and for changed key cols a
  value-matched `UPDATE ... WHERE "MetricId" = '...';`. EXTRA rows on target are reported only (commented
  `-- EXTRA on server (not in baseline): <id>` — never auto-DELETE data).

**D. MIGRATION LEDGER**
- List `db/migrations/*.sql` (name-sorted). There is NO `public.db_patch_history` table in this project today —
  so: if `db_patch_history` exists on the target, read applied names from it; ELSE determine applied/unapplied by a
  per-migration object-presence probe (heuristic): each migration's defining object (e.g. `_009` -> prokind='p' for
  NGC_SetUserAgentgroup; `_006` -> the 4 UNAVAILABLE MetricIds present; `_007` -> `NGC_UserAgentgroup` table exists).
  Implement probes as a name->SQL map at the top of the script; for migrations without a probe, report `UNKNOWN`
  (cannot determine) rather than guessing applied.
- Report applied / unapplied / unknown lists.
- Alignment contribution: the alignment SQL begins with the UNAPPLIED migrations (name-ordered). Do NOT inline
  their bodies blindly via `\i` (wrong for a single-file run); instead CONCATENATE each unapplied migration's file
  content into the alignment file in order, each preceded by `-- ===== migration <name> =====`. They are already
  idempotent (DROP IF EXISTS / IF NOT EXISTS / ON CONFLICT) per project convention. UNKNOWN migrations: emit a
  `-- UNKNOWN (probe absent) — operator verify: <name>` note, do not concatenate.

### Alignment file assembly ORDER (idempotent, run-as-postgres)
1. Header comment (run instruction + generated timestamp + target identity).
2. D: unapplied migrations concatenated in name order.
3. B: routine-kind fixes (DROP FUNCTION IF EXISTS + CREATE PROCEDURE, verbatim from db/functions).
4. C: data inserts/updates (ON CONFLICT DO NOTHING / value-matched UPDATE).
5. A: `-- MANUAL REVIEW:` blocks for schema drift not covered above.
Wrap the whole file with `\set ON_ERROR_STOP on` at the top.

### Console summary at the end
Print a colored summary: counts per dimension (schema-diff lines, routine flags, metric drift, unapplied
migrations) + the two output paths. Exit 0 always on a successful comparison (drift is a finding, not an error);
exit non-zero only on connection/tool failure.

### Self-test (no commit dependency)
After writing, run a dry parse to ensure the script has no syntax errors:
```powershell
powershell -NoProfile -Command "& { . 'D:\Claude\Projects\RTM View Shell\db\tools\Compare-ToBaseline.ps1' -? } " 2>&1 | Select-Object -First 5
```
(or `Get-Command -Syntax` after a dot-sourcing guard). Do NOT run it against a live DB in this task — the operator
runs it later with credentials. If a live smoke is desired, the operator will supply -Password.

## Commit
One commit, prefix `db:`, message `db: add Compare-ToBaseline.ps1 DB drift comparator (schema/prokind/data/migrations)`.
Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
