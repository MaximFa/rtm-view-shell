# CC task — DEVOPS: StrictMode scalar.Count crash in Update-RTMView.ps1 (234 deploy blocker)
> §4-PASS coordinator-0612 2026-06-19T08:20:07Z. Owner devops-0619. Commit `deploy:`. NO push. Surgical fix, logic otherwise unchanged.
> SYMPTOM (234, real run): after pg_dump succeeds -> "The property 'Count' cannot be found on this object ... PropertyNotFoundStrict".
> ROOT CAUSE: `Set-StrictMode -Version Latest` + `$allBackups = Get-ChildItem $BackupRoot -Directory | Sort-Object Name` returns a SCALAR DirectoryInfo when exactly ONE backup dir exists -> `$allBackups.Count` (L138) accesses a non-existent .Count on a scalar -> throw. Pre-existing bug (old script never reached it — died earlier on -MigrationList). Same hazard at `$migrations.Count` (L218) for a single-migration list.

## INIT + discipline
- §0.2/§0.5 object-store. §0.3 Python+fsync. Binding PREAMBLE -> .coord/cc/devops.md. commit.lock around commit. NO push.

## THE FIX (deploy/Update-RTMView.ps1) — wrap collection results in @() so .Count is always array-safe
1. L137: `$allBackups = Get-ChildItem $BackupRoot -Directory | Sort-Object Name`
   -> `$allBackups = @(Get-ChildItem $BackupRoot -Directory | Sort-Object Name)`
2. L~217: `$migrations = $MigrationList.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }`
   -> `$migrations = @($MigrationList.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })`
3. AUDIT the whole file for any other `.Count` / index `[0]` on a value sourced from Get-ChildItem / Sort-Object / Where-Object / .Split() pipelines under StrictMode -> wrap each in @(). (functionFiles/preserve hashtables are already literal arrays/@{} — fine; don't touch.) Logic otherwise UNCHANGED.

## RE-ENCODE + VERIFY (preserve §35 — file MUST stay UTF-8 BOM + CRLF)
- Write via Python: read current text, apply the two replacements, normalize CRLF, prepend BOM b"\xef\xbb\xbf", binary write + fsync.
- VERIFY: head -c3 == ef bb bf; CRLF==line-count; last line `Write-Host ""`; the two @() present (`git show`/grep); PowerShell parse clean ([Parser]::ParseFile — NOTE: native-Windows only; if on Linux mount, state "parse owed to operator").

## COMMIT (deploy:, NO push) under commit.lock
`deploy: Update-RTMView.ps1 StrictMode scalar.Count fix — wrap @() on $allBackups + $migrations (Get-ChildItem/Split single-item -> scalar -> .Count throws under StrictMode Latest) [devops]`
then §0.6 post-commit (head -c3 ef bb bf via xxd from HEAD blob) + §0.7 re-sync + sync.

## OVERWRITE staged pkg copy (swap-ready)
`copy /Y deploy\Update-RTMView.ps1 Installations\234_b58e2c2_19062026_Full\Update-RTMView.ps1` then verify head -c3 ef bb bf + the two @() present + lines.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md (or operator relay): commit hash; both @() confirmed object-store; BOM/CRLF confirmed; pkg copy overwritten. NO push.
