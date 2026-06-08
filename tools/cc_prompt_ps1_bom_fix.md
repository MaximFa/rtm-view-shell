# CC Task — Fix PS1 encoding (UTF-8 BOM + CRLF) on release-critical scripts (§35; Windows PS 5.1 parse failure)

> Session devops-2-0607. Live finding: Build-ProdRelease.ps1 fails to PARSE under Windows PowerShell 5.1 —
> "Unexpected token" — because it is UTF-8 WITHOUT BOM and contains non-ASCII (em-dash —, Cyrillic). PS 5.1 reads
> a BOM-less .ps1 as the ANSI codepage, mangling multi-byte chars (the em-dash bytes produce a stray quote that
> breaks string parsing). CLAUDE.md §35: PS1 files MUST be UTF-8 BOM + CRLF. Several release-critical scripts lost
> their BOM. CRITICAL: deploy/Apply-Server45Upgrade.ps1 (the server45 upgrade orchestrator) is BOM-less with 55
> non-ASCII lines -> it would CRASH on server45 (PG17, PS 5.1) exactly like Build-ProdRelease did.

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES-WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED"; else echo "OK: $f"; fi
done
sync; echo "=== integrity done ==="
```
Known false-M (hash==HEAD): db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY
Session slug: `devops-2-0607`
Claims: `deploy/Apply-Server45Upgrade.ps1`, `deploy/Update-RTMView.ps1`, `tools/Build-ProdRelease.ps1`, `db/tools/Compare-ToBaseline.ps1`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo STOP; exit 1; fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py devops-2-0607 deploy/Apply-Server45Upgrade.ps1 deploy/Update-RTMView.ps1 tools/Build-ProdRelease.ps1 db/tools/Compare-ToBaseline.ps1
```
Modify ONLY those 4 files (plus /tmp throwaways).
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s, phantom-aware. While holding:
`bash tools/pre-commit-check.sh` -> `git add` the 4 files -> commit (msg below) -> §0.6 post-commit verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

## The fix — add UTF-8 BOM + ensure CRLF, PRESERVE content byte-for-byte (only encoding changes)
For EACH of the 4 files:
1. Read the file as raw bytes. Confirm current content is valid UTF-8 (it is — the non-ASCII are correct UTF-8
   em-dashes / Cyrillic; the ONLY problem is the missing BOM under PS 5.1).
2. If it does NOT already start with the UTF-8 BOM (EF BB BF), PREPEND it.
3. Normalize line endings to CRLF (§35): convert lone LF -> CRLF (do not double existing CRLF).
4. Do NOT change any actual script content (no logic edits, no char substitutions). BOM + CRLF only.
Implementation (PowerShell, the platform that will run these — do it natively so encoding is exact):
```powershell
$files = @(
  "deploy\Apply-Server45Upgrade.ps1",
  "deploy\Update-RTMView.ps1",
  "tools\Build-ProdRelease.ps1",
  "db\tools\Compare-ToBaseline.ps1"
)
foreach ($f in $files) {
  $raw = [System.IO.File]::ReadAllText($f, [System.Text.UTF8Encoding]::new($false))  # read as UTF-8 (no BOM)
  $raw = $raw -replace "`r`n","`n" -replace "`n","`r`n"                               # normalize to CRLF
  $utf8bom = [System.Text.UTF8Encoding]::new($true)                                    # UTF-8 WITH BOM
  [System.IO.File]::WriteAllText($f, $raw, $utf8bom)
}
```
(If you prefer Python: read bytes, strip any existing EF BB BF, decode utf-8, CRLF-normalize, write
 b'\xef\xbb\xbf' + content.encode('utf-8'). Either is fine — result must be EF BB BF + CRLF + identical text.)

## Self-test (CC runs on Windows — REAL validation)
```powershell
foreach ($f in @("deploy\Apply-Server45Upgrade.ps1","deploy\Update-RTMView.ps1","tools\Build-ProdRelease.ps1","db\tools\Compare-ToBaseline.ps1")) {
  $b = [System.IO.File]::ReadAllBytes($f)[0..2]
  $hasBom = ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
  # PARSE test — this is the proof the §35 failure is gone:
  $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$errs)
  "$f BOM=$hasBom parseErrors=$($errs.Count)"
}
```
Every file: BOM=True, parseErrors=0. (Especially confirm Build-ProdRelease.ps1 + Apply-Server45Upgrade.ps1 now
parse with 0 errors — that is the bug this task fixes.)

## Commit
ONE commit, prefix `deploy:`, message:
`deploy: add UTF-8 BOM + CRLF to release-critical PS1 (Apply-Server45Upgrade, Update-RTMView, Build-ProdRelease, Compare-ToBaseline) — §35 PS5.1 parse fix`
Then S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only (§37).
