# CC task — R0e-fix: complete the missed (4)(b) — nest 2 Join-Path in Rebuild-Proof.ps1

> Owner: dba (slug dba-0620). db: commit. NO push (§37). Completes R0e §4-approved scope item (4)(b) that CC missed in 39270ad.
> R0e (39270ad) fixed BOM + grant + Compare-redesign correctly, but db/tools/Rebuild-Proof.ps1 STILL has the 3-arg Join-Path
> at lines 49-50 (PS7-only) -> on PS 5.1 the committed tool parses (BOM ok) but FAILS at runtime: "A positional parameter
> cannot be found that accepts argument '01_init_db.sql'". The one-command proof cannot run until this is nested. 2-line fix.

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store verify. §0.3 Python+fsync; STEP-0.5 NUL-check (0 NUL) after write.
- §42.6 claims = ["db/tools/Rebuild-Proof.ps1"]. Check .coord/push/request.md absent. commit.lock. §0.6b binding. NO push.

## THE WORK (one db: commit) — db/tools/Rebuild-Proof.ps1 ONLY
Read the file as UTF-8, nest the two 3-arg Join-Path calls, rewrite UTF-8 **WITH BOM** (preserve — the file has non-ASCII):
```python
import os
p = "db/tools/Rebuild-Proof.ps1"
with open(p, "r", encoding="utf-8-sig") as f:   # utf-8-sig strips the existing BOM on read
    t = f.read()
t = t.replace('Join-Path $DbDir "setup" "01_init_db.sql"',
              'Join-Path (Join-Path $DbDir "setup") "01_init_db.sql"')
t = t.replace('Join-Path $DbDir "tools" "Compare-ToBaseline.ps1"',
              'Join-Path (Join-Path $DbDir "tools") "Compare-ToBaseline.ps1"')
with open(p, "wb") as f:                          # re-add BOM
    f.write(b"\xef\xbb\xbf" + t.encode("utf-8"))
    f.flush(); os.fsync(f.fileno())
```
re-scan for any OTHER 3-arg Join-Path or PS7-isms (`??`, `?:`, `-Parallel`) — none expected; confirm none remain.

## ACCEPTANCE
- `head -c3 db/tools/Rebuild-Proof.ps1 | xxd` = `efbb bf`; 0 NUL.
- `grep -nE 'Join-Path \$DbDir "(setup|tools)"' db/tools/Rebuild-Proof.ps1` => NO 3-arg form remains (both nested).
- git diff = only the 2 nested Join-Path lines (+ BOM if shown); no other change.
- Operator re-runs Rebuild-Proof.ps1 (ONE command, no local patch) -> parses AND runs end-to-end -> Compare A:0/B:0/C:0/F:0.

## COMMIT (db:, commit.lock, NO push)
`db: R0e-fix Rebuild-Proof.ps1 nest 2 Join-Path (PS5.1) — completes R0e (4)(b) missed in 39270ad`
then §0.6 verify + §0.7 re-sync.

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md. NO push.
