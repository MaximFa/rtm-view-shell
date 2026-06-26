# CC task — v3 codify QA functional gate (CLAUDE.md §42.7) + role-coordinator §B — coordinator-domain docs
> Coordinator-authored (IRON #9 exception: coordinator owns CLAUDE.md / role-coordinator / push prompts). Executor: native CC. Branch: **v3**. Commit `docs:`. **NO push** (§37).
> WHY: v3 shipped to origin/v3 (2026-06-22) on a PROCESS-only quorum with NO functional gate — latent migration+seed defects surfaced at first clean stand-up. QA (test-5-0607) had been acking barriers as 'stake-clear/non-gating' = a gate demoted to a formality. Codify: QA ack = MANDATORY functional gate, peer of security/techwriter. Retire the stale 'no QA role' framing.

## INIT — branch v3 + skills + integrity
- **BRANCH:** `git checkout v3`; verify `git rev-parse --abbrev-ref HEAD`=v3 + `git rev-parse v3` (OBJECT-STORE, never mount `git status`). Do NOT cross to v2-backend.
- §0.2 integrity: `cat .git/HEAD`=`ref: refs/heads/v3`. Mount may fail `git rev-parse HEAD` (L-SC-04) — verify natively, do NOT escalate as corruption.
- §40 / role read: `.claude/skills/session-coord/session-coord.md` (§42.7 push barrier, L-SC-01/02/29) + `.claude/skills/role-coordinator/role-coordinator.md` §A.
- §0.3 Edit BANNED — Python read/modify/write + os.fsync; after each write `sync` + `tail -3` + `wc -l` + NUL-check (python `b'\x00' in open(p,'rb').read()`). NUL-pad → restore-from-HEAD + re-apply.

## §42.6 sync — slug coordinator-0623 (file-mode)
- S1 barrier: `cat .coord/push/request.md` — STOP only if it contains the literal `FREEZE ACTIVE` as an OPEN barrier (a CLOSED tombstone reads `No FREEZE ACTIVE` — read the FULL line; current state = CLOSED → proceed).
- S2 claims (file-mode, coordinator/docs territory): `CLAUDE.md`, `.claude/skills/role-coordinator/role-coordinator.md`. Touch NOTHING else.
- S3 commit.lock (owner coordinator-0623) around git add/commit, retry 5×60s, never auto-delete a lock you don't own. S4 `bash tools/cc_post_commit.sh coordinator-0623 <hash>`. S5 **NO push**.
- §0.6b binding PREAMBLE/POSTAMBLE → `.coord/cc/coordinator.md`.

## EDIT 1 — CLAUDE.md §42.7: insert the Functional/QA gate block
Python read CLAUDE.md. Anchor (unique, inside §42.7) — the line that begins the doc-sync gate:
```
**Doc-sync gate (mandatory in every push-barrier quorum):**
```
INSERT the following block IMMEDIATELY BEFORE that anchor line (keep one blank line before and after). Use `text.replace(anchor, NEW_BLOCK + "\n\n" + anchor, 1)` so it inserts once:

```
**Functional/QA gate (mandatory in every push-barrier quorum) [norm 2026-06-23]:**

QA — the `test` session (test-5-0607) — is a MANDATORY quorum ack, a PEER of Security and the Doc-sync gate, NEVER logged as 'stake-clear / non-gating'. The push barrier is NOT complete without QA's READY/GREEN or HOLD. QA's ack means **functionally verified**, not a diff-read: for any commit touching code / schema / migration the Definition-of-Done is (a) unit tests GREEN, (b) fresh-DB migrate clean (no latent migration/seed defect), (c) smoke — the app starts AND the key user path works (e.g. /reports renders seeded rows; the To-day incl. today is shown). 'No defect visible in the diff' is NOT a QA ack — object-store/code verification is necessary but NOT sufficient. The stale 'no QA role' assumption is RETIRED: `test` is the standing functional-gate owner.

(Origin: v3 was pushed to origin/v3 on 2026-06-22 with no functional gate; malformed migrations + seed bugs surfaced expensively at first clean stand-up. QA had been acking barriers as 'stake-clear' — a gate demoted to a formality. On 2026-06-23 the functional gate then caught a real off-by-one (exclusive To-date dropping today's data, 640→735) that the object-store code-review had missed — proof the gate is load-bearing.)
```

VERIFY edit 1: `grep -n "Functional/QA gate (mandatory" CLAUDE.md` = exactly 1; the anchor line still present once right after; §42.7 still intact (`grep -c "§42.7" CLAUDE.md` unchanged).

## EDIT 2 — role-coordinator §B: append the 2026-06-23 lesson
Python read `.claude/skills/role-coordinator/role-coordinator.md`.
INTEGRITY PRE-CHECK (the WT file carries uncommitted §B lessons from coordinator-0622 — do NOT lose them): confirm it contains `2026-06-22 · Ran the v3 push barrier on a PROCESS-only quorum`. If MISSING → file was truncated by the mount → STOP and flag coordinator (do NOT commit a truncated role-skill; HEAD lacks these lessons so no clean restore — coordinator re-supplies).
Anchor (unique) — the §C header line:
```
## §C VERIFY  (run at init
```
INSERT the following single line IMMEDIATELY BEFORE that anchor (as the last line of §B), with a trailing newline, via `text.replace(anchor, NEW_LINE + "\n" + anchor, 1)`:
```
- 2026-06-23 · v3 /reports zero-data: object-store code-review (DBA) nailed the root (DateTime.Kind→timestamptz Npgsql throw + a SILENT bare catch), but it was the FUNCTIONAL QA gate (test, live UI=DB) that caught a SECOND real bug the diff-read missed — an exclusive To-date dropping today's rows (640→735). RULE: code/object-store verify is necessary but NOT sufficient; the functional QA gate is load-bearing and catches correctness bugs invisible to a diff. Never push on the code-floor alone; QA ack = mandatory functional gate (peer security/techwriter), never 'stake-clear'. · SOURCE: 9c63ba4/152b074, test verdicts 2026-06-23 · status: active
```
VERIFY edit 2: `grep -c "2026-06-23 · v3 /reports zero-data" role-coordinator.md` = 1; the 2026-06-22 lesson still present; `## §C VERIFY` still present once; `## §A CORE` + `## §B LESSONS` intact.

## VERIFY (before commit)
- `git diff --name-only` = EXACTLY `CLAUDE.md` + `.claude/skills/role-coordinator/role-coordinator.md` (no other file).
- Both files: `tail -3` ends on a proper line; no NUL bytes.
- pre-commit-check passes (no >10% shrink).

## Commit (docs:, NO push) under commit.lock
`bash tools/pre-commit-check.sh CLAUDE.md .claude/skills/role-coordinator/role-coordinator.md`
→ git add CLAUDE.md + `git add -f .claude/skills/role-coordinator/role-coordinator.md` (`.claude/` is .gitignored — MUST use -f)
→ commit -m "docs: codify QA functional gate in §42.7 (mandatory quorum peer; retire 'no QA/stake-clear') + role-coordinator §B [coordinator-0623]"
→ §0.6 post-commit (`git show v3:CLAUDE.md | grep -c "Functional/QA gate (mandatory"` =1; `git show v3:.claude/skills/role-coordinator/role-coordinator.md | grep -c "2026-06-23 · v3 /reports"` =1)
→ `bash tools/cc_post_commit.sh coordinator-0623 <hash>` (journal + lock release)
→ PD-007 re-sync both files from HEAD → `sync`.

## Binding RESULT → .coord/cc/coordinator.md (done): commit <hash>; CLAUDE.md §42.7 QA-gate block inserted (grep=1); role-coordinator §B +1 lesson (2026-06-23); 2 files only; pre-commit PASS; NO push. verified: object-store (git show v3:).

## Report (chat): commit hash; the 2 edits via git show v3; confirm only 2 files changed; NO push.
