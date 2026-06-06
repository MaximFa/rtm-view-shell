# CC Task — barrier push: push EXACTLY the frozen 14 (no untracked sweep)

This is the ONLY task allowed while .coord/push/request.md exists. Quorum is verified
(metrics-0605, daytrend-0606, test4-0606, session-sync-0605 all READY for the 14-commit set).

DECISION (ASK-3): push EXACTLY the frozen set. Do NOT run cc_prompt_push.md's untracked
docs-sweep — it would add commits nobody ack'd. The 14 are already committed in HEAD;
this push creates NO new commits. Stray untracked prompts are handled post-push.

## Step A — Verify quorum + frozen set
```bash
cd "D:\Claude\Projects\RTM View Shell"
cat .coord/push/request.md            # 14 commits, frozen
grep -l READY .coord/push/acks/*.md   # expect 4 files
git log origin/v2..HEAD --oneline | wc -l   # MUST be exactly 14
```
If count != 14 — STOP (set drifted), report.

## Step B — Phantom commit.lock guard (no real lock expected)
```bash
if [ -s .coord/locks/commit.lock ] && cat .coord/locks/commit.lock 2>/dev/null | grep -q owner; then
    echo "REAL LOCK — STOP"; cat .coord/locks/commit.lock; exit 1
fi
# phantom dirent (test -f YES, no content) is harmless for push — ignore it
```

## Step C — Push exactly HEAD (the 14)
```bash
git push origin v2
git log origin/v2..HEAD --oneline | wc -l   # MUST now be 0
```
No git add, no git commit — HEAD already IS the frozen set.

## Step D — Barrier cleanup (after push succeeds, exit 0 and 0 unpushed)
```python
# /tmp/session-sync-0605_cleanup.py  (per-slug name, L-SC-16)
import os, glob, datetime, subprocess
rng = subprocess.check_output(["git","log","origin/v2..HEAD","--oneline"]).decode().strip()
assert rng == "", "still unpushed — do NOT clean barrier"
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | session-sync-0605 | PUSHED 14 commits (7cf83cb..adeebca) barrier complete\n"
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
# remove request.md + acks via temp-replace-safe unlink; if unlink blocked (phantom), truncate to empty marker
for p in [".coord/push/request.md"] + glob.glob(".coord/push/acks/*.md"):
    try: os.remove(p)
    except OSError:
        try:
            with open(p,"w") as f: f.write("")  # neutralise: content-based checks treat empty as absent
            print("neutralised (could not unlink):", p)
        except OSError: print("could not clear:", p)
print("barrier cleaned")
```
Then `sync`.

## Git push
The push IS the task. Do not push anything beyond `origin v2`.

## Report
push result (old..new), `git log origin/v2..HEAD` count (must be 0), journal PUSHED line,
barrier files state, `git status --short` summary.
