# CC task — R0c-fix: Rebuild-Proof.ps1 PowerShell 5.1 compat (UTF-8 BOM + 2-arg Join-Path)

> Owner: dba (slug dba-0620). db: commit. NO push (§37). Tooling-only fix; no rebuild-logic change.
> Blocks the rebuild proof (barrier #3 gate). Two PS-5.1 incompatibilities CC introduced in the new tool.

## Problem (object-store pinned, both confirmed on the dev run)
db/tools/Rebuild-Proof.ps1 (committed b8631bd) has TWO Windows-PowerShell-5.1 incompatibilities:
1. **No UTF-8 BOM** (head `23 52 65` = `#Re`) while the file has 13 non-ASCII lines (box-draw `--`, em-dash). PS 5.1 reads
   no-BOM as WIN1252 -> parser desync -> bogus `:85 '<' operator reserved` (on a correctly double-quoted SQL string)
   + cascade `:92/:198`. Sibling tools (Restore-All/Compare/Create-FreshDb) all start `EF BB BF`. FIX: re-encode UTF-8 BOM.
2. **3-arg Join-Path** (lines 49, 50): `Join-Path $DbDir "setup" "01_init_db.sql"` and
   `Join-Path $DbDir "tools" "Compare-ToBaseline.ps1"`. The 3-component Join-Path is PowerShell 7+ ONLY; PS 5.1 accepts max
   2 components and throws `A positional parameter cannot be found that accepts argument '01_init_db.sql'` at runtime.
   FIX: nest -> `Join-Path (Join-Path $DbDir "setup") "01_init_db.sql"` (same for the tools/Compare-ToBaseline.ps1 line).

3. **Missing GRANT step before Compare** (confirmed dev-run step 7): Rebuild-Proof.ps1 applies schema.sql as SuperUser
   (postgres owns the RTM tables) then runs Compare-ToBaseline's pg_dump as the APP user -> `permission denied for table
   NGC_AgentGroups`. Restore-All.ps1 has a grant step; Rebuild-Proof.ps1 lacks one.
   FIX: after step 6 (data), before Compare, run as SuperUser:
   `GRANT USAGE ON SCHEMA public TO <AppUser>; GRANT ALL ON ALL TABLES IN SCHEMA public TO <AppUser>; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO <AppUser>;`
   (mirror Restore-All's grant block). Alternatively run the internal Compare invocation as SuperUser. Grant-step preferred
   (represents prod: schema owned by postgres, app user granted).
   ACCEPTANCE add: proof reaches step 7 Compare with no permission error and prints B=0.

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store verify. §0.3 Python+fsync. Check .coord/push/request.md absent.
  commit.lock around commit. §0.6b binding -> .coord/cc/dba.md. NO push. §42.6 claims = ["db/tools/Rebuild-Proof.ps1"].

## THE WORK (one db: commit)
```python
import os
p = "db/tools/Rebuild-Proof.ps1"
with open(p, "r", encoding="utf-8") as f:
    t = f.read()
if t.startswith("﻿"):
    t = t[1:]
# 2-arg Join-Path nesting (PS 5.1)
t = t.replace('Join-Path $DbDir "setup" "01_init_db.sql"',
              'Join-Path (Join-Path $DbDir "setup") "01_init_db.sql"')
t = t.replace('Join-Path $DbDir "tools" "Compare-ToBaseline.ps1"',
              'Join-Path (Join-Path $DbDir "tools") "Compare-ToBaseline.ps1"')
# write UTF-8 WITH BOM (PS 5.1 needs it for the non-ASCII lines)
with open(p, "wb") as f:
    f.write(b"\xef\xbb\xbf" + t.encode("utf-8"))
    f.flush(); os.fsync(f.fileno())
```
Optional: normalise to CRLF (sibling-tool consistency). Re-scan for other PS7-isms (`??`, `?:` ternary, `-Parallel`) — none
found in the current file, but confirm after edit.

## ACCEPTANCE
- `head -c 3 db/tools/Rebuild-Proof.ps1 | xxd` => `efbb bf`.
- `grep -n 'Join-Path $DbDir "setup"\|Join-Path $DbDir "tools"' db/tools/Rebuild-Proof.ps1` => no 3-arg form remains.
- `git diff` shows only the BOM + the two nested-Join-Path lines; no logic lines altered.
- Operator re-runs Rebuild-Proof.ps1 -> parses, runs, reaches Compare. Do NOT claim Delivered without B:0.

## COMMIT (db:, commit.lock, NO push)
`db: R0c-fix Rebuild-Proof.ps1 PS 5.1 compat — UTF-8 BOM + 2-arg Join-Path (no-BOM+box-draw + 3-arg Join-Path both blocked the rebuild proof)`
then §0.6 verify + §0.7 re-sync.

## CAPTURE (NORM-CUR-11 — MANDATORY): append to .claude/skills/role-dba/role-dba.md §B:
`2026-06-21 · NEW PowerShell tooling must be Windows-PS-5.1-compatible, verified on PS 5.1 not just structurally: (1) UTF-8 WITH BOM if it has ANY non-ASCII (box-draw/em-dash/Cyrillic) — no-BOM is read as WIN1252 and desyncs the parser into errors far from the real spot; (2) Join-Path takes only 2 components on 5.1 (3-arg is PS7-only -> "positional parameter cannot be found"); also avoid ??/ternary/-Parallel. Asymmetry vs psql temp .sql which must be NO-BOM. A grep/structure review does NOT catch these — run it on 5.1. · SOURCE: Rebuild-Proof.ps1 dev-run fails 2026-06-21 (BOM then Join-Path), R0c-fix · status: active`

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md. NO push.
