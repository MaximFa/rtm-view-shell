# CC Task — Apply-Server45Upgrade.ps1: preserve RTM log4net.config + app.dat (operator finding)

> Session devops-2-0607. The dotnet publish output publish\rtm\ CONTAINS log4net.config, so the orchestrator's
> Phase-3b binary copy (Copy-Item publish\* -Force) would OVERWRITE the server45-customised log4net.config and lose
> the operator's logging config. It must be preserved like data.sys / appsettings.json. One-line fix to the RTM
> preserve list. (Shell already preserves appsettings.Production.json/web.config/nlog.config — RTM list is missing
> log4net.config.)

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES-WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED"; else echo "OK: $f"; fi
done
sync; echo done
```
NOTE: deploy/Apply-Server45Upgrade.ps1 is UTF-8 WITH BOM (just fixed in 373ffd6) — PRESERVE the BOM on write
(read+write as UTF-8 BOM, do NOT strip it). Known false-M: db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY
Session slug: `devops-2-0607`
Claims: `deploy/Apply-Server45Upgrade.ps1`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo STOP; exit 1; fi
```
### S2. Claim
```bash
python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1
```
Modify ONLY deploy/Apply-Server45Upgrade.ps1.
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s. While holding:
`bash tools/pre-commit-check.sh` -> `git add deploy/Apply-Server45Upgrade.ps1`
-> `git commit -m "deploy: preserve RTM log4net.config on server45 upgrade (Phase 3b)"` -> §0.6 verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

## The fix (one line)
Find the RTM preserve list (around line 253):
```powershell
$rtmPreserve   = @("data.sys", "appsettings.json")
```
Change it to include log4net.config AND app.dat:
```powershell
$rtmPreserve   = @("data.sys", "appsettings.json", "log4net.config", "app.dat")
```
Rationale: publish\rtm ships dev copies of data.sys (320B) and app.dat (4B placeholder) + a default log4net.config;
all three would clobber the server's live versions without preservation. data.sys was already listed; add the
other two.
Do NOT change anything else. Preserve the file's UTF-8 BOM + CRLF.

## Self-test (Windows)
```powershell
$b=[System.IO.File]::ReadAllBytes("deploy\Apply-Server45Upgrade.ps1")[0..2]
"BOM=$($b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF)"            # must be True
$null=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "deploy\Apply-Server45Upgrade.ps1"),[ref]$null,[ref]$e); "parseErrors=$($e.Count)"  # must be 0
Select-String -Path deploy\Apply-Server45Upgrade.ps1 -Pattern 'log4net.config|app.dat'   # both in $rtmPreserve
```
BOM=True, parseErrors=0, log4net.config present in $rtmPreserve.

## Commit
ONE commit, prefix `deploy:`, message:
`deploy: preserve RTM log4net.config + app.dat on server45 upgrade (Phase 3b)`
Then S4 wrapper. NO push (§37).
