# CC Task: Apply RTSGrid_Metric dedup migration + export DB to git

> Source analysis: `docs/RTM_Shell_Metrics_Overview.md` §4–§5 (Metrics catalog session, 2026-06-05).
> Migration file ALREADY CREATED by Cowork: `db/migrations/20260605_004_metrics_dedup.sql` — apply it, do not rewrite it.
> Engine verification done: Calc key lookup is exact-match (trailing-space ref broken);
> `QueuePctAnsweredCalls60secIncLast30min` throws in Eval() every calc cycle — deleted by the migration.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Only after reading both files: proceed with the task below.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF lines)"
        git show HEAD:"$f" > "$f"
        echo "RESTORED: $f"
    else
        echo "OK: $f ($WT_LINES lines)"
    fi
done
sync
echo "=== Integrity check complete ==="
```

## Step 1 — Verify migration file integrity

```bash
wc -l db/migrations/20260605_004_metrics_dedup.sql    # expected: 81 lines
tail -3 db/migrations/20260605_004_metrics_dedup.sql  # must end with the orphan_cells SELECT
```
If truncated: STOP, report. Do not reconstruct.

## Step 2 — Pre-flight reference snapshot (dev DB `rtmviewdb`, user `ccdashboard_user`)

Record (for the commit message) which references will be re-pointed:

```sql
SELECT 'cell' src, "Value" AS metric, count(*) FROM "RTSGrid_Cell"
WHERE "Value" IN ('QueueNumAcceptedCallbacks','QueueNumOnCallAgents','QueueNumberOfLoggedAgents','QueuePctAnsweredCalls60secIncLast30min')
GROUP BY "Value"
UNION ALL
SELECT 'col', "MetricId", count(*) FROM "RTSGrid_Column"
WHERE "MetricId" IN ('QueueNumAcceptedCallbacks','QueueNumOnCallAgents','QueueNumberOfLoggedAgents','QueuePctAnsweredCalls60secIncLast30min')
GROUP BY "MetricId";

-- Calc formulas referencing soon-to-be-deleted metrics (expected: none)
SELECT "MetricId" FROM "RTSGrid_Metric"
WHERE "MetricFunction" = 'Calc'
  AND ("MetricParameter" LIKE '%[QueueNumAcceptedCallbacks]%'
    OR "MetricParameter" LIKE '%[QueueNumOnCallAgents]%'
    OR "MetricParameter" LIKE '%[QueueNumberOfLoggedAgents]%'
    OR "MetricParameter" LIKE '%[QueuePctAnsweredCalls60secIncLast30min]%');

-- widget configs (jsonb -> text, widget-creator §26)
SELECT w."Id", d."Name" FROM dashboard_widgets w
JOIN dashboards d ON w."DashboardId" = d."Id"
WHERE w."ConfigJson"::text ILIKE ANY (ARRAY[
 '%QueueNumAcceptedCallbacks%','%QueueNumOnCallAgents%',
 '%QueueNumberOfLoggedAgents%','%QueuePctAnsweredCalls60secIncLast30min%']);
```

If Calc formulas reference deleted metrics: STOP, report (migration does not cover that case).
If widget ConfigJson references found: update them to the canonical IDs (jsonb text replace) AFTER Step 3.

## Step 3 — Apply migration

```powershell
psql -U ccdashboard_user -d rtmviewdb -f db\migrations\20260605_004_metrics_dedup.sql
```
Expected verification output: total_metrics = 198; remaining_deleted = 0; orphan_cells = 0;
`MonAgentNumberOfInboundCallsOnly` parameter has no "Intercom"; SLA ref has no trailing space.

## Step 4 — Check Shell/simulator code for hardcoded removed IDs

```bash
grep -rn "QueueNumAcceptedCallbacks\|QueueNumOnCallAgents\|QueueNumberOfLoggedAgents\|QueuePctAnsweredCalls60secIncLast30min" src/ tools/SignalRSimulator/ --include="*.cs" --include="*.razor"
```
If found: replace with canonical IDs (Python writes only, §0.3 — Edit tool is BANNED), then
`dotnet build CcDashboard.sln` (stop dotnet processes first, widget-creator §28).

## Step 5 — Export DB state to git

```powershell
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 -Password "!@#qweASDzxc" -CommitMessage "metrics dedup: remove 3 duplicates + broken Last30min Calc, fix InboundCallsOnly filter and SLA80 ref, description fixes (audit 2026-06-05)"
```
Ensure `db/migrations/20260605_004_metrics_dedup.sql` is included in the same `db:` commit
(stage it manually if Export-All does not pick it up).

## Step 6 — Pre-commit check + commit (only if Step 4 changed Shell files)

```bash
# MANDATORY before every commit — no exceptions
bash tools/pre-commit-check.sh
# If exit code 1: restore truncated files, retry Python write, then re-check
# Only after exit code 0: proceed with git add
```
Shell changes (if any) → separate `web:` commit (§0.4 index.lock workaround if needed).

## Step 7 — Post-commit verification + re-sync (§0.6, PD-007)

```bash
git status --short          # must be empty
git log --oneline -3
for f in db/migrations/20260605_004_metrics_dedup.sql db/data/02_metrics.sql; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

## Acceptance criteria
1. `SELECT count(*) FROM "RTSGrid_Metric"` returns 198 (202 − 3 duplicates − 1 broken Calc).
2. No references to the 4 removed MetricIds remain in `RTSGrid_Cell`, `RTSGrid_Column`, Calc formulas, `dashboard_widgets.ConfigJson`, Shell/simulator code.
3. `MonAgentNumberOfInboundCallsOnly` filter contains `CallType=="External"` and no `Intercom`.
4. `QueueSLAIn30secFrom80PctInc` parameter contains `[QueueNumAnsweredCalls30sec]` (no trailing space).
5. RTM Service log shows no `Union.getData.Calc` errors after restart (spot-check if service available).
6. Description fixes applied (11 rows) + DataType fix on `QueueLoginDataNumTrainingUsers`.
7. `db/data/02_metrics.sql` re-exported, `db:` commit created, working tree clean.
8. No `git push` performed.
