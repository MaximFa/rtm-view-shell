# CC task — DEVOPS: Update-RTMView preserve appsettings.json (Shell config clobber fix) — pre-45 hardening
> §4-PASS coordinator-0612 2026-06-19T08:58:15Z. Owner devops-0619. Commit `deploy:`. NO push. Surgical, logic otherwise unchanged.
> INCIDENT (234, today): Shell crashed on start — 28P01 password auth failed for ccdashboard_user. ROOT: Update-RTMView Shell
> $preserveFiles = @("appsettings.Production.json","nlog.config") MISSES appsettings.json. On 234 the live connection string
> lives in appsettings.json -> deploy overwrote it with the package default -> Shell couldn't connect. Operator recovered by
> restoring appsettings.json from the deploy backup. This WILL recur on 45 unless fixed. This is a "bake-all-lessons" pre-45 fix.

## INIT + discipline
- §0.2/§0.5 object-store (mount lies). §0.3 Python+fsync for .coord. Binding PREAMBLE -> .coord/cc/devops.md. commit.lock around commit. NO push (§37).
- CONFIRM FIRST (object-store) that HEAD deploy/Update-RTMView.ps1 still carries today's 3 fixes — @() wraps ($allBackups+$migrations), BOM (head -c3 ef bb bf), DB-apply (-MigrationList/pg_dump/ON_ERROR_STOP). This edit must NOT regress them.

## THE FIX (deploy/Update-RTMView.ps1) — Shell preserve list
Find the Shell deploy block `$preserveFiles = @("appsettings.Production.json", "nlog.config")` (~L139) and change to:
  `$preserveFiles = @("appsettings.json", "appsettings.Production.json", "nlog.config")`
Rationale: preserve the operator's live Shell config (conn string + secrets) across binary updates, same as Production.json is already preserved. Logic otherwise UNCHANGED. (RTM block already preserves appsettings.json+data.sys — leave it.)
OPTIONAL (only if trivial + low-risk): after Shell copy, if a preserved appsettings.json is restored, print `Preserved: appsettings.json` so the deploy log shows it (parity with current preserve echoes). Don't over-engineer.

## RE-ENCODE + VERIFY (§35 — file MUST stay UTF-8 BOM + CRLF)
- Python: read text, apply the one-line preserve replacement, normalize CRLF, prepend BOM b"\xef\xbb\xbf", binary write + fsync.
- VERIFY (object-store/xxd): head -c3 == ef bb bf; CRLF==line-count; last line `Write-Host ""`; the preserve line now lists appsettings.json; the 3 prior fixes still present (@() x2, -MigrationList, pg_dump, ON_ERROR_STOP). PS parse: native-Windows only (note if on mount).

## COMMIT (deploy:, NO push) under commit.lock
`deploy: Update-RTMView preserve Shell appsettings.json (was clobbered -> 28P01 on 234; preserve operator live config across binary update) [devops]`
then §0.6 post-commit (HEAD blob head -c3 ef bb bf via xxd) + §0.7 re-sync + sync.

## OVERWRITE staged pkg copy (so BOTH 234-future and 45 use the lesson-complete script)
`copy /Y deploy\Update-RTMView.ps1 Installations\234_b58e2c2_19062026_Full\Update-RTMView.ps1` then verify head -c3 ef bb bf + preserve line + all fixes present.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash; preserve line confirmed (object-store); 3 prior fixes intact; BOM/CRLF; pkg copy overwritten. NO push.
