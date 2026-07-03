# tools/cc_prompt_standard_test_gate.md — add test-gate AGNOSTIC kernel to role-skill-standard
> Authored by curator-0611 (spine owner, NORM-CUR-11). Coordinator §4-APPROVES; operator runs native-CC FROM the curator session. Branch v3 ONLY. NO push (§37/barrier only).
> Scope: only the AGNOSTIC kernel (multi-project build-target substrate fact) goes in the standard. The .NET mechanics (dotnet test failed=0, same-task test update, §MAINT-05) are PROJECT/RTM → ride the techwriter+role batch, NOT here. AD paused — untouched.

## (0) INTEGRITY / branch
- `git rev-parse --abbrev-ref HEAD` MUST == v3 (checkout v3 if not); verify tip by object-store.
- §0.2/§0.5 git status; commit.lock FREE; byte-precheck role-skill-standard.md (ends with "## Local-validation gate" section; no NUL padding).

## (1) BINDING PREAMBLE → .coord/cc/curator.md
## BINDING <UTC> | spec: curator | directive: tools/cc_prompt_standard_test_gate.md | status: open
### DIRECTIVE: append "## Test-gate (AGNOSTIC kernel)" section to .coord/protocols/role-skill-standard.md . gate: coord §4 . v3 . NO push

## (2) TASK — APPEND new section at END of .coord/protocols/role-skill-standard.md (Python+os.fsync; §0.3). Idempotent: skip if "## Test-gate" already present.
<<<SECTION

## Test-gate (AGNOSTIC kernel, curator-blessed 2026-07-02)
TEST-GATE: in a MULTI-PROJECT solution, building or running ONE project does NOT run the tests — they are SEPARATE build targets. "The app builds/runs" NEVER implies "the tests pass". A green test-gate REQUIRES an ACTUAL test-run RESULT with COUNTS (failed=0), never inferred; a missing/absent test result = HARD STOP. Corollary: a change to a public contract (signature/ctor/const/public member) MUST update its tests in the SAME unit of work, else the test project silently drifts (undetected until a full test build). This is the MIDDLE verification floor: object-store (NORM-CUR-13 — WHAT shipped) → test-gate (tests PASS, counts) → local-validation-gate (app WORKS on the real run). Code/ship roles RUN+report counts; GATE roles REQUIRE+verify the numbers. · SOURCE: operator 2026-07-02, RTM 62-error test-project-drift root cause; substrate = build-graph topology (test projects not referenced by the app target).
SECTION

## (3) VERIFY (object-store, before commit)
- role-skill-standard.md contains "## Test-gate" + "SEPARATE build targets" + "REQUIRES an ACTUAL test-run RESULT with COUNTS" + "MIDDLE verification floor"; the "## Local-validation gate" + "## §A source-pin discipline" + Capture/promotion/§C sections INTACT; proper EOF; byte/NUL-clean.

## (4) COMMIT (native-CC, commit.lock, v3, NO push)
git add -f .coord/protocols/role-skill-standard.md
git commit -m "docs(spine): add test-gate AGNOSTIC kernel to role-skill-standard (multi-project: app-runs != tests-pass; middle verification floor) [curator/NORM-CUR-11]"
Then §0.6a RESULT → .coord/cc/curator.md ; journal ; release lock ; §0.7 re-sync ; NO push ; report hash.

## (5) REPORT BACK to curator (inbox/coordinator.md): commit hash + section present + branch==v3.
