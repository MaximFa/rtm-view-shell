# CC Task — PUSH: today's 8 commits -> origin/v2-backend (quorum COMPLETE)
> Authored by coordinator-0612 2026-06-15T03:57Z. Quorum 3/3: coordinator READY + Security READY (CLEAN) + Techwriter READY+doc-debt.
> Excluded (operator-confirmed not-live, work committed): dba/backend/shell/test-5/curator/daytrend.
> THE ONLY prompt allowed to `git push` (§37). Native CC only (Cowork mount cannot push, L-SC-20).
> SUPERSEDES stale cc_prompt_push_45green.md (yesterday's 22-commit barrier) and cc_prompt_push.md (wrong branch v2 + broad-add + Export-All). DO NOT use those (L-SC-29).
> THIS PUSH STAGES NOTHING — all 8 commits are already committed. NO docs-sweep, NO `git add`, NO Export-All. Just verify + push.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md (§42.7 barrier, §0.2 integrity, §0.4 git workarounds)

## STEP 0 — L-SC-29 preflight (CRITICAL)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD          # MUST print: v2-backend  (NOT v2 — abort if v2)
git rev-parse --short HEAD                # expect 7ae098a (or later if WT re-synced)
git rev-list --count origin/v2-backend..HEAD   # expect 8
git log --oneline origin/v2-backend..HEAD       # the 8: 7ae098a 6d3754c af9caeb 33a842e af8d89a 01d4db6 c1f66af b618a14
```
If branch != v2-backend, or count != 8, or the list differs -> STOP, report to coordinator. Do NOT push.

## STEP 1 — integrity (PD-007 defensive; NO staging, NO commit)
Restore from HEAD any committed file whose WT may be truncated, so a later session never re-stages junk. (We do NOT commit here.)
```bash
for f in db/migrations/20260613_011_45_table_drift_addcolumns.sql \
         db/migrations/20260613_013_sgag_unique_constraint.sql \
         db/migrations/20260613_014_schema_reconcile.sql \
         db/migrations/20260613_015_ngc_createsupergroup_overloads.sql \
         db/schema.sql db/tools/Compare-ToBaseline.ps1 db/tools/Regen-Schema.ps1 \
         db/tools/Restore-All.ps1 db/setup/02_catowner_role.sql deploy/Update-RTMView.ps1 \
         deploy/Apply-Server45Upgrade.ps1 src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs; do
    [ -f "$f" ] && git show HEAD:"$f" > "$f"
done
sync
git status --short | grep -E "^A|^D|^M " || echo "(no staged adds/deletes/mods — clean, good)"
```
(A few ` M` from the restore are fine — they equal HEAD content. We are NOT staging them.)

## STEP 2 — pre-push verify (NO new commit)
```bash
git status --short | grep -E "^A|^D" && { echo "STRAY STAGED — abort"; exit 1; } || echo "(nothing staged — correct, push-only)"
git log --oneline origin/v2-backend..HEAD | wc -l   # MUST be 8
```

## STEP 3 — PUSH (origin/v2-backend ONLY)
```bash
git push origin v2-backend
```
If rejected (remote moved): `git fetch origin` then `git merge-base --is-ancestor origin/v2-backend HEAD && echo FF-OK || echo DIVERGED-STOP`.
- FF-OK -> retry `git push origin v2-backend`.
- DIVERGED -> STOP, report to coordinator (do NOT blind rebase/force). Do NOT push any other branch. NEVER `git push --force`.

## STEP 4 — verify pushed + re-sync (PD-007)
```bash
git rev-parse origin/v2-backend            # must now equal local HEAD
git log --oneline -1 origin/v2-backend
for f in $(git show --name-only --pretty="" HEAD); do [ -f "$f" ] && git show HEAD:"$f" > "$f"; done
sync
```

## STEP 5 — clear the barrier + journal (after successful push)
```bash
python3 - <<'PY'
import os,datetime
now=datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%MZ')
# tombstone request.md (clear FREEZE)
open(".coord/push/request.md","w",encoding="utf-8").write("# CLEARED — PUSHED 3568f30..7ae098a (8 commits) to origin/v2-backend "+now+". Barrier closed, FREEZE lifted.\n")
# journal PUSHED line
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write("\n"+now+" | coordinator-0612 | PUSHED origin/v2-backend 3568f30..7ae098a (8 commits: A-batch+R1+B-5 regen+E2+E4+E3+E1). Quorum 3/3 (coord+Security CLEAN+Techwriter READY+doc-debt). Barrier closed.\n")
import subprocess
for p in (".coord/push/request.md",".coord/journal.md"):
    fd=os.open(p,os.O_RDONLY); os.fsync(fd); os.close(fd)
print("barrier cleared + journaled")
PY
sync
```
Also blank/clear .coord/push/ACKS.md (overwrite with a one-line tombstone) the same way if desired.

## Report (chat)
- branch confirmed v2-backend; pushed range 3568f30..<newtip>; commit count 8; origin/v2-backend == local HEAD.
- barrier cleared (request.md tombstoned, journal PUSHED line). FREEZE lifted.
