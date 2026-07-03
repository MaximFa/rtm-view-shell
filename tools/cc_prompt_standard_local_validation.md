# tools/cc_prompt_standard_local_validation.md — add local-validation-gate to role-skill-standard (AGNOSTIC)
> Authored by curator-0611 (spine owner, NORM-CUR-11). Coordinator §4-APPROVES; operator runs native-CC FROM the curator session. Branch v3 ONLY (single-branch-v3). NO push (§37/barrier only).
> Scope note: local-validation-gate is AGNOSTIC → belongs in the standard (cross-project spine). single-branch-v3 is PROJECT/RTM → NOT here (it goes to CLAUDE §42 + session-coord via the techwriter/role batch). AD copy of the standard syncs later (AD operator-paused) — do NOT touch AD.

## (0) INTEGRITY / branch (single-branch-v3)
- `git rev-parse --abbrev-ref HEAD` MUST == v3 (checkout v3 if not); verify HEAD is the v3 tip by object-store.
- §0.2/§0.5: `git status --short`; verify by object store. commit.lock FREE (§26.3).
- Byte-precheck role-skill-standard.md (no NUL padding; ends with the "## §A source-pin discipline" section).

## (1) BINDING PREAMBLE → .coord/cc/curator.md
## BINDING <UTC> | spec: curator | directive: tools/cc_prompt_standard_local_validation.md | status: open
### DIRECTIVE: append "## Local-validation gate" section to .coord/protocols/role-skill-standard.md (AGNOSTIC) . gate: coord §4 . v3 only . NO push

## (2) TASK — APPEND new section at END of .coord/protocols/role-skill-standard.md (Python+os.fsync; §0.3). Idempotent: skip if "## Local-validation gate" already present.
<<<SECTION

## Local-validation gate (AGNOSTIC, curator-blessed 2026-07-02)
LOCAL-VALIDATION GATE: nothing moves forward until the commit is validated by a LOCAL RUN on the REAL app — not a PoC/harness/component/object-store alone. Object-store verifies WHAT shipped; local validation verifies it WORKS (TWO floors). CODE/ship roles (backend/shell/dba/devops/qa/test) PERFORM the local validation; GATE roles (curator/coordinator/security) REQUIRE local-validation evidence BEFORE greenlight. Complements NORM-CUR-13 (object-store = truth for what's committed). · SOURCE: operator 2026-06-26; pins T1 9734252 (object-store-verified-but-broken-in-prod), Garnet INC-001d (PoC-harness-only).
SECTION

## (3) VERIFY (object-store, before commit)
- role-skill-standard.md contains "## Local-validation gate" + "LOCAL RUN on the REAL app" + "TWO floors"; existing sections (§A source-pin discipline, Capture discipline, §C write-time gate, promotion gate) INTACT; proper EOF; byte/NUL-clean.

## (4) COMMIT (native-CC, commit.lock, v3, NO push)
git add -f .coord/protocols/role-skill-standard.md
git commit -m "docs(spine): add local-validation-gate to role-skill-standard (AGNOSTIC — 2nd floor to NORM-CUR-13; code=perform/gate=require) [curator/NORM-CUR-11]"
Then §0.6a RESULT → .coord/cc/curator.md ; journal ; release lock ; §0.7 re-sync ; NO push ; report hash.

## (5) REPORT BACK to curator (inbox/coordinator.md): commit hash + confirm section present + branch==v3.
