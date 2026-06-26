# CC task — docs(ЧП): commit emergency §A clauses + reports v1 acceptance/debrief docs — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Coordinator-authored docs-persist for the ЧП handoff: commit the ЧП §A clauses (all 7 role-skills) + the 2 ЧП docs so the handoff runs on COMMITTED state. Branch **v3**. Commit `docs:`. **NO push** (§37). NARROW-ADD by name only.

## STEP 0 — integrity (object-store, §0.6a/§0.5)
- `cd "D:\Claude\Projects\RTM View Shell"`; `git status --short`.
- These are NEW/EDITED content (ЧП §A + new docs). Do NOT restore-from-HEAD on a short WT — that would ERASE the ЧП edits. For each of the 9 target files verify it is intact: NUL=0 (`tr -cd '\000' < f | wc -c` = 0) and ends on a proper line; if any is NUL-corrupted, RE-APPLY (re-run the coordinator write) — do NOT discard the edit.

## TARGET FILES (exactly these 9 — NARROW, by name; NO -A, NO Installations/, NO other untracked)
- .claude/skills/role-shell/role-shell.md
- .claude/skills/role-bi/role-bi.md
- .claude/skills/role-dba/role-dba.md
- .claude/skills/role-backend/role-backend.md
- .claude/skills/role-devops/role-devops.md
- .claude/skills/role-test/role-test.md
- .claude/skills/role-coordinator/role-coordinator.md
- docs/Reports-v1-Acceptance-Checklist-and-Gap-Plan.md
- docs/incidents/EMERGENCY-debrief-2026-06-25.md

## VERIFY before staging
- Each role-skill contains the ЧП block: `grep -c "ЧП / EMERGENCY MODE" <file>` = 1 (×7). Each role-skill `## §A` header intact (grep `## §A` = 1).
- Both docs present + NUL=0.

## COMMIT (commit.lock; §0.4 index.lock workaround if needed; NO push)
```bash
# acquire commit.lock (Python open(path,"x"); retry 5x60s; never auto-delete a lock you don't own)
# If 'git add' / 'git commit' fail with .git/index.lock 'Operation not permitted' (known on this mount, §0.4):
cp .git/index /tmp/cc-chp-idx
GIT_INDEX_FILE=/tmp/cc-chp-idx git add \
  .claude/skills/role-shell/role-shell.md .claude/skills/role-bi/role-bi.md \
  .claude/skills/role-dba/role-dba.md .claude/skills/role-backend/role-backend.md \
  .claude/skills/role-devops/role-devops.md .claude/skills/role-test/role-test.md \
  .claude/skills/role-coordinator/role-coordinator.md \
  docs/Reports-v1-Acceptance-Checklist-and-Gap-Plan.md docs/incidents/EMERGENCY-debrief-2026-06-25.md
GIT_INDEX_FILE=/tmp/cc-chp-idx git status --short   # must show ONLY the 9 staged; ZERO Installations/, zero other
TREE=$(GIT_INDEX_FILE=/tmp/cc-chp-idx git write-tree)
COMMIT=$(git commit-tree "$TREE" -p HEAD -m "docs(ЧП): emergency §A clauses in all 7 role-skills + reports v1 acceptance checklist + ЧП debrief log [coordinator-authorized]")
# update branch ref (HEAD.lock workaround if needed, §0.4):
python3 -c "import os,subprocess; gd=subprocess.check_output(['git','rev-parse','--git-dir']).decode().strip(); h=open(os.path.join(gd,'HEAD')).read().strip(); ref=h[5:] if h.startswith('ref: ') else None; open(os.path.join(gd,ref),'w').write('$COMMIT\n'); print('HEAD ->',ref)"
cp /tmp/cc-chp-idx .git/index
```
(If plain `git add`/`git commit` works without the lock issue, use it — same 9 files, same message.)

## §0.6 POST-COMMIT VERIFY
- `git show --stat HEAD` = EXACTLY 9 files (7 role-skills + 2 docs), ZERO deletions, ZERO Installations/.
- `git log --oneline -1` shows the docs(ЧП) commit. `git status --short` shows the 9 no longer M/?? (the Installations/ deletions + other untracked REMAIN — that's expected, out of scope).
- **NO push** (§37).

## §0.7 re-sync (LAST)
```bash
for f in .claude/skills/role-shell/role-shell.md .claude/skills/role-bi/role-bi.md .claude/skills/role-dba/role-dba.md .claude/skills/role-backend/role-backend.md .claude/skills/role-devops/role-devops.md .claude/skills/role-test/role-test.md .claude/skills/role-coordinator/role-coordinator.md docs/Reports-v1-Acceptance-Checklist-and-Gap-Plan.md docs/incidents/EMERGENCY-debrief-2026-06-25.md; do git show HEAD:"$f" > "$f"; done
sync
```
Report: commit hash + `git show --stat HEAD` (9 files, 0 del, 0 Installations). NO push.
