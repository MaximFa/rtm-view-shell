# tools/cc_prompt_role_coordinator_weed.md — weed role-coordinator §A (cap) + commit on v2-backend
> Authored by curator-0611 (§A-cap discipline + spine authority). Coordinator §4-APPROVES; operator runs native-CC FROM the curator session per IRON rule #9 (spine/skill commit → spec=curator authors). NO push (§0.6/§37).
> §4-PASS: coordinator-0622 2026-06-22T09:43:46Z — all 9 cardinals preserved as one-liners (substance intact) + detail->§D; IRON #9 + role-line correct; §B/§C/§D untouched; safety (precheck WT integrity, NO whole-file HEAD-restore since §B lives only in WT, STOP-on-truncate) sound; commits WT-M in same docs: commit; branch v2-backend, commit.lock, NO push. APPROVED — operator runs from curator session; curator FORM-reviews + reports.
> Reason: role-coordinator §A overflowed (~9 multi-line cardinals, > ~40-line cap). This terse-ifies §A to one-liners (substance preserved), relocates detail to §D, and commits the uncommitted WT-M (IRON rule #9 + S4 §B lessons).

## (0) INTEGRITY / branch
- §0.2/§0.5: `git status --short`; verify by OBJECT STORE.
- `git checkout v2-backend`; `git rev-parse --abbrev-ref HEAD` must == v2-backend.
- ⚠ The role-coordinator.md WT carries uncommitted content (IRON rule #9 in §A + §B lessons through 2026-06-22). §B/§C/§D content lives ONLY in the WT — do NOT restore the whole file from HEAD (that loses §B). Restore ONLY if a section is TRUNCATED (verify first).

## (1) PRECHECK — WT integrity (object-store/byte-aware, N5)
- Confirm role-coordinator.md WT ends properly (tail: §D "Role-creation procedure" block, proper EOF) and §B contains the latest lesson dated 2026-06-22 "IRON RULE (operator, PERMANENT) — dispatch workflow shape". byte/NUL-clean (no NUL padding).
- If TRUNCATED → STOP, report to curator (do not guess §B).

## (2) TASK — replace ONLY the §A block, keep §B/§C/§D as-is
Replace everything from the line `## §A CORE` up to (but NOT including) `## §B LESSONS` with the WEEDED §A below (Python+os.fsync; §0.3). Then ADD the relocated detail as a new subsection at the END of §D (before/after the Role-creation procedure block — either, keep both).

### WEEDED §A (verbatim replacement):
<<<A
## §A CORE  (invariant · HARD CAP ~40 lines · read EVERY init)
Role: Multi-session router/planner. Owns .coord/, CLAUDE.md, session-coord skill, task DISPATCH + §4-review. Does NOT write production code (§0.7); does NOT author non-push prompts (IRON #9 — the SPEC authors; coordinator authors ONLY push prompts).
**Reality wins — update me.** If §C VERIFY finds §A disagrees with the code/artifacts, the CODE is right; mark the line superseded.
Cardinal truths (source-pinned; detail in §D):
1. commit.lock acquire/release = CC-ONLY (Cowork mount can't unlink → orphan). · L-SC-02/§42.4
2. journal.md = convenience view; git log / object-store = truth (reconcile). · L-SC-04/§42.5
3. push-prompt preflight MANDATORY (branch-agnostic; 5 checks → §D). · L-SC-29
4. CC↔spec binding MANDATORY every CC prompt (PREAMBLE + RESULT → .coord/cc/<role>.md). · NORM-CUR-07c/§0.6b
5. Barrier: request.md FIRST (freeze) → acks AFTER. · L-SC-01/§42.7
6. .coord/ presence checks content-based (-s + cat), never -f (mount phantom dirents). · L-SC-10/14
7. Verify by object-store, not chat memory; tool-success ≠ delivery. · §0.1/NORM-CUR-13
8. MANDATORY Compare-ToBaseline before ANY deploy; never reuse a migration-list/memory. · 234+45 2026-06-19
9. IRON dispatch (operator, PERMANENT): coordinator DISPATCHES + §4-approves; SPEC authors prompt; operator runs from spec session; spec processes + reports. EXCEPTION: push = coordinator. · operator 2026-06-22

A

### §D ADDITION (relocated cardinal detail — append at end of §D):
<<<D
### §A cardinal details (relocated for cap)
- (1) commit.lock: a Cowork-acquired lock orphans forever (mount can't unlink). SOURCE 7cf83cb.
- (2) journal: CC-appended journal lines may vanish from the mount; reconcile against object-store. SOURCE 7cf83cb.
- (3) push preflight 5 checks: branch==declared(request.md); narrow explicit adds only; §0.2-restore truncated; no Export-All; no secrets. SOURCE b618a14.
- (8) Compare-ToBaseline: never apply migrations/binaries without FIRST running Compare against THAT server; each server's applied-set differs. SOURCE 234+45 2026-06-19.
- (9) IRON dispatch shape: (1) coordinator dispatches; (2) spec authors prompt; (3) coordinator §4-approves; (4) operator runs CC from the spec's session; (5) spec processes RESULT + reports. EXCEPTION push=coordinator. SOURCE operator 2026-06-22.
D

## (3) VERIFY (object-store, before commit)
- §A non-blank line count <= 40 (target ~14); 9 one-liner cardinals + role-line + caveat present.
- §B unchanged (lesson count same as WT; latest 2026-06-22 IRON lesson intact).
- §D has the relocated "§A cardinal details" subsection + the Role-creation procedure block.
- tail proper EOF; byte/NUL-clean.

## (4) COMMIT (native-CC, commit.lock, NO push)
git add -f .claude/skills/role-coordinator/role-coordinator.md
git commit -m "docs(skill): weed role-coordinator §A to cap (one-liners; detail->§D) + commit IRON dispatch #9 + S4 §B lessons [curator/NORM-CUR-11]"
Then §0.6a RESULT -> .coord/cc/coordinator.md ; journal ; release lock ; §0.7 re-sync ; NO push ; report hash.

## (5) REPORT BACK to curator (inbox/coordinator.md): commit hash + §A final line count + WT-integrity result.
