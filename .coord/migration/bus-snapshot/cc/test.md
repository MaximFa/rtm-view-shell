## 2026-06-23T20:15:00Z | binding: test <-> CC | directive: tools/cc_prompt_regression_checklist.md | status: open
### DIRECTIVE: Author the standing pre-push regression checklist (testing/regression_checklist.md). Claims: testing/regression_checklist.md, tools/cc_prompt_regression_checklist.md. Prefix: test.
### RESULT (CC->spec):
- commit: 46a2989 (test: add standing pre-push regression checklist)
- files: testing/regression_checklist.md (40 lines, new)
- build/test: skipped (documentation artifact, no code)
- blockers: none
- verified: yes - git log shows 46a2989, content matches prompt spec
- status: done
## 2026-06-24T01:00:00Z | binding: test <-> CC | directive: tools/cc_prompt_regression_wgsection.md | status: open
### DIRECTIVE: Append section 6 (Widget grid lifecycle, DB-verified) to testing/regression_checklist.md. Claims: testing/regression_checklist.md, tools/cc_prompt_regression_wgsection.md. Prefix: test.
### RESULT (CC->spec):
- commit: 18704c0 (test: regression checklist section 6)
- files: testing/regression_checklist.md (50 lines, +12)
- build/test: skipped (documentation)
- blockers: none
- verified: object-store (git show confirms section 6 + v2 revision row)
- status: done