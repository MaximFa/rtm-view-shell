# CC TASK — commit regenerated Tech-Writer docs to v3 (backstop, NO push)

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md (§10). Only after: proceed.

## Step 0 — integrity + branch
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD        # MUST be v3; if not: git checkout v3
git status --short | head

## Why
The Tech-Writer HELD doc package was LOST (untracked, wiped by git clean during a rebuild). Operator
decision A: regenerate + COMMIT to v3 NOW so it is backstopped in the object store and rides the ONE
clean push. IRON RULE: these docs must be committed WIP on v3 — never left untracked.

## Task — stage explicitly (ONE path per line; NO broad -A; NO CMD ^ continuations)
git add docs/user-documentation/end-user/
git add docs/user-documentation/admin/A-03/
git add docs/user-documentation/admin/A-04/
git add docs/user-documentation/admin/A-05/
git add docs/user-documentation/admin/A-07/
git add docs/user-documentation/admin/A-08/
git add docs/training/
git add docs/business/
git add docs/methodology/project-launch/editing/
git add docs/methodology/project-launch/approved/
git add docs/archive/
git add docs/incidents/incidents.md
git add docs/user-documentation/DOC-REGISTRY.md
git add docs/DOCS_INVENTORY.md
# (Any path that does not exist is harmless — the recovery is 19/19; re-run to catch late files.)

## Commit (use CLAUDE.md §0.4 index.lock / §0.4 HEAD.lock workarounds if needed)
git commit -m "docs: recover Tech-Writer doc package to v3 (RTM-REL-2026.06) — A-03/04/05/07v1.1/08, B-01/03/04/05/06/07, D-02/03, C-01..05, Runbook v1.2; incident 2026-07-03 untracked-loss backstop"

## §0.6 verify + §0.5 object-store confirm
git log --oneline -1
git status --short | head
git ls-files docs/user-documentation/end-user/B-07/ | head    # confirm tracked

## RESULT
Append the commit hash + tracked-file confirmation to .coord/cc/techwriter.md (binding RESULT).

## NO PUSH. (Ships via the ONE clean push barrier only, §37.)
