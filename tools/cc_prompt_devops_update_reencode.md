# CC task — DEVOPS: re-encode deploy/Update-RTMView.ps1 to UTF-8 BOM + CRLF (§35) — swap-blocker fix

> Coordinator-0612 directive 2026-06-19. Owner: devops (devops-2-0607). Executor: native CC. Commit `deploy:`. **NO push.**
> CONTEXT: d62e704 added correct DB-apply LOGIC (verified: -MigrationList L49, pg_dump FAIL-STOP L120-130, functions+migrations psql -f ON_ERROR_STOP L171-211, 309 lines) BUT dropped §35 encoding — HEAD blob starts `23 52 65` (#Re, NO BOM), LF newlines. The script has box-draw `╔══╗` + Cyrillic comments -> without BOM, Windows PowerShell 5.1 throws "Unexpected token". The OTHER package PS1 are BOM+CRLF (old Update 216 / Install 294 / Restore 148). LOGIC UNCHANGED — encoding-only.

## INIT + discipline
- §0.2: branch v2-backend. Restore deploy/Update-RTMView.ps1 from HEAD first (WT was PD-007-truncated 263/309): `git show HEAD:deploy/Update-RTMView.ps1 > deploy/Update-RTMView.ps1` (then it is the authoritative 309-line content). Hash-verify == HEAD blob.
- NORM-CUR-07 binding PREAMBLE -> .coord/cc/devops.md. §42.6 sync: S2 claim deploy/Update-RTMView.ps1, S3 commit.lock, S4 post-commit. NO push.

## THE WORK — encoding only, do NOT touch logic
```python
import os
# source = the HEAD-restored working tree (309 lines, d62e704 logic, currently LF/no-BOM)
text = open("deploy/Update-RTMView.ps1","r",encoding="utf-8",newline="").read()
text = text.replace("\r\n","\n").replace("\n","\r\n")        # normalize -> CRLF
data = b"\xef\xbb\xbf" + text.encode("utf-8")                # prepend UTF-8 BOM
with open("deploy/Update-RTMView.ps1","wb") as f:
    f.write(data); f.flush(); os.fsync(f.fileno())
```

## VERIFY (cite real bytes/parse — devops HAS native tools)
- `head -c3 deploy/Update-RTMView.ps1 | xxd` == `ef bb bf`.
- CRLF count == line count (e.g. `grep -c $'\r' deploy/Update-RTMView.ps1` equals the 309 line count).
- Last line is `Write-Host ""`.
- `[System.Management.Automation.Language.Parser]::ParseFile("deploy/Update-RTMView.ps1",[ref]$null,[ref]$e); $e -eq $null` (no parse errors).
- LOGIC unchanged vs HEAD: `git diff --stat HEAD -- deploy/Update-RTMView.ps1` should show only the encoding change (BOM/EOL); the token content is identical.

## Commit (deploy:, NO push) under commit.lock
git add deploy/Update-RTMView.ps1 ; commit -m "deploy: Update-RTMView.ps1 -> UTF-8 BOM+CRLF (§35; d62e704 dropped BOM/CRLF — box-draw+Cyrillic need BOM) [devops]" ; §0.6 post-commit ; cc_post_commit.sh ; §0.7 re-sync ; sync.

## PATCH the staged package (so 234 pkg is swap-ready)
```
copy /Y deploy\Update-RTMView.ps1 Installations\234_b58e2c2_19062026_Full\Update-RTMView.ps1
```
(So the operator's only remaining action is one copy of the file from the staged pkg to the 234 server.)

## Report -> .coord/cc/devops.md binding RESULT + chat:
- commit hash ; `head -c3`=ef bb bf confirmed ; CRLF==309 lines ; last line `Write-Host ""` ; ParseFile no errors ; git diff HEAD = encoding-only ; pkg copy overwritten (Installations\234_b58e2c2_19062026_Full\Update-RTMView.ps1). NO push.
