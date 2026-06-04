# CC Task: Export DB state to git + push all pending changes

## Step 1 — Export DB to git

```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
    -Password "!@#qweASDzxc" `
    -CommitMessage "db: fix metric typos — add QueueNumAbandonedCalls and QueueNumAbandonedCallbacks aliases"
```

Expected: Export-All.ps1 regenerates db/data/02_metrics.sql and commits.
Verify: `git log --oneline -2` must show a new `db:` commit.

---

## Step 2 — Integrity check (§0.2)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

For every `M` file: `tail -3 <path>` — check for truncation.
Restore if truncated: `git show HEAD:<path> > <path>`

---

## Step 3 — Pre-commit check on remaining changes (§0.5)

```bash
bash tools/pre-commit-check.sh
```

Only if exit code 0: proceed.

---

## Step 4 — Commit RTM changes (if any M files under RTM/)

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add RTM/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "rtm: prod-test2 fixes — connection race, refreshCells void fix"
cp /tmp/cc-idx .git/index
```

---

## Step 5 — Commit Shell changes (if any M files under src/)

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add src/ tools/ .claude/
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "web: DataSlot BU fix, GridId sync, connection race fix; tools: cc prompts"
cp /tmp/cc-idx .git/index
```

---

## Step 6 — Post-commit verification (§0.6)

```bash
git status --short   # must be empty or only ??
git log --oneline -6
```

---

## Step 7 — Push

```bash
git push origin v2
```

If rejected: `git pull --rebase origin v2 && git push origin v2`

---

## Git push
Push IS allowed in this prompt (это промпт для push).

---

## Step 8 — Re-sync (§0.6 PD-007)

```bash
git diff --name-only HEAD~3 HEAD | while read f; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
sync
```

Report final `git log --oneline -5` and `git status --short`.
