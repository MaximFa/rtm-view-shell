# CC Task: Full push — commit pending docs/skills + export DB + push all

## Git push
Push IS allowed in this prompt.

---

## Step 0 — Mandatory integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f — restoring"; git show HEAD:"$f" > "$f"
    fi
done && sync && echo "=== Integrity OK ==="
```

---

## Step 1 — Commit pending docs/skills/tools changes

These files were modified by Cowork (documentation only — allowed per §0.7):

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  .claude/skills/widget-planner/widget-planner.md \
  .claude/skills/widget-creator/widget-creator.md \
  .claude/skills/qa-expert/ \
  CLAUDE.md \
  docs/daytrendcomparison-plan.md \
  docs/RTMViewShell_SecurityOverview.docx \
  docs/security-overview.docx \
  tools/cc_prompt_fix_daytrand_ux.md \
  tools/cc_prompt_fix_header_icon.md \
  tools/cc_prompt_fix_localization.md \
  tools/cc_prompt_fix_logout.md \
  tools/cc_prompt_fix_modal_flat.md \
  tools/cc_prompt_fix_modal_overlay.md \
  tools/cc_prompt_fix_tests.md \
  tools/cc_prompt_metric_colors.md \
  tools/cc_prompt_more_tests.md \
  tools/cc_prompt_run_tests.md \
  tools/cc_prompt_uws17.md \
  tools/cc_prompt_user_widget_settings.md \
  tools/cc_prompt_viewconfig_tabs.md \
  tools/integrity-check-block.md \
  tools/Build-ProdRelease.ps1 \
  2>/dev/null || true

GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: widget-planner L-36..L-38, qa-expert skill, CLAUDE.md §0.6a/§41, security overview, cc prompts, prod-release integrity check"
cp /tmp/cc-idx .git/index
git log --oneline -2
```

---

## Step 1b — Add untracked files in docs/tools/db/.claude (often missed)

```bash
# Force-add skills (blocked by .gitignore .claude/ rule)
git add -f .claude/skills/ 2>/dev/null || true

# Add untracked docs, tools CC prompts, db migrations
git add docs/ tools/cc_prompt_*.md tools/fix_*.py tools/integrity-check-block.md         db/migrations/ 2>/dev/null || true

# Check what's still untracked
git status --short | grep "^??" | grep -v "node_modules\|Installations\|\.sync\|\.docx\|\.skill\|The\|bash\|file\|have\|in\|its\|line\|original\|user\|will\|working\|your\|endings\|directory\|build_"
```

If any relevant `??` files remain — add them explicitly before committing.

If anything was staged — commit:
```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git diff --cached --name-only
# Only if non-empty:
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: untracked skills, prompts, docs caught by push step"
cp /tmp/cc-idx .git/index
```

---

## Step 2 — Export DB to git (Export-All.ps1)

```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
    -Password "!@#qweASDzxc" `
    -CommitMessage "db: export after UserWidgetSettings migration + metrics dedup"
```

Verify new `db:` commit:
```bash
git log --oneline -2
```

---

## Step 3 — Post-commit integrity check

```bash
git status --short
# Must be empty or only ?? untracked
git log --oneline -5
```

---

## Step 4 — Push all

```bash
git push origin v2
```

If rejected: `git pull --rebase origin v2 && git push origin v2`

---

## Step 5 — Re-sync (§0.6 PD-007)

```bash
git diff --name-only HEAD~3 HEAD | while read f; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
sync
```

Report: `git log --oneline -5` and `git status --short`.
