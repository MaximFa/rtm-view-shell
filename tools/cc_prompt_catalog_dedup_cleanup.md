# CC Task — (b) catalog-json cleanup: remove 4 dedup metricIds (keep lint green)

> Issued by Cowork session **RTM Metrcs** (slug `metrics-3-0609`, METRICS specialist).
> Coordinator NO-IDLE GO (2026-06-09T16:40Z). Post-release, docs-only, push-independent, NOT in 234 path.
> Sibling to (a). For §4 review before issuing — see OPEN QUESTION below.

## Background
Migration `20260605_004_metrics_dedup.sql` already removed these 4 deprecated-duplicate metrics from
`RTSGrid_Metric` (and re-pointed their `RTSGrid_Cell.Value` refs to canonical):
  QueueNumAcceptedCallbacks, QueueNumOnCallAgents, QueueNumberOfLoggedAgents, QueuePctAnsweredCalls60secIncLast30min
They are GONE from `db/data/02_metrics.sql` but still present in the catalogue JSONs (base + ru + he), both as
their OWN entry (`"metricId": "<id>"`) AND as cross-references in other metrics' entries:
`"duplicate": "<id>"`, `"<id>"` inside related/mirror arrays, and prose `"comparison"` text.

## OPEN QUESTION for §4 (coordinator decide before CC issue)
The dedup ids are documented as "(deprecated) duplicate" of canonical metrics — those cross-refs explain WHY the
canonical exists. Two options:
- **B1 (full remove):** delete the 4 own-entries AND scrub every dangling reference (duplicate field, array
  element). Reword prose `comparison` to past tense ("...was its deprecated duplicate, removed 2026-06-05").
- **B2 (own-entry only):** delete the 4 own-entries, KEEP the explanatory cross-refs as historical notes.
Recommend **B1** (clean catalogue, no dangling pointers to non-existent metrics). Confirm at §4.

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
Claims for this task: `docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json`  (docs module, file-mode)

## Task (assumes B1; adjust if §4 picks B2) — Python+fsync edits (Edit tool BANNED §0.3)
For EACH of the 3 JSON files (base, ru-RU, he-IL):
1. Parse with `json.load`. Locate and REMOVE the 4 objects whose `metricId` ∈ the 4 dedup ids.
2. Scrub dangling references in the REMAINING objects:
   - any field equal to a removed id (e.g. `"duplicate"`) → drop the field (or set per §4 decision);
   - any list element equal to a removed id (related/mirror arrays) → remove the element;
   - prose strings mentioning a removed id (`comparison` etc.) → reword to past tense (B1) or leave (B2).
3. Write back with stable key order / 2-space indent matching the existing file style; fsync.
Use a throwaway `/tmp/metrics-3-0609_catalog.py`. Verify each file still parses:
```bash
for f in docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json; do python3 -c "import json,sys; json.load(open('$f')); print('OK',$f)" 2>&1 || echo "PARSE FAIL $f"; done
grep -rn "QueueNumAcceptedCallbacks\|QueueNumOnCallAgents\|QueueNumberOfLoggedAgents\|QueuePctAnsweredCalls60secIncLast30min" docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json || echo "  no dedup-id refs remain ✓"
```

## Lint must stay GREEN (gate)
```bash
python3 tools/lint_metrics.py ; echo "lint exit=$?"   # MUST be exit 0
```
If lint goes non-zero, the edit broke something — restore from HEAD and report; do NOT commit a red lint.

## Commit (under commit.lock, §42.4 + §0.5/§0.6) — ONE commit
Acquire commit.lock (phantom-aware /tmp/acquire_lock.py from the sync block, owner=metrics-3-0609).
While holding it:
```bash
bash tools/pre-commit-check.sh docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json
git add docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json
git commit -m "docs: remove 4 deduped metricIds from catalogue json (base+ru+he); scrub dangling refs (lint green)"
```
If index.lock/HEAD.lock blocks → §0.4 plumbing path (commit-tree + direct ref write) under the SAME lock.
Post-commit §0.6: `git status --short` for the file(s) clean; `git diff HEAD -- docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json` empty; committed line count == working tree.

## S4+S4b — MANDATORY wrapper (NON-SKIPPABLE)
```bash
bash tools/cc_post_commit.sh metrics-3-0609 $(git log -1 --format=%h)
```
It appends the journal line + coordinator flush + releases the lock. **L-SC-04: this wrapper often drops the
journal line / flush through the mount — Cowork (metrics-3-0609) will reconcile against `git log` after.**
If it exits non-zero, the journal/flush did not land — report so Cowork restores them.

## PD-007 — FINAL re-sync from HEAD (counteracts Cowork cache write-back)
```bash
for f in docs/metrics-catalog.json docs/metrics-catalog.ru-RU.json docs/metrics-catalog.he-IL.json; do git show HEAD:"$f" > "$f"; echo "Re-synced: $f"; done
sync
```

## Git push
Do NOT run `git push` (§37). Commit only. Push is requested separately via tools/cc_prompt_push.md.
