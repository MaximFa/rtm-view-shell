# CC Task: git reset --hard to f9b2dc4

## Git push
Do NOT run `git push`. Commit only.

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

## Task: Roll back to f9b2dc4

```bash
cd "D:\Claude\Projects\RTM View Shell"
git reset --hard f9b2dc4
```

Verify:
```bash
git log --oneline -3
git status --short
```

Expected:
- HEAD = f9b2dc4 (fix: DayTrend modal — restore CSS + flat layout)
- No uncommitted changes

---

## After reset — re-sync working tree

```bash
git diff --name-only HEAD~3 HEAD | while read f; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done
sync
```

Report: `git log --oneline -3` and `git status --short`.
