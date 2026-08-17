# CC TASK — PUSH BARRIER v3: b03b870 (EDIT-500) + reconcile -> origin/v3
## Git push: ALLOWED in THIS prompt ONLY (designated barrier push, quorum COMPLETE). Push to **v3** ONLY.

> Quorum GREEN: QA(test-5-0607) + Security(security-0620) + TechWriter(techwriter-0610) all READY (barrier 2026-07-04T11:51Z).
> The 3 commits are ALREADY COMMITTED. This is a plain fast-forward push.
> ⛔ NO new commits. NO `git add` (any form). NO Export-All. NO push to v2. NO force. NO rebase.
> (The stale tools/cc_prompt_push.md is SUPERSEDED — do NOT run it: it targets v2 + runs Export-All + broad-adds.)

## Step 0 — preflight (MANDATORY, L-SC-29; ABORT on any mismatch)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD          # MUST print: v3
git rev-parse HEAD                        # MUST start: 26d6d9e
git rev-parse origin/v3                   # MUST start: 1b5778a
git merge-base --is-ancestor origin/v3 HEAD && echo "FF-OK" || { echo "NOT-FAST-FORWARD -> ABORT"; exit 1; }
echo "--- exactly these 3 unpushed, no more ---"
git log --oneline origin/v3..HEAD         # MUST be exactly: 26d6d9e, b03b870, 6945fc0
test -s .coord/locks/commit.lock && { echo "commit.lock held -> ABORT"; exit 1; } || echo "no commit.lock"
```
If branch != v3, or HEAD != 26d6d9e, or the 3 commits are not EXACTLY (26d6d9e / b03b870 / 6945fc0), or not fast-forward -> STOP, report, do NOT push.

## Step 1 — PUSH (v3 only)
```bash
git fetch origin v3
git rev-parse origin/v3   # re-confirm STILL 1b5778a (nobody else pushed); if changed -> STOP + report
git push origin v3
```
If rejected (origin moved): STOP + report. Do NOT force, do NOT blind-rebase.

## Step 2 — post-push verify
```bash
git rev-parse origin/v3   # MUST now == local HEAD 26d6d9e
git log --oneline -3 origin/v3
git status --short        # working tree unchanged; untracked (staging/regen234, Installations, cache) NOT pushed = expected/correct
```

## Step 3 — journal PUSHED line + re-sync
```bash
python3 - <<'PY'
import datetime
line = datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%MZ') + " | coordinator-0703 | PUSHED 1b5778a..26d6d9e (3 commits: b03b870 EDIT-500 + reconcile plan + efmig baseline)\n"
open(".coord/journal.md","a",encoding="utf-8").write(line)
print("journal appended")
PY
sync
git log --oneline -3
```
Report back: `git rev-parse origin/v3` + `git log --oneline -3 origin/v3` + `git status --short`.

## DO NOT
- NO `git add` / `git add -A` / `git add -f`. NO new commit. NO Export-All.ps1. NO push to `v2`. NO `--force`. NO rebase without coordinator. Touch ONLY the push of the existing HEAD to origin/v3.
