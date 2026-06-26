# CC task — PUSH BARRIER #3 (dedicated push prompt — the ONLY prompt authorized to git push)

> Owner: native CC (operator-run; mount cannot push, L-SC-20). §42.7 quorum COMPLETE.
> Range: origin/v2-backend 5206633 .. HEAD 8bbee78 = 12 commits. Gate OPT-A MET (fresh rebuild zero-errors + B/C/F=0).
> Quorum: 9 READY incl mandatory Security-0620 + Techwriter doc-gate. Stale excluded (operator-confirmed): security-0609, test-5-0607.
> SAFETY: this pushes ALREADY-COMMITTED history only — NO new commit, NO git add, so the PD-007-truncated working tree
> (AppDbContext.cs -49) is IRRELEVANT to the push. Do NOT stage anything. Do NOT git add -A.

## STEP 0 — integrity / preflight (object-store, §0.5)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
test "$(git rev-parse origin/v2-backend)" = "5206633538ed929459ac8cd68c1d3e2d972c4652" || echo "WARN origin moved — STOP, reconcile"
git rev-parse HEAD            # expect 8bbee78...
git log --oneline origin/v2-backend..HEAD | wc -l   # expect 12
git rev-list origin/v2-backend..HEAD | tail -1      # oldest = c60229e (parent chain intact)
```
If origin advanced past 5206633 unexpectedly -> STOP, report (someone else pushed).

## STEP 1 — PUSH (the one authorized push; §37 dedicated)
```bash
git push origin v2-backend
```
No flags beyond this. No tags here (tag v2-server-verified-20260619 already pushed separately).

## STEP 2 — POST-PUSH VERIFY (object-store)
```bash
git fetch origin
git rev-parse origin/v2-backend     # MUST == 8bbee78 (local HEAD)
git log --oneline -1 origin/v2-backend
git log --oneline origin/v2-backend..HEAD | wc -l   # MUST == 0 (nothing unpushed)
```
If origin/v2-backend != 8bbee78 -> push did not land; report, do NOT cleanup.

## STEP 3 — WT hygiene (PD-007; native write persists, §0.7) — AFTER successful push only
Re-sync any PD-007-truncated tracked file from HEAD so the next session starts clean:
```bash
git show HEAD:src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs > src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs
# scan for other content-truncated tracked-M and restore from HEAD (hash-object vs HEAD); EOL-only noise = leave
sync
```

## STEP 4 — barrier cleanup + journal (after verified push)
```bash
# journal the PUSHED line
printf '%s | coordinator-0612 | PUSHED 5206633..8bbee78 (12 commits) to origin/v2-backend — barrier #3 (OPT-A gate). incident a/b + R0b-e + CC-HIST-001(+fix) + role-incident + RCA-ledger + ROLLBACK.md. code-Delivered (NOT server-verified). rollback anchor tag v2-server-verified-20260619 live.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> .coord/journal.md
# remove the barrier request + acks (FREEZE lifts). If rm "Operation not permitted" on mount -> flag for native rm; truncate instead:
rm -f .coord/push/request.md .coord/push/acks/*.md 2>/dev/null || { : > .coord/push/request.md; for f in .coord/push/acks/*.md; do : > "$f"; done; echo "NOTE: could not unlink — emptied; operator native rm"; }
sync
```

## REPORT -> inbox/coordinator.md: pushed range, origin/v2-backend new tip, unpushed=0, WT re-sync done, request/acks cleaned. FREEZE lifted.

## FOLLOW-UP (NOT in this push — separate docs: commit later): sweep the 2 protocol tracked-M
.coord/protocols/discipline-lessons.md + .coord/protocols/role-skill-standard.md (curator flag; missed #2). Author a small
explicit-add docs: commit (those 2 files ONLY) post-barrier; they ride #4.
