# CC Task: Fix metrics linter duplicate-detection guard (bugfix)

> Follow-up to c5ced4e/c28e098 (lint_metrics.py). The duplicate check (#5) is effectively disabled
> for the whole catalogue. Verified by metrics-0605 during deliverable review (2026-06-06).

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md   (§6 duplicate methodology)

## Git push
Do NOT run `git push`. Commit only (§37).

## Claims (file-mode, metrics-0605)
- tools: `tools/lint_metrics.py`

## Step 0 — §0.6a integrity block (+ known false-M db/data/02_metrics.sql, db/schema.sql)
Then the sync block from `tools/cc_prompt_sync_block.md`.
**Note:** `tools/lint_metrics.py` working copy was truncated by the mount cache after the last
session (348 vs 367 lines). Restore from HEAD first if short:
`git show HEAD:tools/lint_metrics.py | wc -l` must be 367; if WT differs, `git show HEAD:tools/lint_metrics.py > tools/lint_metrics.py`.

## The bug

In `tools/lint_metrics.py`, the duplicate-detection loop guards with:
```python
if m["metric_id"] and m["default_value"] != "\\N":
```
This checks **column 7 (`default_value`)**, which is `\N` for almost every QM metric, so those rows
are excluded from duplicate detection entirely — the check silently does nothing for the bulk of the
catalogue. (Confirmed: an exact duplicate of `QueueNumAnsweredCalls` was NOT flagged.)

## Fix (Python+fsync, §0.3 — Edit BANNED)

Replace the guard so duplicate detection runs for ALL real metric rows, only skipping rows with an
empty/`\N` MetricParameter is NOT correct either (status/identity functions legitimately share empty
params). Correct approach: include every row with a non-empty `metric_id`; rely on the existing
`(MetricFunction, canonical_param, bag)` key — identity/login functions with empty params and the
SAME function would then be compared, which is the desired behaviour (two `LogedInUsersCount` with
empty param ARE the QueueNumberOfLoggedAgents-style duplicate we want to catch).

```python
# was: if m["metric_id"] and m["default_value"] != "\\N":
if m["metric_id"]:
```

If this produces false positives on legitimately-distinct identity metrics (e.g. several `User*`
static attributes that share an empty param but differ by MetricFunction — they WON'T collide because
MetricFunction is part of the key), leave as-is. Do NOT weaken the key.

## Verify
1. `python3 tools/lint_metrics.py` on the live catalogue → **still 1 error** (only the known
   CurLoginTimeStamp defect), **0 duplicate errors** (catalogue is clean post-migration 004).
2. Inject an exact duplicate of `QueueNumAnsweredCalls` under id `ZZDup` inside the COPY block of a
   temp copy → linter MUST report a `Duplicate key` error for both `ZZDup` and `QueueNumAnsweredCalls`.
3. `python3 tools/lint_metrics.py --ignore-known` → 0 errors on the clean catalogue.

## Commit
`fix: lint_metrics.py — duplicate check guarded on default_value instead of metric_id (dup detection was disabled)`
pre-commit-check → §0.6 verify → journal → release lock → PD-007 re-sync. No push.

## Acceptance criteria
1. Duplicate of an existing metric is now flagged; clean catalogue still passes (only known defect).
2. One `fix:` commit; working tree clean (ignore known false-M); journal line; lock released; no push.
