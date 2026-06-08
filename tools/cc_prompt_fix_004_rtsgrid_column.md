# CC Task: repair 20260605_004_metrics_dedup.sql — remove 4 invalid RTSGrid_Column UPDATEs (42703 blocker)

> RELEASE-CRITICAL for the Full PG18 Server-234 in-place upgrade. 20260605_004_metrics_dedup.sql contains 4
> statements `UPDATE "RTSGrid_Column" SET "MetricId" = ... WHERE "MetricId" = ...`. RTSGrid_Column has NO
> "MetricId" column (schema: ColumnId, GridId, ColumnNumber, CellTemplateId only) -> Postgres raises 42703
> (column does not exist) -> ON_ERROR_STOP halts mid DB-phase on 234. The grid->metric reference lives in
> RTSGrid_Cell."Value" (already remapped by the paired RTSGrid_Cell UPDATEs in the same migration). RTSGrid_Column
> does NOT reference a metric at all -> the 4 lines are simply wrong and must be REMOVED.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (RTSGrid_Cell.Value vs Column model, dedup)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has FREEZE ACTIVE content -> STOP.

## Claims (file-mode, metrics-2-0607)
- db: db/migrations/20260605_004_metrics_dedup.sql
> coord_check_claims FIRST. Touch ONLY this file.

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug + claim).

## The repair — DELETE exactly these 4 lines (the RTSGrid_Column UPDATEs), KEEP their paired RTSGrid_Cell lines:
Remove:
```
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueueNumAnsweredCallbacks'    WHERE "MetricId" = 'QueueNumAcceptedCallbacks';
UPDATE "RTSGrid_Column" SET "MetricId" = 'UsersSumOnCall'               WHERE "MetricId" = 'QueueNumOnCallAgents';
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueueLoginDataNumLoggedUsers' WHERE "MetricId" = 'QueueNumberOfLoggedAgents';
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueuePctAnsweredCalls60secInc' WHERE "MetricId" = 'QueuePctAnsweredCalls60secIncLast30min';
```
KEEP the 4 `UPDATE "RTSGrid_Cell" SET "Value" = ...` lines (correct remap path) and EVERYTHING ELSE in the file
(DELETE FROM RTSGrid_Metric, sections 3-6, verification block) UNCHANGED.
Optionally add a one-line comment where they were removed, e.g.:
`-- (removed 4 invalid UPDATE RTSGrid_Column SET MetricId — RTSGrid_Column has no MetricId; ref is RTSGrid_Cell.Value)`
Migration stays idempotent. Do NOT add a §38a db_patch_history self-record: this file (20260605_004) sorts BEFORE
20260607_002 which CREATES the ledger table, so a self-record INSERT would hit 42P01 on a fresh name-ordered apply.

## Verify
- `grep -c 'UPDATE "RTSGrid_Column"' db/migrations/20260605_004_metrics_dedup.sql` -> MUST be 0.
- `grep -c 'UPDATE "RTSGrid_Cell"' db/migrations/20260605_004_metrics_dedup.sql` -> MUST be 4 (unchanged).
- File still ends with the verification SELECT block (no truncation).
- (No build; pure SQL migration.) If a local throwaway PG is available, running the file MUST NOT raise 42703.

## Commit
`db: fix 20260605_004 — drop 4 invalid RTSGrid_Column UPDATEs (42703 blocker for 234 release)`
(only db/migrations/20260605_004_metrics_dedup.sql)
S3 lock -> pre-commit-check -> git add (the one file) -> commit -> §0.6 verify ->
`bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` -> sync. No push (rides 234 release barrier).

## Acceptance criteria
1. The 4 `UPDATE "RTSGrid_Column" SET "MetricId"` lines removed; the 4 paired RTSGrid_Cell.Value UPDATEs + all other
   sections intact; migration idempotent; no §38a self-record added.
2. grep counts: RTSGrid_Column UPDATEs = 0, RTSGrid_Cell UPDATEs = 4; verification block present.
3. One db: commit; tree clean (ignore false-M); journal + S4b via wrapper; lock released; no push.
