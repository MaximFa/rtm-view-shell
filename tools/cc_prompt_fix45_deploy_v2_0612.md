# CC TASK — Server-45 deploy: consolidate ALL defects, fix + repackage (devops-2-0607)

> Issued per coordinator-0612 10:49Z. Fix the 5 server-45 deploy defects in repo, repackage 45 cleanly, so the
> next deploy needs NO manual workarounds. commit fix: (NO push). Submit -> coordinator §4 BEFORE the operator runs.
> [coordinator-0612 §4 PASS 2026-06-12: SOUND. 2 amendments applied — (1) FIX C SQL via quoted-heredoc + doubled-apostrophe gate (anti-rake); (2) bounded S2-override for stale dba/db claim. GO after these.]

## Mandatory — read: .claude/skills/widget-planner/widget-planner.md ; widget-creator ; session-coord (§10/§42).

## §0.6a Step 0 — restore the .ps1 from HEAD first (PD-007 mount-drift)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
git show HEAD:deploy/Apply-Server45Upgrade.ps1 > deploy/Apply-Server45Upgrade.ps1
sync; tail -3 deploy/Apply-Server45Upgrade.ps1; wc -l deploy/Apply-Server45Upgrade.ps1
```
## Sync — slug devops-2-0607. Claims: `deploy/Apply-Server45Upgrade.ps1, db/functions/01_ngc_functions.sql, tools/cc_prompt_build_45.md, CLAUDE.md`.
- S1 barrier (FREEZE ACTIVE -> STOP). S2 coord_check_claims (all 4). S3 commit.lock. S4 cc_post_commit.sh. S5 NO push.
- **[coord §4 — S2 override, bounded]** coord_check_claims WILL exit-1 on db/functions/01_ngc_functions.sql — dba-0610
  holds a STALE db-module claim (HB 06-10, dormant; reads session-file claim, not the queue). PROCEED past the exit-1 ONLY
  for that known dba-0610/db conflict (justified: dba dormant + operator-authorised deploy consolidation + recurring
  stale-claim false-positive, flagged 09:35/10:14). ANY OTHER path conflict STILL STOPs. (Hygiene to clear dba's stale
  claim is in backlog.md.)
ALL writes Python+os.fsync. Edit tool BANNED.

---

## FIX A — BOM on the orchestrator (ROOT of the server-45 parse-fail)
The 65281a7 de-IIS Python write dropped the UTF-8 BOM -> Windows PS 5.1 on the cyrillic-locale server mis-decoded the
54 em-dashes -> cascade parse errors. Re-write deploy/Apply-Server45Upgrade.ps1 WITH a BOM. Use **utf-8-sig**:
```python
import os
p="deploy/Apply-Server45Upgrade.ps1"
t=open(p,encoding="utf-8").read()           # current content (already correct, just no BOM)
# (apply FIX A2 edits below to `t` BEFORE writing)
with open(p,"w",encoding="utf-8-sig") as f: # utf-8-sig PREPENDS EF BB BF
    f.write(t); f.flush(); os.fsync(f.fileno())
