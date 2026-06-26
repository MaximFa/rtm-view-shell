# CC task — SPINE FOLD-FIX on v2-backend (native CC) — add curator FOLD-1 + FOLD-2

> coordinator-0622. NATIVE Windows CC ONLY. Branch **v2-backend** (HEAD bffa20c). **NO push (§37).** Curator FORM-reviews vs AD 029f3a8 for byte-parity after.
> Adds the 2 agnostic FOLDs the spine commit (bffa20c) missed. ANCHORS = curator-confirmed (07:53): BOTH are NEW end-of-file SECTIONS (NOT §B / Capture-discipline), byte-identical to AD 029f3a8. Idempotent: skip an edit if its section header already present.

## PRE-FLIGHT — STOP on mismatch
1. On v2-backend; `git rev-parse HEAD` == bffa20c... (object-store, not mount status).
2. §0.2 RESTORE the PD-007-drifted WT from HEAD FIRST (committed blob bffa20c is authoritative):
   `git show HEAD:.coord/protocols/role-skill-standard.md > .coord/protocols/role-skill-standard.md`
   `git show HEAD:.coord/protocols/role-skill-TEMPLATE.md  > .coord/protocols/role-skill-TEMPLATE.md`
   verify `git hash-object <f>` == `git rev-parse HEAD:<f>` for BOTH before editing.
3. §0.3 Python+fsync for edits; commit.lock (§0.4 temp-index if index.lock phantom).

## EDITS (Python+fsync; APPEND new section at END of each file; idempotent — skip if header already present)

A. `.coord/protocols/role-skill-TEMPLATE.md` — APPEND at END (after `## §D REFERENCE`), VERBATIM (FOLD-1):
```
## COMMIT-block guidance (AGNOSTIC, curator-blessed 2026-06-21)
COMMIT must be an EXPLICIT executable step (NOT under `##` comments — commands under `##` are read as docs and do not run) + `git add -f .claude/skills/...` + verify HEAD advanced + `git cat-file -e HEAD:<path>`.
```

B. `.coord/protocols/role-skill-standard.md` — APPEND at END (after `## §C VERIFY — WRITE-TIME GATE`), VERBATIM (FOLD-2):
```
## §A source-pin discipline (AGNOSTIC, curator-blessed 2026-06-21)
NEVER pin a SOURCE to a § that does not literally support the claim (verify the cite exists). If the codified location is absent, mark CONVENTION/skill-provided — do not fabricate a CLAUDE § (cf. finesse-sim #6 / CODE-05 catches).
```
After each write: sync + tail -3 + NUL-check (0).

## COMMIT (docs:, commit.lock, NO push)
```
git add -f .coord/protocols/role-skill-TEMPLATE.md .coord/protocols/role-skill-standard.md
git commit -m "docs: spine fold-fix — COMMIT-block guidance (TEMPLATE) + §A source-pin discipline (standard) — agnostic folds, AD 029f3a8 parity [curator/NORM-CUR-11]"
```

## VERIFY + JOURNAL + RE-SYNC
- committed blob: `git show HEAD:.coord/protocols/role-skill-TEMPLATE.md | findstr "COMMIT-block guidance"` ==1 + "EXPLICIT executable step" ==1; `git show HEAD:.coord/protocols/role-skill-standard.md | findstr "source-pin discipline"` ==1 + "NEVER pin a SOURCE" ==1.
- journal (Python+fsync); §0.7 re-sync both files from HEAD; sync. NO push.
- REPORT -> inbox/coordinator.md: hash, both section markers verified in committed blob, branch v2-backend, NO push. (curator FORM-reviews vs AD 029f3a8 byte-parity.)
