# Task: REVERT ad73870 — remove the MAXWAIT diag log-only instrumentation (RTM)

> Operator chose path A: revert the throwaway MAXWAIT diagnostic BEFORE the push barrier. The 140 capture
> is DONE. Remove ONLY the guarded `AsyncLogger.Info("MAXWAIT-...")` log lines that ad73870 added — nothing
> else. Clean inverse. Lands on v3 so the barrier manifest includes diag+revert (net-clean, no history rewrite).
> Territory: **rtm**. NO `git push`. Commit prefix: `rtm:`.

---

## STEP 0 — MANDATORY integrity check (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED: $f"; else echo "OK: $f ($WT_LINES)"; fi
done
sync; echo "=== integrity complete ==="
```

## STEP 1 — MANDATORY reads (§40 + §0.8)
```
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-backend/role-backend.md   (§A CORE + §C VERIFY)
```

## STEP 2 — BINDING preamble (§0.6b) — append to `.coord/cc/backend.md` via Python+fsync
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_revert_maxwait_diag.md | status: open
### DIRECTIVE: revert ad73870 (MAXWAIT diag log-only). Claims: RTM/RTM/Engine.cs, RTM/RTM/Union.cs. Prefix rtm:.
```

## STEP 3 — SYNC block (§42.6): slug `backend-0626`, claim `rtm`. Abort if `.coord/push/request.md` exists. commit.lock around the commit. Journal + lock-release after. NO push (§37).

---

## THE REVERT

ad73870 was a pure additive commit (+10 lines): 4 guarded `AsyncLogger.Info("MAXWAIT-...")` log statements —
Engine.cs (STREAM ~line 921, REFRESH-ENTER ~1388, REFRESH ~1414) + Union.cs (RECOMPUTE ~385). It is the
TIP commit for those files (no later change). So a clean inverse:

### Primary path — git revert (cleanest inverse)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git revert --no-commit ad73870
```
Then VERIFY the tags are gone (hard gate):
```bash
grep -c 'MAXWAIT-' RTM/RTM/Engine.cs RTM/RTM.Tools/*.cs RTM/RTM/Union.cs
# EVERY file must report 0. If any > 0 -> revert incomplete, do NOT commit.
```

### Fallback path — if `git revert` conflicts on this mount
Remove ONLY the 4 guarded MAXWAIT log statements via an atomic Python read→replace→write (§0.3, os.fsync),
one per site. Each is a self-contained `try { AsyncLogger.Info($"MAXWAIT-...`...`); } catch { }` (Sites 1/2/3a/3b
per ad73870) — delete the whole guarded statement, restore the surrounding code to its pre-ad73870 form
(i.e. `git show ad73870^:RTM/RTM/Engine.cs` and `git show ad73870^:RTM/RTM/Union.cs` are the exact targets).
Simplest deterministic fallback: `git show ad73870^:RTM/RTM/Engine.cs > RTM/RTM/Engine.cs` and
`git show ad73870^:RTM/RTM/Union.cs > RTM/RTM/Union.cs` (ONLY valid because ad73870 is the tip for these
files — confirm `git log --oneline -1 -- RTM/RTM/Engine.cs RTM/RTM/Union.cs` == ad73870 first). Then the
same grep==0 verify.

> Touch ONLY Engine.cs + Union.cs. No other file. No logic change beyond removing the 4 log lines.

## STEP 4 — build0
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build RTM/RTM/RTM.csproj -c Release 2>&1 | tail -20
```
Must be Build succeeded, 0 errors.

## STEP 5 — grep gate (MANDATORY before commit)
```bash
grep -c 'MAXWAIT-' RTM/RTM/Engine.cs RTM/RTM.Tools/*.cs RTM/RTM/Union.cs
# ALL must be 0. If not -> STOP, do not commit.
```

## STEP 6 — pre-commit + commit (rtm:) — NO PUSH
```bash
bash tools/pre-commit-check.sh RTM/RTM/Engine.cs RTM/RTM/Union.cs
# exit 0 required. commit.lock (§42.4). Message:
#   rtm: revert MAXWAIT diag log-only (ad73870) — 140 capture complete
```
Post-commit: §0.6 verify (git status clean, git show HEAD:<f> | wc -l matches), journal append, lock release, §0.7 re-sync of Engine.cs + Union.cs from HEAD.

## STEP 7 — BINDING postamble (§0.6b): write RESULT into `.coord/cc/backend.md`
```
### RESULT: commit <hash> . build succeeded 0-err . grep MAXWAIT- == 0 all files . files RTM/RTM/Engine.cs (-7), RTM/RTM/Union.cs (-3) . status done . blockers none . verified: object-store
```

## Acceptance criteria
- [ ] Only Engine.cs + Union.cs changed; ONLY the 4 MAXWAIT log lines removed (net -10 vs ad73870, back to ad73870^ for those files).
- [ ] `grep -c 'MAXWAIT-'` == 0 in Engine.cs, RTM.Tools/*.cs, Union.cs.
- [ ] `dotnet build RTM/RTM` = Build succeeded, 0 errors.
- [ ] Commit prefix `rtm:` with the exact message; NO push; working tree clean vs HEAD after.
- [ ] Binding RESULT written, object-store verified. Report the revert commit hash.

## Git push
Do NOT run `git push`. Commit only. The push barrier handles origin separately.