```
HARD-VERIFY (gate — do not proceed if it fails):
```bash
head -c3 deploy/Apply-Server45Upgrade.ps1 | xxd | grep -q "efbb bf" && echo "BOM ok" || echo "BOM MISSING — FIX"
```

## FIX A2 — Invoke-Rollback pg_restore must tolerate non-fatal stderr (the rollback failed live on 45)
Invoke-Rollback runs `& $psql ... DROP/CREATE DATABASE` and `& (pg_restore) ...` under the script's
`$ErrorActionPreference="Stop"`. A non-fatal stderr (e.g. PG17-dump `transaction_timeout` GUC on a PG15 server)
raised NativeCommandError -> aborted the rollback mid-restore -> EMPTY DB (live incident 2026-06-12).
FIX: inside Invoke-Rollback, wrap the DROP/CREATE psql AND the pg_restore call in EAP=Continue and rely on exit
codes (same pattern as E-015 in Phase 4/5). e.g. around the pg_restore:
```powershell
$prevEAP=$ErrorActionPreference; $ErrorActionPreference="Continue"
& (Find-PGTool "pg_restore") -h $DBHost -p $DBPort -U $SuperUser -d $Database $backupFile 2>&1 | ForEach-Object { Log "  $_" }
$rc=$LASTEXITCODE; $ErrorActionPreference=$prevEAP
if ($rc -ne 0) { Log "[ROLLBACK] pg_restore exit=$rc (non-zero may be non-fatal GUC warnings — verify data)" }
```
Apply the same EAP=Continue guard to the DROP DATABASE / CREATE DATABASE psql calls in Invoke-Rollback.

## FIX B — build_45 migration completeness + build-time verify (DEFENSIVE — package was NOT actually missing files)
NOTE: the live "Migration not found" was a HIDDEN char in the pasted -MigrationList, NOT a missing file (the package
had all 17). Still, add a build-time guard to tools/cc_prompt_build_45.md: after copying db/migrations/*.sql, assert
`(package migrations/*.sql count) == (repo db/migrations/*.sql count)` and FAIL the build on mismatch. Confirm the copy
step uses `db/migrations/*.sql` (all of them).

## FIX C — NGC_CreateSupergroup sig+prokind-AGNOSTIC DROP in db/functions/01_ngc_functions.sql
Server 45 had NGC_CreateSupergroup as a PROCEDURE (drift); the fixed `DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"(...)`
(lines ~384-385) does NOT drop a procedure -> Phase-5 42809. Replace those fixed DROP FUNCTION lines with ONE
kind-agnostic DO-loop (drops it whether function OR procedure), so re-apply is procedure-safe (no manual pre-DROP):
```sql
DO $drop_createsupergroup$
DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='NGC_CreateSupergroup' LOOP
    IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE ' || r.sig::text;
    ELSE                  EXECUTE 'DROP FUNCTION '  || r.sig::text; END IF;
  END LOOP;
END $drop_createsupergroup$;
```
**[coord §4 — REQUIRED, anti-rake]** Insert this DO-loop by writing it via a QUOTED heredoc to a temp file, then
Python-fsync the replacement into db/functions/01 (read file, str.replace the old fixed-DROP lines with the heredoc
content). Do NOT embed the SQL as an inline Python string literal — that is what DOUBLED the apostrophes in 5c6a535
(the catowner rake). After the edit, GATE: `grep -c "''" db/functions/01_ngc_functions.sql` must NOT increase vs before
the edit (no new doubled apostrophes); dollar-quote balance even; file line-count sane.
Keep the following `CREATE OR REPLACE FUNCTION "NGC_CreateSupergroup"(...)` body BYTE-UNCHANGED (it stays a FUNCTION —
RTM calls it via SELECT/GetScalar). Verify: 0 remaining `DROP FUNCTION IF EXISTS "NGC_CreateSupergroup"` lines; the
DO-loop present; dollar-quote balance even.

## FIX D — CLAUDE.md §43 factual fix
Change "Server 45 -> PG17" to "Server 45 -> PG15.x" (it auto-detected PG 15.5). Others stay PG18. (CLAUDE.md edit OK §0.7/§39.5.)
Verify: `grep -n "Server 45" CLAUDE.md` shows PG15.

## COMMIT (single fix:, NO push) under commit.lock
```bash
bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1 db/functions/01_ngc_functions.sql CLAUDE.md tools/cc_prompt_build_45.md
git add deploy/Apply-Server45Upgrade.ps1 db/functions/01_ngc_functions.sql CLAUDE.md tools/cc_prompt_build_45.md
git commit -m "fix: server-45 deploy v2 — orchestrator BOM (utf-8-sig) + Invoke-Rollback EAP=Continue + NGC_CreateSupergroup kind-agnostic DROP + CLAUDE.md §43 PG15 + build-45 migration verify"
```
Then §0.6 post-commit verify + cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h) + PD-007 re-sync. NO push.

## FIX E — REPACKAGE 45 from the new HEAD + VERIFY the package
Run the build (tools/cc_prompt_build_45.md) producing Installations/45_<newHEAD>_<ts>.zip. INSTALL.txt MUST say:
**-PgVersion 15** (server 45 = PG15.5, NOT 17); -MigrationList = the 4 unapplied (20260604_001, 20260605_004,
20260606_005, 20260606_008; 010 already applied on 45); NO manual pre-DROP needed (FIX C). 
VERIFY the package (gate):
```powershell
# every .ps1 in the package starts EF BB BF:
Get-ChildItem -Recurse $pkg -Filter *.ps1 | ForEach-Object { $b=[IO.File]::ReadAllBytes($_.FullName); "$([bool]($b.Length -ge 3 -and $b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF))  $($_.Name)" }
# migrations complete, SQL clean, ps1 IIS-free:
"migrations: $((Get-ChildItem $pkg\migrations -Filter *.sql).Count) (repo has $((Get-ChildItem db\migrations -Filter *.sql).Count))"
# 02_catowner_role.sql: doubled=0, current_setting=2 ; Apply-...ps1: IIS=0, $AppPools=0, service-model>0
```
Report new package path + all verify results.

## REPORT to coordinator (append .coord/inbox/coordinator.md): commit hash; BOM EF BB BF confirmed; A2 EAP guard present;
FIX C DO-loop + 0 fixed-DROP; §43 PG15; build verify added; new package path + package verify (all .ps1 BOM, migrations count match, doubled=0, IIS=0). NO push.
