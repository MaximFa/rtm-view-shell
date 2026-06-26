# CC task — RESTORE §42.7 Per-change QA + regression block (reverted by 9c6ac0e collateral)
> Coordinator-authored (IRON #9 exception: coordinator owns CLAUDE.md). Executor: native CC. Branch **v3**. Commit `docs:`. **NO push** (§37).
> WHY: commit 9c6ac0e (devops SF-SOMA-001 db fix) ALSO swept a STALE CLAUDE.md and REVERTED f80840c's "Per-change QA + standing pre-push regression" §42.7 block (cross-session stale-clobber, L-SC-09; CLAUDE.md was outside that task's claim). The db fix itself is correct — do NOT revert 9c6ac0e. This task RE-ADDS the lost block forward, on top of HEAD.

## INIT — branch v3 + integrity
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 (object-store, not mount status §0.5). HEAD should be 9c6ac0e (or later).
- §0.2 integrity. §0.3 Python read/modify/write + os.fsync; after write: sync + tail -3 + wc -l + NUL-check (0).
- CONFIRM the block is actually missing FIRST: `grep -c "Per-change QA + standing pre-push regression" CLAUDE.md` must be 0. If it is 1 -> someone restored it; STOP, report, do nothing.

## §42.6 sync — slug coordinator-0623 (file-mode)
- S1: `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (current = CLOSED tombstone -> proceed).
- S2 claims (file-mode): `CLAUDE.md` ONLY.
- S3 commit.lock (owner coordinator-0623). §0.6b binding PRE/POST -> .coord/cc/coordinator.md. NO push.

## EDIT — re-insert the block into §42.7 (before the Doc-sync gate)
Python read CLAUDE.md. Anchor (unique, =1): the doc-sync gate header line:
```
**Doc-sync gate (mandatory in every push-barrier quorum):**
```
INSERT the following block IMMEDIATELY BEFORE that anchor (one blank line before and after), via `text.replace(anchor, NEW_BLOCK + "\n\n" + anchor, 1)`:

```
**Per-change QA + standing pre-push regression (norm 2026-06-23):**

QA verification is not only a barrier gate — it is CONTINUOUS: (1) EVERY change / fix / addition gets IMMEDIATE QA verification right after it lands (per-change functional check by `test` — object-store + a live run + a clean log), NOT deferred to the barrier; (2) before EVERY push, `test` runs the standing pre-push REGRESSION over UI + DB (Dashboards + Historical Reports) per `testing/regression_checklist.md` and emits ONE consolidated GREEN/HOLD. The barrier's QA quorum ack = that CONSOLIDATED regression GREEN (NOT the sum of piecemeal per-feature checks). The checklist is versioned and carries an explicit regression guard for every closed defect (e.g. F-QA-1/5/6) so none can silently regress.
```

## VERIFY (before commit)
- `grep -c "Per-change QA + standing pre-push regression" CLAUDE.md` = 1; `grep -c "Functional/QA gate (mandatory" CLAUDE.md` = 1 (970e390 block still intact); the Doc-sync anchor still present once right after.
- `git diff --name-only` = `CLAUDE.md` ONLY. tail -3 proper EOF; 0 NUL.

## Commit (docs:, commit.lock, NO push)
`bash tools/pre-commit-check.sh CLAUDE.md` -> `git add CLAUDE.md` (ONLY — narrow) -> commit -m "docs: restore §42.7 per-change QA + regression block (reverted by 9c6ac0e stale-CLAUDE clobber) [coordinator-0623]" -> §0.6 post-commit (`git show v3:CLAUDE.md | grep -c "Per-change QA + standing pre-push regression"` = 1) -> `bash tools/cc_post_commit.sh coordinator-0623 <hash>` -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/coordinator.md (done): commit <hash>; §42.7 per-change block restored (grep=1); Functional/QA gate intact (grep=1); 1 file; NO push. verified: object-store.
## Report (chat): commit hash; confirm grep=1 + 1 file; NO push.
