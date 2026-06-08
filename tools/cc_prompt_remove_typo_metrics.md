# CC Task — fix typo metrics (rename QueueNumAbandonef* → canonical) durable in git

> Issued by Cowork session **RTM DevOps** (slug `devops-0606`). Coordinator-assigned,
> operator-approved (operator chose RENAME over delete-only, 2026-06-06).
>
> WHY rename (not delete): the canonical `QueueNumAbandonedCalls` / `QueueNumAbandonedCallbacks`
> are ABSENT from both the seeder and baseline.sql — only the typo'd `QueueNumAbandonef*` exist.
> The Calc metrics `QueuePctAbandonedCallsTotal` / `QueuePctAbandonedCallbacksTotal`
> (DatabaseInitializer.cs ~470/471) reference the CANONICAL ids. So deleting the typos alone
> would leave fresh installs with broken Calc refs. Renaming typo→canonical removes the typo
> AND supplies the canonical base — it is the durable form of the live-DB end state
> (operator deleted typos on prod; migration 20260605_001 / staging/patch_abandoned_metrics.sql
> added the canonical). Verified: NOTHING references the typo id (`Abandonef` appears ONLY at the
> two seeder lines + two baseline lines), so the rename is safe.
>
> OUT OF SCOPE: catalogue (D3a) fields for the renamed metrics — those come from the backfill,
> not the seeder. Do not add catalogue columns here.

---

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST

```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q
git rev-parse HEAD; git rev-parse origin/v2     # expect equal (origin/v2==HEAD==85279d0 after last push)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== Integrity check complete ==="
```

---

## Mandatory — read before starting (§40)

```
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
```
Only after reading all three: proceed.

---

## Multi-session sync — MANDATORY (§42, skill v1.4)

Session slug: `devops-0606`
Claims (touch ONLY these, plus /tmp/devops-0606_*.py throwaway — L-SC-16):
- `src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs`   (web — string rename only)
- `db/baseline.sql`                                                (db — MetricId rename only)

### S1. Push barrier check — before ANY work (content-based, L-SC-10)
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py devops-0606 \
    src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs db/baseline.sql
# exit 1 -> STOP: another active session holds a path. Report to operator.
```
Modify ONLY those 2 files (plus /tmp throwaways). Anything else → STOP.

---

## Task — rename in two files (Python+fsync; Edit tool BANNED §0.3)

Replacement is unambiguous: `QueueNumAbandonef` occurs ONLY in these 2 metric ids, in exactly
these 4 locations. Replace the longer id first, then the shorter (defensive).

```python
# /tmp/devops-0606_rename.py
import os
EDITS = [
    "src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs",
    "db/baseline.sql",
]
PAIRS = [
    ("QueueNumAbandonefCallbacks", "QueueNumAbandonedCallbacks"),
    ("QueueNumAbandonefCalls",     "QueueNumAbandonedCalls"),
]
for path in EDITS:
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()
    before = text
    n = 0
    for old, new in PAIRS:
        c = text.count(old)
        text = text.replace(old, new)
        n += c
    assert text != before, f"NO CHANGE in {path} — investigate, do not commit"
    assert "QueueNumAbandonef" not in text, f"typo still present in {path}"
    with open(path, "w", encoding="utf-8") as f:
        f.write(text); f.flush(); os.fsync(f.fileno())
    print(f"{path}: {n} replacement(s)")
```

```bash
python3 /tmp/devops-0606_rename.py && sync
# verify: expect 2 hits in seeder (419/420), 2 in baseline (68/69); zero typo remaining
grep -n "QueueNumAbandonedCalls\b\|QueueNumAbandonedCallbacks\b" src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs | grep -v "AndCallbacks"
grep -nE '^QueueNumAbandonedCalls\b|^QueueNumAbandonedCallbacks\b' db/baseline.sql
echo "typo remaining (must be empty):"; grep -rn "Abandonef" src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs db/baseline.sql || echo "  none ✓"
# truncation guard on the C# file (largest edit):
tail -3 src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs
wc -l src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs   # compare to HEAD line count
```

Sanity build (string-literal change — must still compile):
```bash
dotnet build src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj -c Debug --nologo 2>&1 | tail -5
```

---

## Commit — TWO commits under the lock (web: then db:), §42.4 + §0.5/§0.6

Acquire the commit lock ONCE (phantom-aware), do both commits, release once.

```python
# /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
def real_lock():
    try:
        with open(lock) as f: return f.read().strip() != ""
    except OSError: return False
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: devops-0606\nacquired: " + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        if not real_lock():
            print("PHANTOM lock — clearing")
            try: os.remove(lock)
            except OSError: print("  cannot unlink this side")
            time.sleep(2); continue
        print("BUSY (real): " + open(lock).read().strip()); time.sleep(60)
print("FAILED to acquire commit lock"); sys.exit(1)
```

While holding the lock:
```bash
bash tools/pre-commit-check.sh src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs db/baseline.sql
# if exit 1: restore truncated file (git show HEAD:<f> > <f>), redo Python write, re-check.

# Commit 1 — web:
git add src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs
git commit -m "web: rename seeder typo metric QueueNumAbandonef{Calls,Callbacks} -> canonical (fixes broken Calc refs on fresh install)"
# Commit 2 — db:
git add db/baseline.sql
git commit -m "db: rename baseline typo metric QueueNumAbandonef{Calls,Callbacks} -> canonical"
```
If `git commit` hits index.lock/HEAD.lock → use §0.4 plumbing path (commit-tree + direct ref
write), still under the same commit.lock.

Post-commit (§0.6): `git status --short` for the 2 files clean; `git diff HEAD -- <each>` empty;
committed line count == working tree.

Journal both commits, then release the lock:
```python
# /tmp/journal2_release.py
import os, datetime, subprocess
for h in subprocess.check_output(["git","log","-2","--format=%h %s"]).decode().strip().split("\n")[::-1]:
    line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | devops-0606 | " + h + "\n"
    with open(".coord/journal.md","a",encoding="utf-8") as f:
        f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal x2 appended, lock released")
```
Then `sync`. If commits abort, still release the lock.

### S4b. Post-commit flush — to coordinator (REQUIRED)
```python
# /tmp/devops-0606_flush.py
import os, datetime, subprocess
hs = subprocess.check_output(["git","log","-2","--format=%h %s"]).decode().strip().replace("\n","; ")
block = ("## " + datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
    + " | from: devops-0606 | to: coordinator\n"
    "COMMIT " + hs + "\n"
    "claims-releasable: src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs, db/baseline.sql\n"
    "blocker/question: none\n"
    "next: awaiting operator — typo rename durable (web+db); no push (§37)\n---\n")
with open(".coord/inbox/coordinator.md","a",encoding="utf-8") as f:
    f.write(block); f.flush(); os.fsync(f.fileno())
print("flush written")
```
Then `sync`. Remove both files from `files:` in the session file.

### PD-007 — FINAL re-sync from HEAD (counteracts Cowork cache write-back)
```bash
for f in src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs db/baseline.sql; do
    git show HEAD:"$f" > "$f"; echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```

### S5. Git push
Do NOT run `git push` (§37). Push happens only via `tools/cc_prompt_push.md`.

## Report back to operator
- replacement counts per file (expect 2 + 2), typo-remaining grep empty,
- build result, both commit hashes,
- confirm working tree clean for the 2 files.
