# CC task — PUSH v3 batch (rejects fix pack) — AFTER quorum GREEN only

## Git push
Push IS allowed in THIS prompt (origin v3 only). Runs ONLY after the §42.7 quorum is GREEN
(QA + Security + TechWriter + DBA acks present in .coord/push/acks/). Do NOT Export-All, do NOT
broad `git add` — every commit is already made; this is a pure fast-forward push.

## Step 0 — integrity + preflight
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD            # MUST be v3
git rev-parse v3; git rev-parse origin/v3  # v3=adbf5d7 ; origin/v3=26d6d9e
git status --short                          # working tree: no staged content; ?? ops-output OK
# confirm the 4 commits are the exact unpushed set:
git log --oneline origin/v3..v3
# EXPECTED (4): adbf5d7, 8b285eb, 9648c09, b81ccb5
sync
```
If origin/v3..v3 != exactly {adbf5d7,8b285eb,9648c09,b81ccb5} → STOP, report to coordinator.

## Step 1 — fast-forward push
```bash
git push origin v3
```
If rejected (origin moved): STOP — do NOT force. Report to coordinator (no rebase without a §4 call).

## Step 2 — verify + journal + cleanup barrier
```bash
git rev-parse origin/v3            # MUST now == adbf5d7
git log --oneline -6 origin/v3
```
- Append journal (Python+fsync): `<UTC> | coordinator-0703 | PUSHED 26d6d9e..adbf5d7 (4 commits: WIDGET-STICK x2 + ASD-B + db-tools)`
- Set .coord/push/request.md status: PUSHED (Python+fsync); leave acks/ as historical.

## Step 3 — re-sync (§0.7 PD-007)
```bash
git show origin/v3:src/CcDashboard.Web/wwwroot/js/widget-resize.js > src/CcDashboard.Web/wwwroot/js/widget-resize.js
sync
```
Report: `git log --oneline -6 origin/v3` + `git status --short`.
