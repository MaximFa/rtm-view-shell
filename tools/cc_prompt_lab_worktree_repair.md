# CC task — repair `lab` worktree (Method Lab track) + recover Lab session deliverables

## Scope / nature of this task
This task is **git-plumbing + data recovery** on the `lab` branch worktree. It is NOT v2-backend
feature work:
- It touches ONLY the `lab` worktree at `D:\Claude\Projects\RTM-Lab` and the shared `.git`.
- It makes **NO git commits** and **NO git push** (§37). It leaves recovered files as UNTRACKED
  working-tree files for the Lab session to reconcile + commit later via its own CC.
- It does NOT claim or modify any v2-backend file → the §42 commit.lock / journal / sync-block
  flow does NOT apply (no commit). The v2-backend push barrier (if any) does NOT gate this task —
  `lab` is independent of v2-backend HEAD.

Run native git from the main clone. Do everything with **native Windows git**, never assume the
Cowork mount.

## Step 0 — orient (read-only)
```
cd "D:\Claude\Projects\RTM View Shell"
git worktree list
git status --short            # main tree — informational only, do not modify v2-backend files
git log -1 --format="%H" origin/lab
git ls-tree -r --name-only origin/lab
```
Confirm: `D:\Claude\Projects\RTM-Lab` is listed as a worktree of `[lab]` and currently `prunable`.
Confirm `origin/lab` tree contains: Evidence-Log.md, Method-Charter.md, Method-Discussion-Log.md, README.md.

## Step 1 — BACK UP all uncommitted Lab work (MANDATORY, before any reset)
The Lab session worked in the SUBFOLDER `D:\Claude\Projects\RTM-Lab\Method Lab\` and its files are
UNTRACKED (and may be more than the two known: Method-Charter.md (v0.4), RUN-PLAN-AgentGrid-informedGO.md).
Do NOT assume names — inventory and copy EVERYTHING untracked under the worktree.

```
# Fresh backup dir OUTSIDE the worktree:
$bk = "D:\Claude\Projects\RTM-Lab-recovery-20260609"
New-Item -ItemType Directory -Force -Path $bk | Out-Null
# Copy the whole worktree's NON-.git content verbatim (safety net), preserving structure:
robocopy "D:\Claude\Projects\RTM-Lab" "$bk\full-snapshot" /E /XD ".git" | Out-Null
# Also explicitly list what git considers untracked/modified in the lab worktree:
git -C "D:\Claude\Projects\RTM-Lab" status --short 2>$null
```
PRINT the full file list of `$bk\full-snapshot` (recurse) so the operator sees exactly what was saved.
If `git -C "D:\Claude\Projects\RTM-Lab" status` errors because the worktree link is dead, that is
EXPECTED (prunable) — the robocopy snapshot is the real safety net; proceed.

## Step 2 — repair worktree linkage
```
cd "D:\Claude\Projects\RTM View Shell"
git worktree prune                                   # drop dead admin entries
git worktree repair "D:\Claude\Projects\RTM-Lab"     # re-link gitdir <-> worktree
git worktree list                                    # RTM-Lab must NO LONGER say prunable
```
If `repair` cannot fix it (worktree admin dir gone), fall back to recreate:
```
git worktree remove --force "D:\Claude\Projects\RTM-Lab"   # only metadata; files already backed up
git worktree add "D:\Claude\Projects\RTM-Lab" lab
```
(Recreate is acceptable because Step 1 backed up everything.)

## Step 3 — bring worktree to truth (5f6d712)
```
git -C "D:\Claude\Projects\RTM-Lab" fetch origin
git -C "D:\Claude\Projects\RTM-Lab" reset --hard origin/lab
git -C "D:\Claude\Projects\RTM-Lab" status --short          # expect clean
```
VERIFY truth is present:
```
Select-String -Path "D:\Claude\Projects\RTM-Lab\Evidence-Log.md" -Pattern "E-021" | Select-Object -First 1
Test-Path "D:\Claude\Projects\RTM-Lab\Method-Discussion-Log.md"     # must be True
```
Both must succeed (E-021 found, Method-Discussion-Log.md True). If not — STOP and report.

## Step 4 — migrate recovered deliverables to worktree ROOT (layout = root; do NOT clobber canon)
From the backup snapshot (`$bk\full-snapshot`), move the Lab session's work to the worktree ROOT:
- For each file under `...\Method Lab\` (and any other backed-up untracked file):
  - If its name does NOT collide with a tracked root file (e.g. `RUN-PLAN-AgentGrid-informedGO.md`):
    copy to `D:\Claude\Projects\RTM-Lab\<name>` as-is (it becomes a new untracked file at root).
  - If its name COLLIDES with a tracked root file (notably `Method-Charter.md`):
    DO NOT overwrite. Copy to root as `Method-Charter.labsession-v0.4.md` (suffix `.labsession-v0.4`
    before extension). Rationale: the v0.4 was authored on a STALE base (no E-006..E-021); the Lab
    session must reconcile it against the canonical Method-Charter.md, not blindly replace it.
- Do NOT delete the `Method Lab\` subfolder yet if you are unsure — the backup covers it. If clean,
  remove the now-empty `D:\Claude\Projects\RTM-Lab\Method Lab\` after migration.

PRINT: final `Get-ChildItem D:\Claude\Projects\RTM-Lab -Recurse -File | Select FullName` so the
operator and Lab session see the resulting root layout.

## What NOT to do
- NO `git commit`, NO `git push` anywhere. Recovered files stay untracked for the Lab session.
- Do NOT overwrite `Method-Charter.md` with the v0.4 (keep both; Lab reconciles).
- Do NOT touch the v2-backend working tree files, do NOT touch `.coord/`.
- Do NOT repair the `coord` worktree in this task (separate decision).

## Report back (exact)
1. `git worktree list` before vs after (prove RTM-Lab no longer prunable).
2. Backup location + full file list of `$bk\full-snapshot`.
3. Confirmation E-021 present + Method-Discussion-Log.md present in the worktree after reset.
4. Final root layout of `D:\Claude\Projects\RTM-Lab` (recurse), with the v0.4 charter saved as
   `Method-Charter.labsession-v0.4.md` and RUN-PLAN at root.
5. Anything ambiguous you stopped on.
