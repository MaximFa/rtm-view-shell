# CC PUSH — #2 barrier -> origin/v2-backend (6 commits + BI docs-sweep)  [the ONLY prompt allowed to push, §37]
> Quorum COMPLETE 8/8 (Security + techwriter mandatory gates READY; bi/backend/dba/devops/curator/coordinator READY; no HOLD).
> Native CC only (Cowork mount cannot push, L-SC-20). Branch MUST be v2-backend.

## Read first
.claude/skills/session-coord/session-coord.md (§42.7 barrier, §0.2 integrity, §0.4 git workarounds, L-SC-29 preflight)

## BINDING PREAMBLE -> .coord/cc/coordinator.md
`## BINDING <UTC> | spec: coordinator-0612 | directive: tools/cc_prompt_push_0620.md | status: open`
`### DIRECTIVE: push #2 barrier (6 commits b58e2c2..3516a68) + BI docs-sweep (explicit adds) -> origin/v2-backend. NO Export-All. NO broad add.`

## STEP 0 — integrity + branch (L-SC-29)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD     # MUST be v2-backend; else STOP
git status --short
# restore any PD-007-truncated WT in the explicit-add set from HEAD (do NOT stage truncated):
for f in CLAUDE.md docs/bi/Historical_Reports_Project_Plan.md \
         docs/bi/approved/doc/Historical_Reports_Project_Plan.docx \
         docs/bi/approved/doc/Historical_Reports_Project_Plan_RU.docx \
         tools/cc_prompt_create_role_bi.md tools/cc_prompt_hist_001.md tools/cc_prompt_hist_a3_callid.md ; do
   :  # these are NEW/edited; verify they are NOT truncated mid-line (tail -1) before staging; if a TRACKED file is truncated vs HEAD, git show HEAD:"$f" > "$f"
done
sync
```

## STEP 1 — docs-sweep commit (commit.lock; EXPLICIT adds ONLY — NEVER git add -A / db/ / staging/ broad)
Acquire commit.lock (Python open 'x' on .coord/locks/commit.lock; if held -> STOP+report). Then stage ONLY:
```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add CLAUDE.md
GIT_INDEX_FILE=/tmp/cc-idx git add docs/bi/Historical_Reports_Project_Plan.md
GIT_INDEX_FILE=/tmp/cc-idx git add docs/bi/approved/doc/Historical_Reports_Project_Plan.docx docs/bi/approved/doc/Historical_Reports_Project_Plan_RU.docx
GIT_INDEX_FILE=/tmp/cc-idx git add tools/cc_prompt_create_role_bi.md tools/cc_prompt_hist_001.md tools/cc_prompt_hist_a3_callid.md tools/cc_prompt_devops_*.md tools/cc_prompt_capture_deploy_lessons_0619.md tools/cc_prompt_push_0620.md 2>/dev/null
# REVIEW the staged set — must be ONLY the above; NO db/ staging/ .coord/ docs/bi/editing/build/node_modules root-junk:
GIT_INDEX_FILE=/tmp/cc-idx git diff --cached --name-only
# If anything unexpected staged -> git reset <f> before commit.
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "docs(bi): Historical Reports project plan (md + EN/RU branded docx) + CLAUDE.md §46 identity convention + §4'd CC prompts (role-bi/hist-001/a3/lessons) — #2 barrier (RTM-REL-2026.06)"
cp /tmp/cc-idx .git/index
rm -f .coord/locks/commit.lock 2>/dev/null
git log --oneline -1
```
NOTE: docs/bi/TZ_Historical_Reports.md already committed at 3516a68 — do NOT re-add unless WT differs (ADDENDUM A) by content. .coord/** is gitignored (NOT pushed). docs/bi/editing/build/ generators/node_modules: do NOT add.

## STEP 2 — hygiene: stale .git/index.lock (operator/native only)
If a stale `.git/index.lock` exists and blocks: per §0.4, `rm .git/index.lock` (native Windows; mount cannot). Verify `git status` works after.
Also reap stale ack files (harmless): the 06-13 `# CLEARED` acks/*.md may remain; ignore (request.md acks/<slug>.md is the live set).

## STEP 3 — pre-push verify
```bash
git log --oneline origin/v2-backend..HEAD | wc -l    # expect 7 (6 + the docs-sweep)
git status --short | grep -E "^A|^D" || echo "(no stray staged adds/deletes)"
```

## STEP 4 — PUSH (origin/v2-backend ONLY)
```bash
git push origin v2-backend
```
If rejected: `git fetch origin`; `git merge-base --is-ancestor origin/v2-backend HEAD && echo FF-OK || echo DIVERGED-STOP`. FF-OK -> retry; DIVERGED -> STOP, report (no blind rebase). Do NOT push any other branch.

## STEP 5 — re-sync (PD-007) + barrier cleanup + report
```bash
for f in $(git show --name-only --pretty="" HEAD); do [ -f "$f" ] && git show HEAD:"$f" > "$f"; done
sync
# remove the barrier (FREEZE lifts):
rm -f .coord/push/request.md ; rm -f .coord/push/acks/*.md 2>/dev/null   # (Python+fsync unlink if rm blocked)
git log --oneline -3 ; git status --short | head
```
Journal: append `<UTC> | coordinator-0612 | PUSHED origin/v2-backend <old>..<new> (7 commits) — #2 barrier (deploy fixes + lessons + role-bi + BI docs). FREEZE lifted.`

## BINDING POSTAMBLE -> .coord/cc/coordinator.md RESULT: pushed <range> (N commits); docs-sweep <hash> (explicit adds only, verified no broad); FREEZE lifted; verified: git push output + git log origin/v2-backend.

## DO NOT
NO Export-All; NO broad `git add`; NO secrets in any command; NO push to `v2`; do NOT commit db/ staging/ .coord/ node_modules / PD-007-truncated WT.
