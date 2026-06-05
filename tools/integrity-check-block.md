# Mandatory Integrity Check — paste at TOP of every CC prompt

```bash
# MANDATORY INTEGRITY CHECK (§0.6a) — run before anything else
cd "D:\Claude\Projects\RTM View Shell"
echo "=== Integrity check ===" && git status --short
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        echo "TRUNCATED: $f (HEAD=$H, wt=$W) — RESTORING"
        git show HEAD:"$f" > "$f"
    fi
done
sync && echo "=== Integrity check done ==="
```
