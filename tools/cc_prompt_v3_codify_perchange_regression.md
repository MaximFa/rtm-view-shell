# CC task — §42.7 codify: per-change QA + standing pre-push regression (operator norm 2026-06-23)
> Coordinator-authored (IRON #9 exception: coordinator owns CLAUDE.md). Executor: native CC. Branch **v3**. Commit `docs:`. **NO push** (§37).
> WHY: operator norm 2026-06-23 — (1) every change gets IMMEDIATE per-change QA; (2) before EVERY push a standing UI+DB regression (Dashboards + Historical Reports). Extends the Functional/QA gate block (added in 970e390).

## INIT — branch v3 + integrity
- `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (object-store, never mount status §0.5).
- §0.2: `cat .git/HEAD`=`ref: refs/heads/v3`. Mount may fail rev-parse HEAD (L-SC-04) — verify natively, do not escalate.
- Read: .claude/skills/session-coord/session-coord.md (§42.7).
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; after write: sync + tail -3 + wc -l + NUL-check (0).

## §42.6 sync — slug coordinator-0623 (file-mode)
- S1: `cat .coord/push/request.md` — STOP only on an OPEN `FREEZE ACTIVE` (current = CLOSED tombstone -> proceed).
- S2 claims (file-mode): `CLAUDE.md` ONLY.
- S3 commit.lock (owner coordinator-0623) around add/commit, retry 5×60s. §0.6b binding PRE/POST -> .coord/cc/coordinator.md. NO push.

## EDIT — insert the per-change+regression clause into §42.7 (Functional/QA gate area)
Python read CLAUDE.md. Anchor (unique, =1 — verified): the doc-sync gate header line:
```
**Doc-sync gate (mandatory in every push-barrier quorum):**
```
INSERT the following block IMMEDIATELY BEFORE that anchor (one blank line before and after), via `text.replace(anchor, NEW_BLOCK + "\n\n" + anchor, 1)`:

```
**Per-change QA + standing pre-push regression (norm 2026-06-23):**

QA verification is not only a barrier gate — it is CONTINUOUS: (1) EVERY change / fix / addition gets IMMEDIATE QA verification right after it lands (per-change functional check by `test` — object-store + a live run + a clean log), NOT deferred to the barrier; (2) before EVERY push, `test` runs the standing pre-push REGRESSION over UI + DB (Dashboards + Historical Reports) per `testing/regression_checklist.md` and emits ONE consolidated GREEN/HOLD. The barrier's QA quorum ack = that CONSOLIDATED regression GREEN (NOT the sum of piecemeal per-feature checks). The checklist is versioned and carries an explicit regression guard for every closed defect (e.g. F-QA-1/5/6) so none can silently regress.
```

## VERIFY (before commit)
- `grep -c "Per-change QA + standing pre-push regression" CLAUDE.md` = 1; the doc-sync anchor still present once right after; `grep -c "Functional/QA gate (mandatory" CLAUDE.md` = 1 (block from 970e390 intact).
- `git diff --name-only` = `CLAUDE.md` ONLY. tail -3 proper EOF; 0 NUL.

## Commit (docs:, commit.lock, NO push)
`bash tools/pre-commit-check.sh CLAUDE.md` -> `git add CLAUDE.md` -> commit -m "docs: §42.7 codify per-change QA + standing pre-push regression norm (operator 2026-06-23) [coordinator-0623]" -> §0.6 post-commit (`git show v3:CLAUDE.md | grep -c "Per-change QA + standing pre-push regression"` = 1) -> `bash tools/cc_post_commit.sh coordinator-0623 <hash>` -> PD-007 re-sync -> sync.

## Binding RESULT -> .coord/cc/coordinator.md (done): commit <hash>; §42.7 per-change+regression clause inserted (grep=1); 1 file; NO push. verified: object-store.
## Report (chat): commit hash; the edit via git show v3; confirm 1 file; NO push.
