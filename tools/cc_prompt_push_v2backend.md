# CC task — V2-BACKEND PUSH BARRIER (native CC) — pushes origin/v2-backend ONLY
> coordinator-0622 authored (IRON #9 exception: coordinator authors PUSH prompts). THE push task (§37). NATIVE CC. Quorum COMPLETE.
> Frozen: origin/v2-backend 8bbee78..v2-backend 51daa8a = 7 commits. ⚠ mount truncates HEAD name to 'v2-' (§0.5) — verify HEAD==v2-backend NATIVELY.

## PRE-FLIGHT — STOP on ANY mismatch (report to inbox/coordinator.md)
1. `git checkout v2-backend` (if needed); `git rev-parse --abbrev-ref HEAD` == v2-backend (native, NOT mount).
2. `git rev-parse v2-backend` == 51daa8a... ; `git rev-parse origin/v2-backend` == 8bbee78...
   `git log --oneline origin/v2-backend..v2-backend` == EXACTLY 7: 51daa8a, f3368d8, 9ada3f0, bffa20c, 2a63f57, 83f4cf2, 5e9e22d.
3. FF-safe: `git merge-base --is-ancestor origin/v2-backend v2-backend` -> true. If false -> STOP (NO force).
4. Quorum: `.coord/push/ACKS.md` shows QUORUM COMPLETE (security+techwriter mandatory + devops+curator contributors), no HOLD.
5. L-SC-29: do NOT `git add` anything (commit-only push); NO Export-All; no secrets; §0.2-restore any truncated WT file from HEAD FIRST. Uncommitted WT (tools/cc_prompt_* tooling) cannot ride.
6. `.git/index.lock` phantom does NOT block push (ref op).

## PUSH (only git-write)
```
git push origin v2-backend
```
- Rejected (non-FF) -> do NOT force. STOP + report.

## POST-PUSH VERIFY (object-store)
```
git rev-parse origin/v2-backend            # == 51daa8a
git log --oneline origin/v2-backend..v2-backend | wc -l   # == 0
git ls-remote origin v2-backend            # tip == 51daa8a
```

## JOURNAL + CLEANUP (Python+fsync)
- Append `.coord/journal.md`: `<UTC> | coordinator-0622 | PUSHED origin/v2-backend 8bbee78..51daa8a (7 commits: Garnet PoC/eval + Phase-2 f3368d8 + spine bffa20c/9ada3f0 + weed 51daa8a)`.
- Close barrier: overwrite `.coord/push/request.md` + `.coord/push/ACKS.md` with a CLOSED marker (no "FREEZE ACTIVE" string; rm fails on mount). Best-effort clear `.coord/push/acks/*.md`.
- §0.7 re-sync; sync. NO push beyond this one.

## REPORT -> inbox/coordinator.md: old(8bbee78)->new(51daa8a) origin tip, 7 commits pushed, post-push count 0, barrier closed. NO other branch pushed.
