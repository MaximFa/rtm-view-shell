
## 2026-06-13T11:28:19Z | binding: curator <-> CC | directive: tools/cc_prompt_binding_mandatory.md | status: open
### DIRECTIVE: make CC<->spec BINDING mandatory in §0.6a template (NORM-CUR-07c). Claims: CLAUDE.md, .claude/skills/session-coord/session-coord.md. docs: prefix.
## 2026-06-13T11:29:52Z | binding: curator <-> CC | directive: tools/cc_prompt_binding_mandatory.md | status: done
### RESULT:
- commit: 4742ef2837fa81a2ccc3b317852f8aef62eec987
- files: CLAUDE.md (2349L), .claude/skills/session-coord/session-coord.md (337L)
- build/test: skipped (docs change)
- blockers: none
- object-store verify: yes (commit exists in git log)
- Changes: Added §0.6b mandatory CC<->spec binding block to CLAUDE.md; added L-SC-27/L-SC-28 to session-coord skill

## 2026-06-14T05:09:54Z | binding: curator <-> CC | directive: tools/cc_prompt_codify_lsc29.md | status: open
### DIRECTIVE: Codify L-SC-29 (push-prompt preflight) into session-coord skill lessons table + push-section note + decision sentence. Claim: .claude/skills/session-coord/session-coord.md. Prefix: docs:.

### RESULT (by CC): commit b618a14 ; L-SC-29 row added to lessons table (5-step preflight); push verb updated with L-SC-29 reference + decision sentence (canonical, bake into cc_prompt_push.md next); NO push; verified: object-store (git show HEAD:.claude/skills/session-coord/session-coord.md | grep L-SC-29).
## 2026-06-14T05:11:34Z | binding: curator <-> CC | directive: tools/cc_prompt_codify_lsc29.md | status: done
## BINDING 2026-07-02T04:46:05Z | spec: curator | directive: tools/cc_prompt_standard_local_validation.md | status: open
### DIRECTIVE: append "## Local-validation gate" section to .coord/protocols/role-skill-standard.md (AGNOSTIC) . gate: coord $4 . v3 only . NO push

### RESULT: commit 8fd908b . files 1 (role-skill-standard.md) . build/test n/a . status done . blockers none . verified: object-store . branch v3
## BINDING 2026-07-02T04:46:54Z | spec: curator | directive: tools/cc_prompt_standard_local_validation.md | status: done

## BINDING 2026-07-02T14:09:24Z | spec: curator | directive: tools/cc_prompt_standard_test_gate.md | status: open
### DIRECTIVE: append "## Test-gate (AGNOSTIC kernel)" section to .coord/protocols/role-skill-standard.md . gate: coord §4 . v3 . NO push

### RESULT (CC->spec): commits b9fa318 . files .coord/protocols/role-skill-standard.md . status done . verified: object-store (Test-gate section present, SEPARATE build targets + REQUIRES COUNTS + MIDDLE floor confirmed, all existing sections intact)

## BINDING 2026-08-11T22:22:03Z | spec: curator | directive: tools/cc_prompt_curator_continuity_canon.md | status: open
### DIRECTIVE: write curator-continuity-canon.md + link it from role-curator §D + role-skill-standard . gate: none (curator-owned) . v3 . NO push
### RESULT (CC->spec): commit a110044 . files 3: curator-continuity-canon.md (61 L), role-curator.md (45 L), role-skill-standard.md (70 L) . build/test n/a . status done . verified: object-store . branch v3 . NO push
## BINDING 2026-08-11T22:24:37Z | spec: curator | directive: tools/cc_prompt_curator_continuity_canon.md | status: done
## BINDING 2026-08-11T22:35:22Z | spec: curator | directive: tools/cc_prompt_fix_canon_apostrophes.md | status: open
### DIRECTIVE: fix apostrophe-doubling in curator-continuity-canon.md (byte-copy from staging)

### RESULT (CC->spec): commit 7e14303 . files 1 (curator-continuity-canon.md) . doubled-apos=0 . status done . verified: object-store . branch v3 . NO push
## BINDING 2026-08-11T22:35:22Z | spec: curator | directive: tools/cc_prompt_fix_canon_apostrophes.md | status: done