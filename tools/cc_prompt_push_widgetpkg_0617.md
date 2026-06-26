# CC Task — PUSH: 20 commits (Shell widget pkg + backfill + spine) -> origin/v2-backend
> Authored by coordinator-0612 2026-06-17T14:48Z. Quorum 5/5 READY (coordinator + shell + Security CLEAN + Techwriter READY+doc-debt + metrics-3), NO HOLD.
> THE ONLY prompt allowed to `git push` (§37). Native CC only (Cowork mount cannot push, L-SC-20).
> SUPERSEDES all earlier push prompts (L-SC-29 — they target wrong branch / broad-add / Export-All). THIS PUSH STAGES NOTHING (all 20 already committed). NO docs-sweep, NO `git add`, NO Export-All.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md (§42.7 barrier, §0.2 integrity, §0.4 git, L-SC-29 preflight).

## STEP 0 — L-SC-29 preflight (CRITICAL)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD              # MUST print v2-backend (NOT v2 — abort if v2)
git rev-parse --short HEAD                    # expect b58e2c2 (or later if WT re-synced)
git rev-list --count origin/v2-backend..HEAD  # MUST be 20
git rev-parse --short origin/v2-backend        # expect 7ae098a
git log --oneline origin/v2-backend..HEAD | head -25
```
If branch != v2-backend, or count != 20, or origin != 7ae098a -> STOP, report. Do NOT push.

## STEP 0b — clean stale locks (NATIVE rm; metrics-3 flag) — only if truly stale
```bash
# .git/index.lock (0-byte, Jun 16) + a phantom .coord/locks/commit.lock — both stale, no live committer (all cc_task=none).
[ -f .git/index.lock ] && rm -f .git/index.lock && echo "removed index.lock"
[ -f .coord/locks/commit.lock ] && rm -f .coord/locks/commit.lock && echo "removed commit.lock"
git status --short | head   # sanity
```
(If rm fails on the mount path that's fine — you run NATIVE Windows; rm works. Do NOT delete anything else.)

## STEP 1 — integrity (PD-007 defensive; NO staging, NO commit)
Restore from HEAD any committed file whose WT may be truncated/byte-drifted (so nothing wrong is ever staged). Note CLAUDE.md was a benign trailing-newline artifact already restored == HEAD.
```bash
for f in src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor \
         src/CcDashboard.Web/Components/Dashboard/ScreenFullscreenPage.razor \
         src/CcDashboard.Web/wwwroot/js/widget-resize.js \
         src/CcDashboard.Web/wwwroot/app.css \
         src/CcDashboard.Web/Components/Admin/Configuration/MetricsPage.razor \
         CLAUDE.md db/baseline.sql db/data/02_metrics.sql; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f"
done
sync
git status --short | grep -E "^A|^D" && { echo "STRAY STAGED — abort"; exit 1; } || echo "(nothing staged — correct)"
```
(A few ` M` from the restore are content==HEAD; we do NOT stage them. DEFERRED uncommitted files held by metrics-3/others — DO NOT touch/stage.)

## STEP 2 — pre-push verify
```bash
git log --oneline origin/v2-backend..HEAD | wc -l   # MUST be 20
git status --short | grep -E "^A|^D" || echo "(nothing staged — push-only, correct)"
```

## STEP 3 — PUSH (origin/v2-backend ONLY)
```bash
git push origin v2-backend
```
Rejected (remote moved): `git fetch origin` then `git merge-base --is-ancestor origin/v2-backend HEAD && echo FF-OK || echo DIVERGED-STOP`. FF-OK -> retry. DIVERGED -> STOP, report (no blind rebase, NEVER --force, no other branch).

## STEP 4 — verify pushed + re-sync (PD-007)
```bash
git rev-parse origin/v2-backend            # MUST now equal local HEAD (b58e2c2 or later)
git log --oneline -1 origin/v2-backend
for f in $(git show --name-only --pretty="" HEAD); do [ -f "$f" ] && git show HEAD:"$f" > "$f"; done
sync
```

## STEP 5 — clear barrier + journal (after successful push)
```bash
python3 - <<'PY'
import os,datetime
now=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ')
open(".coord/push/request.md","w",encoding="utf-8").write("# CLEARED — PUSHED 7ae098a..b58e2c2 (20 commits) to origin/v2-backend "+now+". Barrier closed, FREEZE lifted.\n")
open(".coord/journal.md","a",encoding="utf-8").write("\n"+now+" | coordinator-0612 | PUSHED origin/v2-backend 7ae098a..b58e2c2 (20 commits: Shell widget UX pkg T1-T6 + marquee + viewer + template + deploy-tab + backfill + Specialist-Protocol spine/cold-starts). Quorum 5/5 (coord+shell+Security CLEAN+Techwriter READY+doc-debt+metrics-3). Barrier closed.\n")
for p in (".coord/push/request.md",".coord/journal.md"):
    fd=os.open(p,os.O_RDONLY); os.fsync(fd); os.close(fd)
print("barrier cleared + journaled")
PY
sync
```

## Report (chat)
- branch v2-backend; pushed range 7ae098a..<newtip>; commit count 20; origin/v2-backend == local HEAD.
- stale locks removed (or noted absent); barrier cleared (request.md tombstone + journal PUSHED). FREEZE lifted.
