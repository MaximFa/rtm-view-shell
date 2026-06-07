# CC Task — daytrend-2 ACK CLEANUP: commit 3 untracked artefacts (barrier hygiene)

Session: daytrend-2-0607
Context: PUSH BARRIER ACTIVE (round 2026-06-07T13:01Z). The ack checklist (item 3) requires committing my
untracked artefacts NOW under commit.lock BEFORE I write READY (L-SC-05: untracked artefacts get lost in the
push otherwise). This is sanctioned barrier hygiene — NOT new work — so DO NOT S1-stop on request.md here.
ONE small docs: commit, then done. NO push.

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all three: proceed.

## Step 0 — INTEGRITY (§0.6a) + fetch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
# restore truncated M; SKIP known false-M/binary:
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  case "$f" in db/data/02_metrics.sql|db/schema.sql|docs/RTMViewShell_SecurityOverview.docx) echo "SKIP: $f"; continue;; esac
  HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; fi
done
sync
```

## Barrier note (NO S1-stop)
This task is the ack-cleanup mandated by request.md item 3 — proceed even though request.md is present.
Touch ONLY the 3 files below (+ /tmp/daytrend-2-0607_*). Edit tool BANNED (§0.3): these are pre-written, just `git add`.

## S3 — acquire commit.lock (phantom-aware, retry 5x60s)
Use the /tmp acquire_lock.py pattern from tools/cc_prompt_sync_block.md (owner=daytrend-2-0607).
If a real lock is held: STOP, report owner. If phantom (empty/unreadable): clear + retry.

## Commit (under commit.lock)
```bash
cd "D:\Claude\Projects\RTM View Shell"
bash tools/pre-commit-check.sh tools/cc_prompt_p3_harness_dev.md tools/cc_prompt_fix_engine_unionlist_guard.md tools/cc_prompt_daytrend2_ack_cleanup.md staging/verify_p3_daytrend_fn.sql
git add tools/cc_prompt_p3_harness_dev.md tools/cc_prompt_fix_engine_unionlist_guard.md tools/cc_prompt_daytrend2_ack_cleanup.md staging/verify_p3_daytrend_fn.sql
git commit -m "docs: daytrend-2 ack cleanup — version P3 dev harness + P3/Engine-guard CC prompts (barrier hygiene, L-SC-05)"
```
Then §0.6 post-commit verify (git status clean for these 3; git diff HEAD -- them empty), then the LAST step:
```bash
bash tools/cc_post_commit.sh daytrend-2-0607 $(git log -1 --format=%h)
```
(journal + S4b flush + lock release, exit-gated). PD-007 re-sync the 3 files from HEAD after.

## NO push (§37). Report the commit hash so I can write READY.
