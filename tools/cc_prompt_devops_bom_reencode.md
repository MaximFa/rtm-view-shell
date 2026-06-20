# CC task — DEVOPS: §35 BOM+CRLF re-encode of deploy/Update-RTMView.ps1 (swap-blocker)
> §4-PASS coordinator-0612 2026-06-19T07:40:19Z. Owner: devops (devops-0619). Commit `deploy:`. NO push. Logic UNCHANGED — pure re-encode.
> WHY: commit d62e704 (DB-apply fix) is logic-correct (309 ln) BUT dropped the UTF-8 BOM + CRLF. HEAD blob first3=23 52 65 (no BOM), LF endings. ALL other package PS1 = BOM+CRLF (Install 294, Restore 148, old Update 216). Script has box-draw ╔══╗ + Cyrillic comments -> without BOM Windows PowerShell 5.1 fails "Unexpected token". Swap to 234 BLOCKED until fixed.

## INIT + discipline (role-devops cold-start: read §A core + §C verify FIRST)
- §0.2 integrity: branch v2-backend; the WT of deploy/Update-RTMView.ps1 may be PD-007/LF after a coordinator restore — that's fine, you re-encode from HEAD anyway.
- §0.5 verify by OBJECT-STORE (git show HEAD:, git hash-object), NOT mount git status.
- §0.3 any .coord write = Python+fsync. If bash is blind to .coord/ (mount), use file-tools + report to operator for relay.
- Binding PREAMBLE -> .coord/cc/devops.md. commit.lock around the commit (§42.6 S3). NO push (§37).

## THE WORK (deploy/Update-RTMView.ps1)
1. Take content from HEAD (UNCHANGED, 309 lines):
```python
import os, subprocess
text = subprocess.check_output(["git","show","HEAD:deploy/Update-RTMView.ps1"]).decode("utf-8")
text = text.replace("\r\n","\n").replace("\n","\r\n")           # normalize -> CRLF
data = b"\xef\xbb\xbf" + text.encode("utf-8")                    # prepend UTF-8 BOM
with open("deploy/Update-RTMView.ps1","wb") as f:
    f.write(data); f.flush(); os.fsync(f.fileno())
```
2. VERIFY: `head -c3 deploy/Update-RTMView.ps1` == `ef bb bf`; CRLF-count == line-count; last line `Write-Host ""`; PowerShell parse clean: `[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path deploy\Update-RTMView.ps1),[ref]$null,[ref]$null)` no errors.
3. Re-commit (deploy:, NO push) under commit.lock:
   `deploy: Update-RTMView.ps1 -> UTF-8 BOM+CRLF (§35; d62e704 dropped BOM/CRLF — box-draw+Cyrillic need BOM) [devops]`
   then §0.6 post-commit verify (git show HEAD:...|head -c3 == ef bb bf via xxd) + §0.7 re-sync + sync.
4. Overwrite the STAGED package copy so it's swap-ready (one file):
   `copy /Y deploy\Update-RTMView.ps1 Installations\234_b58e2c2_19062026_Full\Update-RTMView.ps1`
   then verify that copy: head -c3 == ef bb bf, lines 309.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md (or operator relay if .coord bash blind):
commit hash; head -c3=efbbbf confirmed (object-store, via xxd); CRLF==lines; parses clean; pkg copy overwritten+verified. NO push.
