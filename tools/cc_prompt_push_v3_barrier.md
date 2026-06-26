# CC Task — v3 BARRIER PUSH (RTM-REL-2026.06) — push EXACTLY the frozen 23, NO untracked sweep
> Coordinator-authored (IRON #9: PUSH prompts = coordinator). The ONLY task allowed while .coord/push/request.md is FREEZE ACTIVE.
> Quorum VERIFIED by coordinator-0623: security + techwriter + test(QA-GREEN) + bi + dba + devops + shell + backend all READY, valid_for 243e4a4..db9d18e.
> ⚠ Do NOT run tools/cc_prompt_push.md (it does an untracked docs-sweep — would add commits nobody ack'd; this tree has many ?? files). This push creates NO new commits.

## L-SC-29 PREFLIGHT (assert ALL before pushing — STOP on any fail)
```bash
cd "D:\Claude\Projects\RTM View Shell"
# 1. BRANCH must be v3 (NOT v2-backend)
test "$(git rev-parse --abbrev-ref HEAD)" = "v3" || { echo "NOT on v3 — STOP"; exit 1; }
# 2. HEAD + origin must be the frozen endpoints (object-store, not mount status)
test "$(git rev-parse HEAD)" = "db9d18e99170d59e1ab6923d62add644183a887a" || { echo "HEAD != db9d18e — STOP"; exit 1; }
test "$(git rev-parse origin/v3)" = "243e4a4f59f4c50b9cb599398e248d3285c3a6cc" || { echo "origin/v3 moved — STOP/refetch"; exit 1; }
# 3. exactly 23 unpushed
test "$(git rev-list --count origin/v3..HEAD)" = "23" || { echo "count != 23 — set drifted, STOP"; exit 1; }
echo "PREFLIGHT OK: v3, HEAD=db9d18e, origin/v3=243e4a4, 23 commits"
```
NO `git add` anywhere. NO `git commit`. NO Export-All. NO secrets in any command/log. Untracked ?? files are IGNORED (push only sends committed objects — they cannot be pushed without an add+commit, which this task never does).

## Step A — verify barrier + quorum
```bash
cat .coord/push/request.md | grep -q "FREEZE ACTIVE" || { echo "no active freeze — STOP"; exit 1; }
cat .coord/push/ACKS.md            # READY blocks: security, techwriter, test, devops (+ bi/dba/shell/backend in acks/ or relayed)
ls .coord/push/acks/               # owned ack files
```
Coordinator has confirmed quorum (all active sessions READY, valid_for 243e4a4..db9d18e). If any READY is missing/HOLD — STOP.

## Step B — phantom commit.lock guard
```bash
if [ -s .coord/locks/commit.lock ] && grep -q owner .coord/locks/commit.lock 2>/dev/null; then
    echo "REAL LOCK — STOP"; cat .coord/locks/commit.lock; exit 1
fi   # empty/phantom lock is harmless for a push — ignore
```

## Step C — PUSH exactly HEAD (the 23)
```bash
git push origin v3
git rev-list --count origin/v3..HEAD    # MUST now be 0
git rev-parse origin/v3                  # MUST now be db9d18e99170d59e1ab6923d62add644183a887a
```
No add, no commit — HEAD already IS the frozen set. If push rejected (non-fast-forward) — STOP, report (origin moved); do NOT force.

## Step D — barrier cleanup (only after push exit 0 AND 0 unpushed)
```python
# /tmp/coord0623_push_cleanup.py (per-slug name, L-SC-16)
import os, glob, datetime, subprocess
rng = subprocess.check_output(["git","log","origin/v3..HEAD","--oneline"]).decode().strip()
assert rng == "", "still unpushed — do NOT clean barrier"
now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write(f"{now} | coordinator-0623 | PUSHED origin/v3 243e4a4..db9d18e (23 commits) RTM-REL-2026.06 — barrier complete\n")
    f.flush(); os.fsync(f.fileno())
for p in [".coord/push/request.md", ".coord/push/ACKS.md"] + glob.glob(".coord/push/acks/*.md"):
    try: os.remove(p)
    except OSError:
        try:
            with open(p,"w") as f: f.write("")   # neutralise (content-based checks treat empty as absent)
            print("neutralised:", p)
        except OSError: print("could not clear:", p)
print("barrier cleaned")
```
Then `sync`.

## Report (chat)
push result (old..new = 243e4a4..db9d18e), `git rev-list --count origin/v3..HEAD` (must be 0), origin/v3 now = db9d18e, journal PUSHED line, barrier files cleared. NO further pushes.
