---
name: untracked-held-is-data-loss
description: "CRITICAL: never keep a deliverable UNTRACKED/HELD for long — untracked files have no object-store backstop and get wiped by git clean. Commit as WIP to the branch instead."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 354b8d04-e136-44ac-8d8d-6a17e576c95b
---

**CRITICAL LESSON (incident 2026-07-03, RTM techwriter-0610).** My entire ~19-doc branded
documentation package (A-03/04/05/07/08, B-01/03/04/05/06/07, C-01..05, D-02/03) + the Project
Launch Runbook v1.1/v1.2 — weeks of work — was **PERMANENTLY LOST**. Root cause: I kept it
**UNTRACKED/HELD** in `editing/` and `approved/` for weeks, acking every push barrier with "my
package is untracked/HELD, not in the push." Untracked files are **NOT in the git object store**, so
they had **zero backstop**. A `git clean -fdx` (run by the DB carve / Rebuild-Proof fresh-rebuild
tooling, and/or the v2-backend→v3 branch consolidation) **deleted every untracked file**. `git status`
then showed zero untracked in docs/; nothing in stash; no git history (never committed) → unrecoverable
from git. Only COMMITTED docs survived (docs/bi Unified Reporting Guide, A-02 published, runbook v1.0).

**The trap:** "HELD for review" was treated as equivalent to "keep untracked." It is NOT. HELD means
*don't push to origin*; it must STILL be a **committed WIP on the working branch** so the object store
holds it. Untracked = one `git clean` from oblivion. This project's own tooling runs clean rebuilds
routinely (R0b/R0c/R0e carve, Rebuild-Proof.ps1), so untracked files are actively at risk here.

**RULE going forward:**
- Any deliverable that will live more than one session gets **committed to the branch immediately**
  (via CC: `docs:` commit, no push). HELD-for-review = committed-but-not-pushed, never untracked.
- At each barrier, instead of "untracked/HELD, not in push," ensure the package is committed (so it's
  backed up) and simply *excluded from origin push* by the push prompt's explicit-add scope.
- The object store is the only real backstop (CLAUDE.md §0.1/§0.5). If it's not committed, it does not
  durably exist — treat any uncommitted work as ephemeral.

Related: [[docx-gen-divergence]], [[feedback_development_process]].
