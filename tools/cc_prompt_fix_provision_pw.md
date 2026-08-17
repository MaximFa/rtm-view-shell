# CC task — SECURITY one-token fix: remove hardcoded DB password default from Provision-FreshDb.ps1
> §4-PASS (coordinator 2026-07-15) — 1-file, 1-line security fix; barrier-unblock (Security HOLD). RUN-CLEARED.
> Owner: devops. Branch v3. Commit `fix(deploy):`. NO push. Joins the active push barrier. ⛔ЧП.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-devops/role-devops.md

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble (.coord/cc/devops.md)
`## BINDING <UTC> | spec: devops | directive: tools/cc_prompt_fix_provision_pw.md | status: open`
`### DIRECTIVE: remove hardcoded DB password default from db/tools/Provision-FreshDb.ps1 (param-source like Install-RTMView). Claim: db/tools/Provision-FreshDb.ps1. fix(deploy):.`

## ROOT (Security HOLD, commit 0966263)
`db/tools/Provision-FreshDb.ps1:31` → `[string]$AppPassword = "!@#qweASDzxc"` hardcodes the REAL prod ccdashboard DB password in cleartext (SF-SEC-001, CODE-05/06). Fix = source it from the param with NO secret default, matching the existing `Install-RTMView.ps1` (88f4888) pattern (-DBAppPassword etc., no hardcode).

## CLAIM (touch ONLY this)
- db/tools/Provision-FreshDb.ps1

## CHANGE (one token, §0.3 Python+fsync)
Line 31: remove the hardcoded secret default. Use the SAME pattern Install-RTMView.ps1 already uses for its password params. Concretely, either:
- `[Parameter(Mandatory=$true)][string]$AppPassword`  (require it), OR
- `[string]$AppPassword = ""` + a fail-fast guard near the top: `if ([string]::IsNullOrWhiteSpace($AppPassword)) { Write-Error "AppPassword is required (pass -AppPassword)"; exit 1 }`.
Pick whichever MATCHES Install-RTMView.ps1's existing convention (read it first; keep the two consistent). Do NOT change any other logic/line. NO other file.

## CONSTRAINTS
- ONE file, the $AppPassword default only. No other change. Zero secret remains in the file (grep-verify: `!@#qweASDzxc` absent). No `git push`.
- §0.3 Python + os.fsync. After write: `sync; tail -3 <f>; wc -l <f>`.

## ACCEPTANCE
- grep `!@#qweASDzxc` in db/tools/Provision-FreshDb.ps1 → 0 hits.
- The param is sourced (Mandatory or fail-fast guard), consistent with Install-RTMView.ps1.
- pre-commit-check.sh green.

## COMMIT (commit.lock §42.4)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
`fix(deploy): remove hardcoded DB password default from Provision-FreshDb.ps1 — param-source like Install-RTMView [SF-SEC-001]`
NO push. Journal append + lock release + §0.7 re-sync the file from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/devops.md`: commit hash, grep-0-verify, verified: object-store. Then ping Security (security-0620) to re-review + flip READY, and post digest to inbox/coordinator.md.
