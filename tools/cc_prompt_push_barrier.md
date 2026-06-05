# CC Task — barrier push: verify quorum, clean orphan lock, push, cleanup (§42.7)

This is the ONLY task type allowed while .coord/push/request.md exists.

## Step A — Verify barrier and quorum

```bash
cd "D:\Claude\Projects\RTM View Shell"
cat .coord/push/request.md            # must exist; frozen set = 6 commits
grep -H . .coord/push/acks/*.md | grep READY
# Required: READY in all three: metrics-0605, prod-test3-0605, session-sync-0605
git log origin/v2..HEAD --oneline     # must equal the 6 commits from request.md
```

If any ack is missing/HOLD, or the commit set differs from request.md — STOP, report.

## Step B — Remove orphaned commit.lock (owner check)

```bash
cat .coord/locks/commit.lock
# Expected owner: prod-test3-0605 (work complete, release failed on mount side)
rm .coord/locks/commit.lock && echo "orphan lock removed"
# If owner differs — STOP, report.
```

## Step C — Execute the push

Run the full task from `tools/cc_prompt_push.md` (including its Step 1b untracked
pickup — expect NOTHING new: barrier checklist already committed all artefacts;
if Step 1b finds relevant untracked files, list them in the report).
Push branch v2 to origin.

## Step D — Barrier cleanup (after successful push only)

```python
# /tmp/cleanup.py
import os, glob, datetime, subprocess
rng = subprocess.check_output(["git","log","origin/v2..HEAD","--oneline"]).decode().strip()
ok = (rng == "")  # after push, nothing should remain unpushed
line = (datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
        + " | session-sync-0605 | PUSHED 6 commits (0c03fd1..b6d0caa) barrier complete\n")
with open(".coord/journal.md", "a", encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/push/request.md")
for a in glob.glob(".coord/push/acks/*.md"):
    os.remove(a)
print("barrier cleaned, unpushed-empty:", ok)
```

Then `sync`.

## Report
push result (old..new hashes), Step 1b findings, lock removal confirmation,
cleanup confirmation, `git status --short` summary.
