# CC Task: Linter — JSON ↔ catalogue coverage gate

> Extends tools/lint_metrics.py so every metric in the DB export has a catalogue card, and vice
> versa. This is the gate that makes "JSON source of truth" safe: a metric can no longer be added
> without a catalogue entry. Source: RTM Metrics session design decision (read-only page + repo-driven).

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (§5 description layers, §8 catalog.json schema)

## Git push
Do NOT run `git push`. Commit only (§37).

## Claims (file-mode, metrics-0605)
- tools: `tools/lint_metrics.py`

## Step 0 — §0.6a integrity block (+ known false-M: db/data/02_metrics.sql, db/schema.sql)
Then the coord sync block from `tools/cc_prompt_sync_block.md` (running slug + the claim above).
**PD-007 note:** tools/lint_metrics.py is repeatedly truncated by the mount cache. Verify
`git show HEAD:tools/lint_metrics.py | wc -l` (currently 374) == `wc -l < tools/lint_metrics.py`;
if WT is shorter, `git show HEAD:tools/lint_metrics.py > tools/lint_metrics.py` BEFORE editing.

## What to add (Python+fsync, §0.3 — Edit BANNED)

A new check method `check_catalogue_coverage()` run ONCE after the per-row loop (it is a set
comparison, not per-row). It loads `docs/metrics-catalog.json` and compares MetricId sets:

1. Parse `--catalog` path (default `docs/metrics-catalog.json`). Read `metrics[]`, build
   `catalog_ids = {m["metricId"] for m in metrics}` and an index by id.
2. `sql_ids` = the MetricIds parsed from the COPY block (already available).
3. **ERROR** for every id in `sql_ids - catalog_ids` — "metric in DB export has no catalogue card".
4. **ERROR** for every id in `catalog_ids - sql_ids` UNLESS the catalogue entry's `status` is in
   {duplicate, deprecated} (those are intentionally retired and may linger as reference) — then WARNING.
5. **WARNING** for every live metric whose catalogue entry is missing a rich card, i.e.
   `longDescription` empty/null OR `shortDescription` empty/null — "metric lacks rich catalogue card
   (candidate for authoring)". This does NOT fail the build — it surfaces the backlog.
6. Respect the existing `--ignore-known` flag: under it, coverage ERRORs for the KNOWN-defect ids
   (the same skip-list already used for the CurLoginTimeStamp case) stay WARNINGs.

Add `--catalog` to argparse. Keep all existing checks intact. Update the module docstring to mention
coverage. Update the final summary line (already `N errors, M warnings`).

## Verify
1. `python3 tools/lint_metrics.py` on the live repo:
   - coverage clean (catalogue was generated from the same 198 metrics) — coverage adds 0 new ERRORS;
   - it MAY add WARNINGs for any metric lacking longDescription — that is expected/acceptable.
   - overall still exits 1 ONLY because of the known CurLoginTimeStamp defect; `--ignore-known` → exit 0.
2. Negative test (temp copies, do NOT commit): remove one metric's entry from a COPY of
   metrics-catalog.json → coverage ERROR for that id. Add a bogus id to a COPY of 02_metrics.sql →
   coverage ERROR. Revert.

## Commit
`fix: lint_metrics.py — add JSON<->catalogue coverage gate (no metric without a card)`
pre-commit-check → §0.6 verify → journal → release lock → PD-007 re-sync. No push.

## Acceptance criteria
1. Coverage check present and run once (set comparison, not per-row).
2. Live repo: 0 new coverage ERRORs; `--ignore-known` exits 0; missing-rich-card surfaces as WARNING only.
3. Negative tests both produce a coverage ERROR.
4. One `fix:` commit; tree clean (ignore known false-M); journal line; lock released; no push.
