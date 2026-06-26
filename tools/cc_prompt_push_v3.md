# CC task — V3 PUSH BARRIER (native CC) — pushes origin/v3 ONLY

> Owner: coordinator-0622. THE push task (§37 — the ONLY prompt allowed to `git push`). NATIVE CC.
> Quorum 7/7 READY (.coord/push/ACKS.md). Frozen set: origin/v3 0996a91..v3 243e4a4 = 5 commits.
> ⚠ This pushes **v3** (reports line) — NOT v2/v2-backend. Do NOT reuse the v2 push prompts.

## PRE-FLIGHT — STOP on ANY mismatch (report to inbox/coordinator.md)
1. `cat .git/HEAD` == `ref: refs/heads/v3`.
2. `git rev-parse v3`        == 243e4a4...
   `git rev-parse origin/v3` == 0996a91...
   `git log --oneline origin/v3..v3` == EXACTLY 5: 243e4a4, 6ea3e6c, 0bd52c0, 62a8759, 53aa308.
3. FF-safe: `git merge-base --is-ancestor origin/v3 v3` -> true (NO force-push; if false STOP).
4. Quorum: `.coord/push/ACKS.md` shows "QUORUM COMPLETE 7/7" + no HOLD.
5. L-SC-29: do NOT `git add` anything. Commit-only push — the 5 commits are already committed.
   Uncommitted WT (Garnet PoC artifacts, spine edits) MUST NOT ride — a plain `git push` cannot include them; do NOT stage them.
6. NO Export-All. No secrets. If `.git/index.lock` phantom exists it does NOT block push (push is a ref op, no index) — proceed.

## PUSH (the ONLY git-write)
```
git push origin v3
```
- If rejected (non-FF): do NOT force. STOP and report (someone advanced origin/v3).

## POST-PUSH VERIFY (object-store)
- `git rev-parse origin/v3` == 243e4a4 (== local v3).
- `git log --oneline origin/v3..v3` == 0 (nothing left unpushed).
- `git ls-remote origin v3` tip == 243e4a4.

## JOURNAL + CLEANUP
- Append to `.coord/journal.md` (Python+fsync): `<UTC> | coordinator-0622 | PUSHED origin/v3 0996a91..243e4a4 (5 commits: SF-BI-001 53aa308, role-bi 62a8759, step-0 0bd52c0, carve 6ea3e6c, Track B UI 243e4a4)`.
- Remove barrier files (best-effort; mount may phantom — coordinator clears residue): `.coord/push/request.md`, `.coord/push/ACKS.md`. If `rm` = "Operation not permitted" (mount), leave for Windows-side; report so.
- §0.7 re-sync committed files from HEAD if PD-007 truncates; `sync`.

## REPORT -> inbox/coordinator.md: old origin/v3 (0996a91) -> new (243e4a4), 5 commits pushed, post-push count 0, barrier files cleared (or residue flagged). NO other branch pushed.
