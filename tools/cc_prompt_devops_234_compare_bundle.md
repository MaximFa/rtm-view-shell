# CC task — DEVOPS: build portable Compare bundle for 234 pre-deploy drift check (read-only)
> §4-PASS by coordinator-0612 2026-06-18T11:31Z (operator: 234 deploy stage, path-1 portable bundle). Owner: devops (devops-2-0607). Executor: native CC.
> Builds a DEPLOY ARTIFACT (zip in Installations/, gitignored). NO commit, NO push. Read-only at run time (Compare never writes the DB).
> Baseline = pushed origin/v2-backend b58e2c2 (regen schema.sql + functions + migrations incl backfill _001). Goal: see 234's STARTING drift BEFORE any apply (anti-saga: drift at the gate, not a runtime cascade).

## INIT + discipline
- If .claude/skills/role-devops/role-devops.md exists -> read §A + §C-green. (If not cold-started yet -> proceed; flag to coordinator.)
- §0.2 integrity: branch v2-backend; HEAD == b58e2c2 (the pushed baseline) — verify `git rev-parse HEAD` and `git rev-parse origin/v2-backend` equal. If not at b58e2c2, `git fetch` + ensure the baseline files (db/) are the b58e2c2 objects (hash-verify, NOT mount line-count).
- POST-VERIFY norm: verify the bundle contents by ls+cat+git show HEAD / unzip-list, NOT -f/-s stat.

## STEP 1 — assemble the bundle (from b58e2c2 objects, NOT possibly-truncated WT)
Create a staging dir, populate it from HEAD blobs to avoid PD-007 WT drift:
```
$stage = "Installations\234_compare_b58e2c2_<ts>"
mkdir $stage, "$stage\db", "$stage\db\tools", "$stage\db\functions", "$stage\db\data", "$stage\db\migrations", "$stage\db\setup", "$stage\out"
# copy baseline + tool from HEAD (git show HEAD:<path> > dest) so content == b58e2c2:
#   db/schema.sql, db/tools/Compare-ToBaseline.ps1, db/functions/*.sql, db/data/*.sql, db/migrations/*.sql, db/setup/01_init_db.sql
# (enumerate via `git ls-tree -r --name-only HEAD -- db/` and copy each via git show HEAD:<f>)
```
Verify every copied file hash == its HEAD blob (git hash-object vs git rev-parse HEAD:<f>).

## STEP 2 — generate run-compare.ps1 (read-only, localhost on 234) into $stage
```powershell
# run-compare.ps1 — run ON 234 (PG localhost-only). READ-ONLY. UTF-8 BOM + CRLF (§35).
param([string]$Password = "", [string]$Database = "rtmviewdb", [string]$DBHost = "localhost", [string]$DBPort = "5432", [string]$User = "ccdashboard_user")
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
& powershell -ExecutionPolicy Bypass -File "$here\db\tools\Compare-ToBaseline.ps1" `
    -DBHost $DBHost -DBPort $DBPort -Database $Database -User $User -Password $Password `
    -BaselineDir "$here\db" -OutDir "$here\out"
Write-Host "Compare done. Delta + align in: $here\out" -ForegroundColor Green
```
Also drop a short README.txt: "Read-only pre-deploy drift check of 234 vs origin/v2-backend b58e2c2. Run on 234: powershell -ExecutionPolicy Bypass -File run-compare.ps1 -Password '<rtmviewdb pw>'. Send back out\baseline_delta_*.txt. NO writes to the DB."

## STEP 3 — zip + ExecutionPolicy/Unblock note
- `Compress-Archive $stage\* Installations\234_compare_b58e2c2_<ts>.zip`
- PS1 files in the zip: UTF-8 BOM + CRLF (§35) so they don't trip Windows PowerShell. Operator STEP-0 on 234: `Set-ExecutionPolicy -Scope Process Bypass -Force` + `Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File` (mark-of-the-web after unzip).

## VERIFY
- unzip -l the produced zip: contains db/tools/Compare-ToBaseline.ps1, db/schema.sql, db/functions/*.sql (4), db/migrations/*.sql (incl 20260613_001_backfill_metric_deploy_log.sql), db/data/*.sql, run-compare.ps1, README.txt.
- Compare-ToBaseline.ps1 in the bundle == HEAD blob (hash). schema.sql == HEAD (the regen, no phantoms: grep -c phantom = 0).
- NO commit, NO push (Installations is gitignored).

## Report (chat + .coord/inbox/coordinator.md)
- zip path Installations\234_compare_b58e2c2_<ts>.zip + contents list + hash-verify pass.
- Operator run instructions on 234 (drop in C:\RTMView-Ops\incoming, ExecutionPolicy Bypass + Unblock-File, run run-compare.ps1 -Password, send back out\baseline_delta_*.txt).
- NOTE for the read-back: Dim A (enumerated objects), Dim B (routine kind, overload-aware), Dim D (migrations 234 lacks incl _001). Functions deploy from db/functions (authoritative); T-FN v2 = schema.sql function-set not 100% faithful, so triage function drift by eye, not auto-apply.
