# CC task — PUSH v3 batch-2 (ASD polish) — AFTER quorum GREEN only

## Git push
Push IS allowed in THIS prompt (origin v3 only). Runs ONLY after §42.7 quorum GREEN (QA+Security+TechWriter+DBA in .coord/push/acks/). NO Export-All, NO broad add — pure fast-forward.

## Step 0 — integrity + preflight
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD            # v3
git rev-parse v3; git rev-parse origin/v3  # v3=12480b2 ; origin/v3=adbf5d7
git log --oneline origin/v3..v3            # EXPECTED (3): 12480b2, 21ecb84, 7a8a4a8
sync
```
If origin/v3..v3 != exactly {12480b2,21ecb84,7a8a4a8} → STOP, report.

## Step 1 — push
```bash
git push origin v3
```
If rejected (origin moved) → STOP, do NOT force, report to coordinator.

## Step 2 — verify + journal + close barrier
```bash
git rev-parse origin/v3     # MUST now == 12480b2
git log --oneline -5 origin/v3
```
- journal (Python+fsync): `<UTC> | coordinator-0703 | PUSHED adbf5d7..12480b2 (3 commits: ASD-BAR-BLUR + guard + recreate-test)`
- request.md status → PUSHED (Python+fsync); acks historical.

## Step 3 — re-sync (§0.7)
```bash
for f in src/CcDashboard.Web/wwwroot/js/agentStateDistributionChart.js src/CcDashboard.Web/wwwroot/js/daytrendChart.js src/CcDashboard.Web/wwwroot/js/reportDistributionChart.js; do
  git show origin/v3:"$f" > "$f"; done
sync
```
Report: `git log --oneline -5 origin/v3` + `git status --short`.
