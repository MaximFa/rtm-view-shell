# CC Task: Commit 2 missed docs files (prod-test3-0605)

## Git push
Do NOT run `git push`.

---

## Step 0 — Integrity check (§0.6a)

```bash
cd "D:\Claude\Projects\RTM View Shell"
for f in $(git diff --name-only HEAD 2>/dev/null); do
    H=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    W=$(wc -l < "$f" 2>/dev/null)
    if [ "$H" -gt 5 ] && [ "$W" -lt $(( H * 90 / 100 )) ]; then
        git show HEAD:"$f" > "$f" && echo "Restored: $f"
    fi
done && sync
```

---

## Step 1 — Acquire commit.lock (§42.4)

```bash
python3 -c "
import os, datetime
lock = '.coord/locks/commit.lock'
os.makedirs('.coord/locks', exist_ok=True)
if os.path.exists(lock):
    print('LOCK EXISTS:', open(lock).read()); exit(1)
with open(lock, 'x') as f:
    f.write('acquired: ' + datetime.datetime.utcnow().isoformat() + '\nowner: prod-test3-0605\n')
print('Lock acquired')
"
```

---

## Step 2 — Commit two missed docs files

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add \
  docs/RTMViewShell_SecurityOverview.docx \
  docs/daytrendcomparison-plan.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs: SecurityOverview + daytrendcomparison-plan (missed from b2dfe42 push)"
cp /tmp/cc-idx .git/index
git log --oneline -3
```

---

## Step 3 — Append journal (§42.5)

```bash
COMMIT=$(git log --oneline -1 | cut -d' ' -f1)
echo "$(date -u +%Y-%m-%dT%H:%MZ) | prod-test3-0605 | $COMMIT docs: SecurityOverview + daytrendcomparison-plan" \
  >> .coord/journal.md
```

---

## Step 4 — Release commit.lock

```bash
rm .coord/locks/commit.lock && sync
echo "Lock released"
```

---

## Step 5 — Re-sync (§0.6 PD-007)

```bash
for f in "docs/RTMViewShell_SecurityOverview.docx" "docs/daytrendcomparison-plan.md"; do
  [ -f "$f" ] && git show HEAD:"$f" > "$f" && echo "Re-synced: $f"
done && sync
```

Report: commit hash + `git log --oneline -3`.
