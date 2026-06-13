# CC Task — B2 quote-safe psql (fix PowerShell -c quote-stripping) + scan orchestrator for same vuln

> Coordinator 13:25Z: 45 is GREEN (cascade 42703/42883/42809 resolved). REMAINING non-fatal: Phase-5c B2 UPDATE fails because
> `& $psql ... -c $updateSql` — PowerShell strips the embedded `"` when passing to native psql.exe -> psql sees `WHERE TenantId`
> (unquoted) -> folds to tenantid -> 42703. Source L841 IS correctly quoted; the `-c` native-arg boundary is the bug.
> FIX: make the B2 UPDATE quote-safe (write SQL to a temp .sql -> `psql -f`), and scan for any other `& $psql ... -c "<...quotes...>"`.
> deploy: commit, NO push. Non-fatal (relay-URL set via UI meanwhile). Native Windows (CC). POST-GREEN hardening — no 45 re-deploy required.

## 0. Integrity (PD-007) — restore deploy/ from HEAD (native git)
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path ".git\index.lock") { Remove-Item ".git\index.lock" -Force -ErrorAction SilentlyContinue }
git checkout HEAD -- deploy/
$w="deploy\Apply-Server45Upgrade.ps1"
if (((Get-Content $w -ErrorAction SilentlyContinue)|Measure-Object -Line).Lines -lt 200){ git show "HEAD:deploy/Apply-Server45Upgrade.ps1" | Set-Content $w -Encoding UTF8 }
"deploy file lines: $((Get-Content $w|Measure-Object -Line).Lines)"

## 1. FIX B2 — replace the `-c $updateSql` call with a temp-file `-f` call (quote-safe)
# Locate the B2 block (Phase 5c, '# B2 — Update tenant_settings.SignalRConnectionUrl to loopback'). The UPDATE is built into
# $updateSql (L~841, already quoted: SET `"SignalRConnectionUrl`" ... WHERE `"TenantId`"). The execution is `& $psql ... -c $updateSql`.
# Convert: write $updateSql to a temp .sql file (UTF-8, no BOM — psql -f reads UTF8) then run `& $psql ... -f $tmpSql`, then remove temp.
# Concretely, in the B2 execution block:
#   $tmpB2 = [System.IO.Path]::GetTempFileName(); $tmpB2 = [System.IO.Path]::ChangeExtension($tmpB2,'.sql')
#   [System.IO.File]::WriteAllText($tmpB2, $updateSql, (New-Object System.Text.UTF8Encoding($false)))   # no BOM for psql -f
#   $updateOutput = & $psql -h $DBHost -p $DBPort -U $DBUser -d $Database -v ON_ERROR_STOP=1 -f $tmpB2 2>&1
#   $updateExitCode = $LASTEXITCODE
#   Remove-Item $tmpB2 -ErrorAction SilentlyContinue
# Keep the surrounding $env:PGPASSWORD set, $ErrorActionPreference=Continue/restore, exit-code check, and Ledger lines UNCHANGED.
# Match the EXACT psql arg pattern already used in this file (host/port/user/db flags) — mirror the OTHER psql calls in the script,
# only swapping `-c $updateSql` for `-f $tmpB2`. Do NOT change the SQL text (it stays quoted in $updateSql -> written verbatim to file).

## 2. SCAN for the same vuln — any other native psql `-c` with embedded double-quotes
$hits = Select-String -Path $w -Pattern '\$psql[^\r\n]*-c\s' | Where-Object { $_.Line -match '`"' -or $_.Line -match '\\"' }
if ($hits) { "⚠ OTHER `-c` psql calls with embedded quotes (convert to -f too, or flag):"; $hits | ForEach-Object { "  L$($_.LineNumber): $($_.Line.Trim())" } }
else { "No other `& \$psql ... -c \"<quotes>\"` patterns. (-f calls are quote-safe.)" }
# If step-2 finds additional embedded-quote -c calls, apply the same temp-file -f conversion to each (or, if low-risk/no quotes, leave).

## 3. Self-tests + commit (deploy:, BOM §35, NO push)
$null=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $w),[ref]$null,[ref]$e=$null); if($e){throw "parse errors after edit."}
# B2 must no longer use -c for $updateSql; must use -f $tmpB2:
$t=Get-Content $w -Raw
if ($t -match '-c\s+\$updateSql') { throw "B2 still uses -c \$updateSql — conversion incomplete." }
if ($t -notmatch '-f\s+\$tmpB2') { throw "B2 -f \$tmpB2 not present." }
# BOM preserved:
$b=[System.IO.File]::ReadAllBytes((Resolve-Path $w))[0..2]; if(-not($b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF)){ [System.IO.File]::WriteAllText((Resolve-Path $w),$t,(New-Object System.Text.UTF8Encoding($true))) }
bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1   # or §0.5 inline checks
git add deploy/Apply-Server45Upgrade.ps1
git commit -m "deploy: B2 quote-safe psql -f tempfile (PowerShell -c strips embedded quotes -> 42703) + scan psql -c calls"
git rev-parse HEAD

## 4. cc-binding (NORM-CUR-07) -> append RESULT to .coord/cc/devops.md (Python+os.fsync, append)
  ## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_b2_quotesafe_psql.md | status: done
  ### RESULT (by CC): commit <hash> deploy: B2 -c->-f tempfile ; parse OK ; -c $updateSql removed, -f $tmpB2 present ; other -c-with-quotes: <none|list> ; BOM ok. NO push.

## Report (chat)
commit hash ; B2 now -f tempfile (quote-safe) ; other -c-with-embedded-quotes found = <none|list+converted> ; parse+BOM OK. NO push.
NOTE: 45 is already GREEN; B2 relay-URL set via UI meanwhile. This fix rides the push barrier / next package — NO 45 re-deploy needed now.
