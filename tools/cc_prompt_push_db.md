# CC Task: Export DB state and push — DB ONLY

## Scope
This prompt touches ONLY files under `db/`. No RTM, no Shell, no docs, no tools.
Any other pending changes are ignored and left for cc_prompt_push.md.

## Git push
Push IS allowed — only the db: commit created by Export-All.

---

## Step 1 — Export DB

```powershell
cd "D:\Claude\Projects\RTM View Shell"
powershell -ExecutionPolicy Bypass -File db\tools\Export-All.ps1 `
    -Password "!@#qweASDzxc" `
    -CommitMessage "db: sync DB state"
```

Verify new `db:` commit exists:
```bash
git log --oneline -2
```

---

## Step 2 — Push

```bash
git push origin v2
```

If rejected: `git pull --rebase origin v2 && git push origin v2`

---

## Step 3 — Verify + re-sync

```bash
git log --oneline -3
git status --short

git diff --name-only HEAD~1 HEAD | while read f; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
sync
```

## Important
Do NOT git add or commit any files outside db/.
Do NOT touch src/, RTM/, tools/, docs/, CLAUDE.md, or any other directory.
