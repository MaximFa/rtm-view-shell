# Task: Commit and push all pending changes to origin/v2

## Git push rule
After committing, run `git push origin v2`. This is the dedicated push prompt — push IS allowed here.

---

## Step 0 — Integrity check (§0.2)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

For every `M` file: `tail -3 <path>`. If truncated → restore:
```bash
git show HEAD:<path> > <path>
```

---

## Step 1 — Pre-commit check on ALL modified files (§0.5)

```bash
bash tools/pre-commit-check.sh
```

If exit code 1 → restore truncated files. Do NOT commit until exit code 0.

---

## Step 2 — Commit RTM changes

Stage and commit all files under `RTM/`:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "rtm: prod-test fixes — diag logging flag, percent format, event subscription"
cp /tmp/cc-idx .git/index
```

---

## Step 3 — Commit Shell changes

Stage and commit src/, tests/, wireframes/, deploy/, CLAUDE.md, PROJECT_STATUS.md:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/ tests/ wireframes/ deploy/ CLAUDE.md PROJECT_STATUS.md 2>/dev/null || true
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "web: prod-test fixes — time format, percent, table filter, seeder SITE001, RtmRelay diag"
cp /tmp/cc-idx .git/index
```

---

## Step 4 — Commit DB tools + setup

Stage and commit db/:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add db/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: add Export-All, Restore-All, Create-FreshDb, setup scripts"
cp /tmp/cc-idx .git/index
```

---

## Step 5 — Commit tools/, docs/, testing/, misc

Stage everything else (cc_prompt_*.md, fix_*.py, docs/, testing/, etc.):

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/ docs/ testing/ .claude/ 2>/dev/null || true
GIT_INDEX_FILE=/tmp/cc-idx git add INSTALL-SIMULATOR.md Installations/ 2>/dev/null || true
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: cc prompts, fix scripts, documentation, testing artifacts"
cp /tmp/cc-idx .git/index
```

---

## Step 6 — Post-commit verification (§0.6)

```bash
git status --short
# Expected: empty or only untracked (??) lines, no M lines

git log --oneline -6
```

If any M files remain → re-stage and create follow-up commit.

---

## Step 7 — Push

```bash
git push origin v2
```

If rejected (non-fast-forward):
```bash
git pull --rebase origin v2
git push origin v2
```

---

## Step 8 — Re-sync committed files from HEAD (§0.6 PD-007)

```bash
git diff --name-only HEAD~5 HEAD | while read f; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
sync
```

Report final `git log --oneline -6` and `git status --short`.
