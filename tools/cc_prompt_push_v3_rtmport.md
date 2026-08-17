# CC task — PUSH v3 (PORT-2026-07-10-A RTM UserManager) — AFTER quorum GREEN only

## Git push
Push IS allowed in THIS prompt (origin v3 only). Runs ONLY after §42.7 quorum GREEN (4/4 in .coord/push/acks/). NO Export-All, NO broad add — pure fast-forward of ONE commit.

## Step 0 — integrity + preflight
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD            # v3
git rev-parse v3; git rev-parse origin/v3  # v3=7ae4507 ; origin/v3=12480b2
git log --oneline origin/v3..v3            # EXPECTED (1): 7ae4507
# hash-verify the ported file vs HEAD (PD-007 guard):
[ "$(git hash-object RTM/RTM/UserManager.cs)" = "$(git rev-parse HEAD:RTM/RTM/UserManager.cs)" ] && echo "WT==HEAD OK" || { echo "WT DRIFT — restore"; git show HEAD:RTM/RTM/UserManager.cs > RTM/RTM/UserManager.cs; }
sync
```
If origin/v3..v3 != exactly {7ae4507} → STOP, report.

## Step 1 — push
```bash
git push origin v3
```
If rejected (origin moved) → STOP, do NOT force, report to coordinator.

## Step 2 — verify + journal + close barrier
```bash
git rev-parse origin/v3     # MUST now == 7ae4507
git log --oneline -4 origin/v3
```
- journal (Python+fsync): `<UTC> | coordinator-0703 | PUSHED 12480b2..7ae4507 (1 commit: RTM UserManager legacy port PORT-2026-07-10-A)`
- request.md status → PUSHED (Python+fsync); acks historical.

## Step 3 — re-sync (§0.7 PD-007)
```bash
git show origin/v3:RTM/RTM/UserManager.cs > RTM/RTM/UserManager.cs
sync
```
Report: `git log --oneline -4 origin/v3` + `git status --short`.
