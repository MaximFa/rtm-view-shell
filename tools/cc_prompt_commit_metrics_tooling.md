# CC Task: commit metrics-0605 untracked tooling artefacts (docs:)

> Small housekeeping commit. metrics-0605 produced reusable CC-prompt artefacts + one handoff tsv
> that are untracked and have been deferred across two barriers. Commit them now (barrier clear).

## Mandatory
Read file: .claude/skills/session-coord/session-coord.md
## Git push: NONE (§37). Commit only.

## Step 0 — §0.6a integrity + sync (§42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin 2>&1 | tail -1
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/v2)" && echo "IN SYNC" || echo "DIVERGED-reconcile"
git status --short
```
Then the coord sync block (slug metrics-0605; phantom-aware S3; barrier S1 hard-stop).

## Claim (file-mode, metrics-0605): the 6 files below only.

## Action — commit-lock (§42.4), single docs: commit
Stage EXACTLY these (they are untracked working artefacts of metrics-0605):
```bash
GIT_INDEX_FILE=/tmp/cc-idx git add \
  tools/cc_prompt_metric_change.md \
  tools/cc_prompt_metric_wizard_w1.md \
  tools/cc_prompt_metrics_catalog_fields.md \
  tools/cc_prompt_metrics_d3b_page.md \
  tools/cc_prompt_metrics_lint_fix.md \
  tools/metric_longdesc_catalogtype.tsv
```
Commit message:
`docs: metrics CC-prompt artefacts + catalogue longdesc tsv (D3/wizard tooling)`
Then: pre-commit-check (these are .md/.tsv, size-only) → §0.6 post-commit verify → journal line →
S4b post-commit flush to coordinator.md → release lock → PD-007 re-sync. NO push.

## Acceptance
1. One docs: commit containing exactly the 6 files.
2. `git status --short` shows none of the 6 as `??` afterwards.
3. Journal + S4b flush done; lock released; no push.
