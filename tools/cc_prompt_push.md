# Task: Commit and push RTM + Shell changes to origin/v2

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
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "rtm: prod-test fixes — percent format, diag logging, event subscription"
cp /tmp/cc-idx .git/index
```

Adjust the commit message to reflect what actually changed in RTM/.

---

## Step 3 — Commit Shell + Docs changes

Stage and commit src/, tests/, CLAUDE.md, PROJECT_STATUS.md, tools/, .claude/, docs/, deploy/:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/ tests/ CLAUDE.md PROJECT_STATUS.md tools/ .claude/ docs/ deploy/ wireframes/ 2>/dev/null || true
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "web: prod-test fixes — table filter, time format, row reset, nbsp, diaglog"
cp /tmp/cc-idx .git/index
```

Adjust the commit message to reflect what actually changed in src/.

---

## Step 3b — Commit DB changes (if any db/ files modified)

Stage and commit db/:

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add db/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: <describe DB changes>"
cp /tmp/cc-idx .git/index
```

Skip this step if no db/ files were modified.

---

## Step 4 — Post-commit verification (§0.6)

```bash
git status --short
# Expected: empty (no M lines)

git log --oneline -4
```

If any M files remain → re-stage and amend/follow-up commit.

---

## Step 5 — Push

```bash
git push origin v2
```

If rejected (non-fast-forward):
```bash
git pull --rebase origin v2
git push origin v2
```

---

## Step 6 — Re-sync committed files from HEAD (§0.6 PD-007)

```bash
for f in $(git diff HEAD~2 HEAD --name-only 2>/dev/null); do
    git show HEAD:"$f" > "$f" 2>/dev/null && echo "Re-synced: $f"
done
sync
```

---

## Notes
- RTM files: everything under `RTM/`
- Shell files: `src/`, `tests/`, CLAUDE.md, PROJECT_STATUS.md, `tools/`, `.claude/`, `docs/`, `deploy/`, `wireframes/`
- DB files: `db/` (functions, migrations, tools, baseline.sql)
- `staging/*.sql` → RTM commit
- `tools/cc_prompt_*.md` → Shell commit
- Never mix RTM, Shell, and DB in the same commit
