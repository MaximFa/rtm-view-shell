# CC task — PUSH v3 Part B (RTM pipe-name 116416c) — AFTER quorum GREEN only
## Git push
Push allowed HERE only (origin v3), after 4/4 acks. NO Export-All/broad-add — 1-commit fast-forward.
## Step 0
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse v3; git rev-parse origin/v3     # v3=116416c ; origin=7ae4507
git log --oneline origin/v3..v3               # EXPECTED (1): 116416c
[ "$(git hash-object RTM/RTM.Configuration/AppConfig.cs)" = "$(git rev-parse HEAD:RTM/RTM.Configuration/AppConfig.cs)" ] && echo "AppConfig OK" || git show HEAD:RTM/RTM.Configuration/AppConfig.cs > RTM/RTM.Configuration/AppConfig.cs
sync
```
If origin/v3..v3 != {116416c} → STOP.
## Step 1
```bash
git push origin v3
```
Rejected → STOP, no force, report.
## Step 2
```bash
git rev-parse origin/v3    # == 116416c
```
journal PUSHED line (Python+fsync); request.md → PUSHED.
## Step 3 re-sync (§0.7)
```bash
for f in RTM/RTM.Configuration/AppConfig.cs RTM/RTM/RTMAdapter.cs RTM/RTM/appsettings.json; do git show origin/v3:"$f" > "$f"; done
sync
```
Report git log -3 origin/v3 + status.
