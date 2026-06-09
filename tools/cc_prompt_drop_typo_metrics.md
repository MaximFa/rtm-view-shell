# CC Task — (a) drop typo metrics QueueNumAbandonef* from deployed DBs (new migration, §38a)

> Issued by Cowork session **RTM Metrcs** (slug `metrics-3-0609`, METRICS specialist).
> Coordinator-assigned NO-IDLE GO (coordinator-0609, 2026-06-09T16:40Z). Post-release, push-independent,
> **NOT in the Server-234 to-apply path.** For §4 review before issuing.

## Background (verified on v2-backend, 2026-06-09)
The typo metric ids `QueueNumAbandonefCalls` / `QueueNumAbandonefCallbacks` are ALREADY ABSENT from the repo
data paths — `db/data/02_metrics.sql`, `db/baseline.sql`, and `src/.../DatabaseInitializer.cs` carry only the
CANONICAL `QueueNumAbandonedCalls` / `QueueNumAbandonedCallbacks` (the 2026-06-06 rename was applied). So:
- On a FRESH install the typo rows never exist → this migration is a safe no-op.
- On databases installed BEFORE the rename, leftover typo rows in `RTSGrid_Metric` are removed here.
This migration is therefore a DEPLOYED-DB cleanup only. NO seeder/baseline edits are needed (all-paths rule is
already satisfied by the prior rename — the verify step below CONFIRMS this; if a typo is unexpectedly still in a
repo path, STOP and report — it means the rename did not land on this branch).
NOTE: the older `tools/cc_prompt_remove_typo_metrics.md` (slug devops-0606, RENAME approach, targets old
`origin/v2`) is SUPERSEDED — do not run it; this DELETE migration is the v2-backend approach.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST
```bash
cd "D:\\Claude\\Projects\\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES)"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== integrity complete ==="
```

## Mandatory — read before starting (§40)
```
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: tools/cc_prompt_sync_block.md
```
Apply the FULL S1–S5 sync block from tools/cc_prompt_sync_block.md with the slug + claims below.
S1 (barrier): block ONLY if .coord/push/request.md content contains "FREEZE ACTIVE" (tombstone/phantom must NOT block).
S2: `python3 tools/coord_check_claims.py metrics-3-0609 <each claimed path>` — exit 1 => STOP.
Touch ONLY the claimed files (+ /tmp/metrics-3-0609_*.py throwaways, L-SC-16).

Session slug: `metrics-3-0609`
Claims for this task: `db/migrations/20260609_001_drop_typo_metrics.sql`  (new file; db module, file-mode)

## Task — create the migration (Python+fsync write of the .sql; Edit tool BANNED §0.3)
Create `db/migrations/20260609_001_drop_typo_metrics.sql` with EXACTLY this content:
```sql
-- 20260609_001_drop_typo_metrics.sql
-- Remove the two typo'd RTSGrid_Metric rows from DEPLOYED databases.
-- Repo seeder + baseline already carry the canonical ids (rename applied on v2-backend),
-- so on a fresh install the typo rows never exist and this is a no-op. On databases installed
-- before the rename, the leftover typo rows are removed here.
-- Idempotent: defensive cell remap first, then DELETE ... WHERE. §38a: self-records in db_patch_history.
\set ON_ERROR_STOP on

-- 1) Defensive: re-point any grid cell still bound to a typo id -> canonical (none expected on v2-backend)
UPDATE "RTSGrid_Cell" SET "Value" = 'QueueNumAbandonedCalls'     WHERE "Value" = 'QueueNumAbandonefCalls';
UPDATE "RTSGrid_Cell" SET "Value" = 'QueueNumAbandonedCallbacks' WHERE "Value" = 'QueueNumAbandonefCallbacks';

-- 2) Remove translation rows for the typo ids, if any (PK = MetricId,Locale)
DELETE FROM "RTSGrid_MetricTranslation" WHERE "MetricId" IN ('QueueNumAbandonefCalls','QueueNumAbandonefCallbacks');

-- 3) Delete the typo metric rows
DELETE FROM "RTSGrid_Metric" WHERE "MetricId" IN ('QueueNumAbandonefCalls','QueueNumAbandonefCallbacks');

-- 4) §38a self-record
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260609_001_drop_typo_metrics') ON CONFLICT (migration_name) DO NOTHING;

-- Verification
SELECT count(*) AS typo_metrics_remaining FROM "RTSGrid_Metric"
  WHERE "MetricId" IN ('QueueNumAbandonefCalls','QueueNumAbandonefCallbacks');     -- expect 0
SELECT count(*) AS typo_cell_refs_remaining FROM "RTSGrid_Cell"
  WHERE "Value" IN ('QueueNumAbandonefCalls','QueueNumAbandonefCallbacks');        -- expect 0
SELECT "MetricId" FROM "RTSGrid_Metric"
  WHERE "MetricId" IN ('QueueNumAbandonedCalls','QueueNumAbandonedCallbacks') ORDER BY 1;  -- canonical present
```

## All-paths verification (no edits — must already be clean)
```bash
echo "typo in repo paths (must be empty):"
grep -rn "QueueNumAbandonef" db/data/02_metrics.sql db/baseline.sql src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs || echo "  none (rename already applied) ✓"
# If ANY hit -> STOP, report: rename did not land on this branch (escalate to coordinator).
```

## Lint must stay green
```bash
python3 tools/lint_metrics.py ; echo "lint exit=$?"   # expect exit 0 (this migration doesn't touch 02_metrics)
```

## Commit (under commit.lock, §42.4 + §0.5/§0.6) — ONE commit
Acquire commit.lock (phantom-aware /tmp/acquire_lock.py from the sync block, owner=metrics-3-0609).
While holding it:
```bash
bash tools/pre-commit-check.sh db/migrations/20260609_001_drop_typo_metrics.sql
git add db/migrations/20260609_001_drop_typo_metrics.sql
git commit -m "db: drop typo metrics QueueNumAbandonef{Calls,Callbacks} from deployed DBs (new migration 20260609_001, §38a self-record)"
```
If index.lock/HEAD.lock blocks → §0.4 plumbing path (commit-tree + direct ref write) under the SAME lock.
Post-commit §0.6: `git status --short` for the file(s) clean; `git diff HEAD -- db/migrations/20260609_001_drop_typo_metrics.sql` empty; committed line count == working tree.

## S4+S4b — MANDATORY wrapper (NON-SKIPPABLE)
```bash
bash tools/cc_post_commit.sh metrics-3-0609 $(git log -1 --format=%h)
```
It appends the journal line + coordinator flush + releases the lock. **L-SC-04: this wrapper often drops the
journal line / flush through the mount — Cowork (metrics-3-0609) will reconcile against `git log` after.**
If it exits non-zero, the journal/flush did not land — report so Cowork restores them.

## PD-007 — FINAL re-sync from HEAD (counteracts Cowork cache write-back)
```bash
for f in db/migrations/20260609_001_drop_typo_metrics.sql; do git show HEAD:"$f" > "$f"; echo "Re-synced: $f"; done
sync
```

## Git push
Do NOT run `git push` (§37). Commit only. Push is requested separately via tools/cc_prompt_push.md.
