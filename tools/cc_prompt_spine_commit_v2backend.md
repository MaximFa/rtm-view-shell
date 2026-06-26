# CC task — SPINE COMMIT on v2-backend (native CC) — protocol/methodology spine

> Owner: curator (recipe) + coordinator-0622 (authored). NATIVE Windows CC ONLY (Cowork mount cannot reliably commit — L-SC-20; curator will NOT mount-commit). Branch **v2-backend**. **NO push (§37).**
> 1st of the serialized v2-backend pair (spine FIRST, then devops Garnet Phase-2). Curator FORM-reviews the committed result after.
> WHY v2-backend: the protocol/methodology spine is CROSS-CUTTING trunk material, NOT the v3 reports feature line.

## PRE-FLIGHT — STOP on any mismatch (report to inbox/coordinator.md)
1. `git checkout v2-backend`; `git rev-parse --abbrev-ref HEAD` == v2-backend; `git rev-parse HEAD` resolves (object-store, NOT mount `git status`). git-reconcile is DONE (Garnet @2a63f57 on v2-backend).
2. `.git/index.lock` phantom: if a `git add` later fails "Unable to create '.git/index.lock': File exists" -> use §0.4 temp-index (`cp .git/index /tmp/spine_idx; GIT_INDEX_FILE=/tmp/spine_idx git add ...; GIT_INDEX_FILE=/tmp/spine_idx git commit ...; cp /tmp/spine_idx .git/index`).
3. `git status --short` to enumerate the spine-M set. Verify each file's content NATIVELY (read the Windows FS; mount writes may not have reached native / may be PD-007-truncated).

## SPINE-M SET (coordinator object-store-verified 2026-06-22: 3 files DIFFER vs v2-backend HEAD -> commit; discipline-lessons SAME -> skip)
- `.claude/skills/role-coordinator/role-coordinator.md`  — §B must contain 3 lessons dated 2026-06-22 (grep all 3 SOURCE-pins):
    (a) "SOURCE: operator directive 2026-06-22" (lesson-routing / coordinator-doesn't-hand-CC-commands)
    (b) "SOURCE: index.lock probe 2026-06-22" (diagnose phantom index.lock on 'commits not landing')
    (c) "SOURCE: v3 barrier 2026-06-22, tools/cc_prompt_push*.md hardcoded" (branch-hardcoded push footgun)
- `.coord/protocols/role-skill-TEMPLATE.md`  — must contain §A+§B ROUTING + FOLD-1 (see AUTHORITATIVE below)
- `.coord/protocols/role-skill-standard.md`     — must contain FOLD-2 source-pin rule (see AUTHORITATIVE below)
- `.coord/protocols/discipline-lessons.md` — ALREADY at v2-backend HEAD (object-store SAME, NO change) -> do NOT include in this commit
- + ANY other protocol/skill `M` from git status (do NOT sweep non-spine files; ONLY .claude/skills/** + .coord/protocols/**)

If ANY listed marker is MISSING natively (truncation/drop): for the curator-owned files RE-APPLY from AUTHORITATIVE text below; for role-coordinator §B / discipline-lessons, STOP and report (coordinator re-supplies) — do NOT commit a partial spine.

## AUTHORITATIVE TEXT (curator, RTM-identical to AD 029f3a8 — re-apply ONLY if missing/truncated natively)
role-skill-TEMPLATE.md §A ROUTING: "§A holds ONLY CRITICAL AMPLIFIERS — load-bearing invariants that change init-time behaviour / high recurrence / large blast-radius. Everything else stays in §B. ~40-line cap."
role-skill-TEMPLATE.md §B ROUTING: "record EVERY lesson in §B (append-only); elevate to §A only if a critical amplifier. Default §B. SOURCE: operator 2026-06-22."
role-skill-TEMPLATE.md FOLD-1 (commit-block): "COMMIT must be an EXPLICIT executable step (NOT under ## comments) + `git add -f` + verify HEAD advanced + `git cat-file -e HEAD:<path>`."
role-skill-standard.md FOLD-2 (§A source-pin): "NEVER pin a SOURCE to a § that doesn't literally support the claim; verify the cite exists, else mark CONVENTION/skill-provided (cf finesse-sim #6 / CODE-05)."

## COMMIT (docs:, commit.lock, NO push)
```
# acquire commit.lock (.coord/locks/commit.lock; §0.4 temp-index if index.lock phantom)
git add -f .claude/skills/role-coordinator/role-coordinator.md .coord/protocols/role-skill-standard.md .coord/protocols/role-skill-TEMPLATE.md
# + any other verified spine-M under .claude/skills/** / .coord/protocols/**
git commit -m "docs: spine — lesson-routing (TEMPLATE+standard) + 2 agnostic folds (commit-block, source-pin-verify) + role-coordinator §B lessons [curator/NORM-CUR-11]"
# release commit.lock
```

## POST-COMMIT VERIFY (object-store) + JOURNAL + RE-SYNC
- `git show HEAD:.claude/skills/role-coordinator/role-coordinator.md | findstr "2026-06-22"` -> the 3 lessons present in the COMMITTED blob.
- `git cat-file -e HEAD:.coord/protocols/role-skill-TEMPLATE.md` etc. for each file.
- `git status --short` -> spine files no longer `M`.
- Journal (Python+fsync): `<UTC> | <slug> | docs: spine committed <hash> on v2-backend (lesson-routing + 2 folds + role-coordinator §B + L-RTM-BUILD-01)`.
- §0.7 re-sync committed files from HEAD; `sync`. NO push.

## REPORT -> inbox/coordinator.md: commit hash, files committed (with line counts), markers verified in the committed blob, branch v2-backend, NO push. Then devops Phase-2 may run (curator FORM-reviews this commit).
