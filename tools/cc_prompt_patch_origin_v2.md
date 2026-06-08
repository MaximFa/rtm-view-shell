# CC Task — db/tools/Patch-ToOriginV2.ps1 (idempotent DB patch → origin/v2 state)

> Issued by Cowork session **RTM DevOps** (slug `devops-0606`).
> Goal: create an idempotent PowerShell patch script that brings ANY rtmviewdb-shaped
> database up to the **origin/v2 target** = **Metrics D3a** (12 catalogue columns on
> `RTSGrid_Metric` + 198-row backfill) **+ DayTrend** (`RTSData_SetUserStatus` = single
> 15-param PROCEDURE that writes `RTSData_UserStatusLog`). Then TEST it on `rtmviewdb1`,
> and produce a `pg_dump` for the production restore (`rtmviewdb`).
>
> Naming note: the Metrics-D3a commits (deb1d00/63babe6/5613f00) are LOCAL-ONLY — working
> tree HEAD is 3 commits ahead of origin/v2 (adeebca). The script targets the **working-tree
> files**, which is what origin/v2 will contain after the pending push. Do not block on this.

---

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a) — run FIRST

```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin v2 -q
git rev-parse HEAD; git rev-parse origin/v2     # local is expected 3 ahead (Metrics D3a unpushed)
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== Integrity check complete ==="
```

---

## Mandatory — read before starting (§40)

```
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
```
Only after reading all three: proceed.

---

## Multi-session sync — MANDATORY (§42, skill v1.4)

Session slug: `devops-0606`
Claims (touch ONLY these, plus /tmp/devops-0606_*.py|*.sql throwaway — L-SC-16):
- `db/tools/Patch-ToOriginV2.ps1`            (new file — write)
- `tools/cc_prompt_patch_origin_v2.md`       (this prompt — already written by Cowork; do not edit)

READ-ONLY (consume, never edit): `db/migrations/`, `db/functions/`,
`src/CcDashboard.Infrastructure/Migrations/`.
The script applies changes to LIVE databases (`rtmviewdb1`, dumps for `rtmviewdb`) — that is
NOT a repo edit and needs no claim.

### S1. Push barrier check — before ANY work (content-based, L-SC-10)
```bash
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md
    echo "STOP — do not start this task. Report to operator."; exit 1
fi
```

### S2. Claim discipline — ENFORCED
```bash
python3 tools/coord_check_claims.py devops-0606 db/tools/Patch-ToOriginV2.ps1
# exit 1 -> STOP: another active session holds the path. Report to operator.
```
Modify ONLY `db/tools/Patch-ToOriginV2.ps1` (plus /tmp throwaways). Anything else → STOP.

### S3. Commit lock — around EVERY git add/commit  (phantom-aware, L-SC-10)
```python
# /tmp/acquire_lock.py
import os, sys, time, datetime
lock = ".coord/locks/commit.lock"
def real_lock():
    try:
        with open(lock) as f: return f.read().strip() != ""
    except OSError: return False
for attempt in range(5):
    try:
        with open(lock, "x", encoding="utf-8") as f:
            f.write("owner: devops-0606\nacquired: " + datetime.datetime.utcnow().isoformat() + "Z\n")
            f.flush(); os.fsync(f.fileno())
        print("LOCK ACQUIRED"); sys.exit(0)
    except FileExistsError:
        if not real_lock():
            print("PHANTOM lock — clearing")
            try: os.remove(lock)
            except OSError: print("  cannot unlink from this side — needs Windows rm")
            time.sleep(2); continue
        print("BUSY (real): " + open(lock).read().strip()); time.sleep(60)
print("FAILED to acquire commit lock after 5 attempts"); sys.exit(1)
```
- If FAILED: abort the commit, report lock owner. Do NOT delete the lock.
- Lock older than 15 min = stale: report contents, WAIT for operator. Never auto-delete.

While holding the lock: `bash tools/pre-commit-check.sh` → `git add db/tools/Patch-ToOriginV2.ps1`
→ `git commit -m "db: idempotent Patch-ToOriginV2 (Metrics D3a + DayTrend)"` → §0.6 post-commit verify.

### S4. Journal + release — after the commit
```python
# /tmp/journal_release.py
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
line = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ") + " | devops-0606 | " + h + "\n"
with open(".coord/journal.md","a",encoding="utf-8") as f:
    f.write(line); f.flush(); os.fsync(f.fileno())
os.remove(".coord/locks/commit.lock")
print("journal appended, lock released")
```
Then `sync`. If the commit aborts, still release the lock.

### S4b. Post-commit flush — to the coordinator (REQUIRED)
```python
# /tmp/devops-0606_flush.py
import os, datetime, subprocess
h = subprocess.check_output(["git","log","-1","--format=%h %s"]).decode().strip()
block = ("## " + datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%MZ")
    + " | from: devops-0606 | to: coordinator\n"
    "COMMIT " + h + "\n"
    "claims-releasable: db/tools/Patch-ToOriginV2.ps1\n"
    "blocker/question: none\n"
    "next: awaiting operator (dump ready for rtmviewdb restore)\n---\n")
with open(".coord/inbox/coordinator.md","a",encoding="utf-8") as f:
    f.write(block); f.flush(); os.fsync(f.fileno())
print("post-commit flush written")
```
Then `sync`. Also remove `db/tools/Patch-ToOriginV2.ps1` from `files:` in your session file once committed.

### S5. Git push
Do NOT run `git push` (§37). Push happens only via `tools/cc_prompt_push.md`.

---

## Background — why this script exists (read carefully)

The origin/v2 target is three concrete DB facts:

1. **12 catalogue columns** on `public."RTSGrid_Metric"`: `DisplayName, ShortDescription,
   LongDescription, Comparison, StandardKpi, StandardRef, CatalogCategory, Family, Channel,
   ThresholdSec, CatalogStatus, CatalogNotes`. Added by EF migration
   `BackendEmulation/20260606100233_AddCatalogueFieldsToRtsGridMetric`.
   **CRITICAL:** `RTSGrid_Metric` belongs to `BackendEmulationDbContext`, whose migrations
   run on Shell startup ONLY in Development/Testing (DatabaseInitializer.cs:38 gates them
   behind `env.IsDevelopment() || "Testing"`). On a production DB the 12 columns are therefore
   NEVER created by the normal Shell `migrate`. This script must apply that migration
   **explicitly** via `--context BackendEmulationDbContext`.

2. **Backfill** of those columns for ~198 metrics — `db/migrations/20260606_003_catalog_backfill.sql`
   (idempotent `UPDATE ... WHERE "MetricId" = ...`, 202 statements; ~198 match rows present in DB;
   the catalog has 5 duplicate pairs). MUST run **strictly AFTER** the EF schema migration —
   the columns must exist first.

3. **DayTrend**: `RTSData_SetUserStatus` = single 15-param **PROCEDURE** that appends a row to
   `RTSData_UserStatusLog` when `start < end`. Already encoded in
   `db/functions/02_rtsdata_functions.sql` (CREATE PROCEDURE with the log INSERT) — identical to
   `db/migrations/20260606_002_fix_userstatuslog_write.sql`. Re-applying the functions file is
   authoritative and idempotent; the 002 migration is a redundant duplicate.

EF migration-history tables (separate per context, same DB):
- AppDbContext → `public."__ef_migrations_history"`
- BackendEmulationDbContext → `public."__BackendEmulationMigrationsHistory"`
- ProductVersion = `8.0.16`. BackendEmulation migration id = `20260606100233_AddCatalogueFieldsToRtsGridMetric`.

All `db/migrations/*.sql` are explicitly idempotent (ON CONFLICT / CREATE OR REPLACE /
CREATE TABLE IF NOT EXISTS / value-matched UPDATEs). Re-running any of them is safe.

---

## Task A — write `db/tools/Patch-ToOriginV2.ps1`

Write the file below VERBATIM via a Python script with `os.fsync` (Edit tool BANNED, §0.3),
then `sync && tail -3 && wc -l` to verify it closed properly.

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Idempotent patch: brings a rtmviewdb-shaped database to the origin/v2 target
    (Metrics D3a catalogue + DayTrend UserStatusLog). Safe to re-run.
.DESCRIPTION
    1. EF migrate AppDbContext + BackendEmulationDbContext (explicit — BE is prod-gated off).
       Falls back to idempotent DDL + history insert when the .NET SDK / dotnet-ef is absent.
    2. Apply db/functions/*.sql (CREATE OR REPLACE — idempotent; deploys 15-param
       RTSData_SetUserStatus with the UserStatusLog write).
    3. Apply db/migrations/*.sql delta, name-ordered, ledger-gated (public.db_patch_history);
       20260606_003 backfill runs last, after the EF columns exist.
    4. Verify: 12 columns present, backfill coverage (0 NULL among present targets),
       RTSData_SetUserStatus = single 15-param procedure with log insert.
    5. pg_dump (custom format) for transfer to production.
.EXAMPLE
    .\Patch-ToOriginV2.ps1 -Database rtmviewdb1 -AppPassword "!@#qweASDzxc"
.EXAMPLE
    .\Patch-ToOriginV2.ps1 -Database rtmviewdb1 -SkipDump        # patch only
#>
[CmdletBinding()]
param(
    [string]$DBHost      = "localhost",
    [string]$DBPort      = "5432",
    [string]$Database    = "rtmviewdb1",
    [string]$AppUser     = "ccdashboard_user",
    [string]$AppPassword = "!@#qweASDzxc",
    [int]   $ExpectedCatalogued = 198,
    [string]$DumpPath    = "",
    [switch]$SkipEf,
    [switch]$SkipDump
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $ScriptDir)   # db\tools -> repo root
$DbDir     = Join-Path $RepoRoot "db"
$FuncDir   = Join-Path $DbDir "functions"
$MigDir    = Join-Path $DbDir "migrations"
$ConnStr   = "Host=$DBHost;Port=$DBPort;Database=$Database;Username=$AppUser;Password=$AppPassword;SSL Mode=Prefer"

function Find-PGTool([string]$Name) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($v in @("18","17","16","15")) {
        foreach ($b in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = "$b\$v\bin\$Name.exe"; if (Test-Path $p) { return $p }
        }
    }
    return $null
}
$psql    = Find-PGTool "psql"
$pgdump  = Find-PGTool "pg_dump"
if (-not $psql) { throw "psql not found." }
$env:PGPASSWORD = $AppPassword

function Psql-Scalar([string]$sql) {
    return (& $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -t -A -c $sql 2>&1).Trim()
}
function Psql-File([string]$file) {
    & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -v ON_ERROR_STOP=1 -q -f $file
    if ($LASTEXITCODE -ne 0) { throw "psql failed on $file" }
}
function Psql-Cmd([string]$sql) {
    & $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -v ON_ERROR_STOP=1 -q -c $sql
    if ($LASTEXITCODE -ne 0) { throw "psql failed on inline SQL" }
}

Write-Host "" ; Write-Host "Patch-ToOriginV2 -> ${AppUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Cyan
if ((Psql-Scalar "SELECT 1") -ne "1") { throw "Cannot connect to $Database." }

# The 12 catalogue columns we must end up with.
$CatCols = @("DisplayName","ShortDescription","LongDescription","Comparison","StandardKpi",
             "StandardRef","CatalogCategory","Family","Channel","ThresholdSec",
             "CatalogStatus","CatalogNotes")

function Test-CatalogueColumns {
    $n = Psql-Scalar @"
SELECT count(*) FROM information_schema.columns
WHERE table_schema='public' AND table_name='RTSGrid_Metric'
  AND column_name IN ('DisplayName','ShortDescription','LongDescription','Comparison',
  'StandardKpi','StandardRef','CatalogCategory','Family','Channel','ThresholdSec',
  'CatalogStatus','CatalogNotes');
"@
    return [int]$n
}

# --- Step 1: EF migrate (App + BackendEmulation), explicit ---------------------------------
Write-Host "" ; Write-Host "[ 1/5 ] EF migrate (AppDbContext + BackendEmulationDbContext)..." -ForegroundColor Cyan
$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue)
$efOk = $false
if (-not $SkipEf -and $dotnet) {
    try {
        Push-Location $RepoRoot
        & dotnet ef database update --context AppDbContext `
            --project src\CcDashboard.Infrastructure --startup-project src\CcDashboard.Web `
            --connection $ConnStr
        if ($LASTEXITCODE -ne 0) { throw "dotnet ef AppDbContext failed" }
        & dotnet ef database update --context BackendEmulationDbContext `
            --project src\CcDashboard.Infrastructure --startup-project src\CcDashboard.Web `
            --connection $ConnStr
        if ($LASTEXITCODE -ne 0) { throw "dotnet ef BackendEmulationDbContext failed" }
        Pop-Location
        $efOk = $true
        Write-Host "  EF migrations applied (App + BackendEmulation)." -ForegroundColor Green
    } catch {
        Pop-Location -ErrorAction SilentlyContinue
        Write-Host "  dotnet ef failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Falling back to idempotent SQL for the 12 columns." -ForegroundColor Yellow
    }
} else {
    Write-Host "  dotnet ef skipped (SkipEf or SDK absent) — using SQL fallback." -ForegroundColor Yellow
}

if ((Test-CatalogueColumns) -lt 12) {
    # SQL fallback: add columns idempotently + register the migration so EF stays consistent.
    Write-Host "  Applying SQL fallback for catalogue columns..." -ForegroundColor Yellow
    $ddl = @"
ALTER TABLE public."RTSGrid_Metric"
  ADD COLUMN IF NOT EXISTS "CatalogCategory"   character varying(20),
  ADD COLUMN IF NOT EXISTS "CatalogNotes"      text,
  ADD COLUMN IF NOT EXISTS "CatalogStatus"     character varying(20),
  ADD COLUMN IF NOT EXISTS "Channel"           character varying(20),
  ADD COLUMN IF NOT EXISTS "Comparison"        text,
  ADD COLUMN IF NOT EXISTS "DisplayName"       character varying(200),
  ADD COLUMN IF NOT EXISTS "Family"            character varying(100),
  ADD COLUMN IF NOT EXISTS "LongDescription"   text,
  ADD COLUMN IF NOT EXISTS "ShortDescription"  character varying(500),
  ADD COLUMN IF NOT EXISTS "StandardKpi"       character varying(100),
  ADD COLUMN IF NOT EXISTS "StandardRef"       character varying(200),
  ADD COLUMN IF NOT EXISTS "ThresholdSec"      integer;
CREATE TABLE IF NOT EXISTS public."__BackendEmulationMigrationsHistory" (
  "MigrationId" character varying(150) NOT NULL
    CONSTRAINT "PK___BackendEmulationMigrationsHistory" PRIMARY KEY,
  "ProductVersion" character varying(32) NOT NULL);
INSERT INTO public."__BackendEmulationMigrationsHistory" ("MigrationId","ProductVersion")
VALUES ('20260606100233_AddCatalogueFieldsToRtsGridMetric','8.0.16')
ON CONFLICT ("MigrationId") DO NOTHING;
"@
    Psql-Cmd $ddl
    Write-Host "  SQL fallback applied." -ForegroundColor Green
}
$colN = Test-CatalogueColumns
if ($colN -lt 12) { throw "Catalogue columns missing after step 1 (found $colN/12)." }
Write-Host "  Catalogue columns present: $colN/12." -ForegroundColor Green

# --- Step 2: functions (idempotent CREATE OR REPLACE) --------------------------------------
Write-Host "" ; Write-Host "[ 2/5 ] Apply db/functions/*.sql..." -ForegroundColor Cyan
foreach ($f in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    $file = Join-Path $FuncDir $f
    if (Test-Path $file) { Psql-File $file; Write-Host "  $f" -ForegroundColor Green }
    else { Write-Host "  (missing) $f" -ForegroundColor Yellow }
}

# --- Step 3: raw migrations delta (ledger-gated, name-ordered; backfill last) ---------------
Write-Host "" ; Write-Host "[ 3/5 ] Apply db/migrations/*.sql delta..." -ForegroundColor Cyan
Psql-Cmd @"
CREATE TABLE IF NOT EXISTS public.db_patch_history (
  migration_id text PRIMARY KEY,
  applied_at   timestamptz NOT NULL DEFAULT now());
"@
$migFiles = Get-ChildItem $MigDir -Filter "*.sql" | Sort-Object Name
foreach ($m in $migFiles) {
    $id = [System.IO.Path]::GetFileNameWithoutExtension($m.Name)
    $already = Psql-Scalar "SELECT 1 FROM public.db_patch_history WHERE migration_id = '$id';"
    if ($already -eq "1") { Write-Host "  skip (applied): $id" -ForegroundColor DarkGray; continue }
    if ($id -like "*catalog_backfill*" -and (Test-CatalogueColumns) -lt 12) {
        throw "Refusing to run backfill $id — catalogue columns missing (step 1 must precede)."
    }
    Psql-File $m.FullName
    Psql-Cmd "INSERT INTO public.db_patch_history (migration_id) VALUES ('$id') ON CONFLICT DO NOTHING;"
    Write-Host "  applied: $id" -ForegroundColor Green
}

# --- Step 4: verify ------------------------------------------------------------------------
Write-Host "" ; Write-Host "[ 4/5 ] Verify..." -ForegroundColor Cyan
$fail = @()

# (a) 12 columns
$colN = Test-CatalogueColumns
if ($colN -ne 12) { $fail += "columns: $colN/12" } else { Write-Host "  (a) 12/12 catalogue columns OK" -ForegroundColor Green }

# (b) backfill coverage — build target set from the backfill file, compare to DB
$backfill = Join-Path $MigDir "20260606_003_catalog_backfill.sql"
$mids = Select-String -Path $backfill -Pattern 'WHERE "MetricId" = ''([^'']+)''' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$values = ($mids | ForEach-Object { "('" + ($_ -replace "'","''") + "')" }) -join ","
$tmp = [System.IO.Path]::GetTempFileName() + ".sql"
@"
CREATE TEMP TABLE _bf(mid text);
INSERT INTO _bf(mid) VALUES $values;
\echo TARGETS:
SELECT count(*) FROM _bf;
\echo PRESENT:
SELECT count(*) FROM _bf JOIN public."RTSGrid_Metric" m ON m."MetricId"=_bf.mid;
\echo NULL_DISPLAYNAME_AMONG_PRESENT:
SELECT count(*) FROM _bf JOIN public."RTSGrid_Metric" m ON m."MetricId"=_bf.mid WHERE m."DisplayName" IS NULL;
\echo CATALOGUED_TOTAL:
SELECT count(*) FROM public."RTSGrid_Metric" WHERE "DisplayName" IS NOT NULL;
\echo MISSING_FROM_DB:
SELECT _bf.mid FROM _bf LEFT JOIN public."RTSGrid_Metric" m ON m."MetricId"=_bf.mid WHERE m."MetricId" IS NULL;
"@ | Set-Content -Path $tmp -Encoding UTF8
& $psql -h $DBHost -p $DBPort -U $AppUser -d $Database -v ON_ERROR_STOP=1 -f $tmp
Remove-Item $tmp -ErrorAction SilentlyContinue
$nullCnt = Psql-Scalar "SELECT count(*) FROM (VALUES $values) v(mid) JOIN public.""RTSGrid_Metric"" m ON m.""MetricId""=v.mid WHERE m.""DisplayName"" IS NULL;"
$catTot  = Psql-Scalar "SELECT count(*) FROM public.""RTSGrid_Metric"" WHERE ""DisplayName"" IS NOT NULL;"
if ([int]$nullCnt -ne 0) { $fail += "backfill: $nullCnt present targets still NULL DisplayName" }
else { Write-Host "  (b) backfill OK — 0 NULL among present targets; catalogued=$catTot (expected ~$ExpectedCatalogued)" -ForegroundColor Green }
if ([int]$catTot -ne $ExpectedCatalogued) {
    Write-Host "  (b) NOTE: catalogued=$catTot vs expected $ExpectedCatalogued — review MISSING_FROM_DB above." -ForegroundColor Yellow
}

# (c) RTSData_SetUserStatus — single 15-param procedure with log insert
$pCount = Psql-Scalar "SELECT count(*) FROM pg_proc WHERE proname='RTSData_SetUserStatus';"
$pKind  = Psql-Scalar "SELECT prokind FROM pg_proc WHERE proname='RTSData_SetUserStatus';"
$pArgs  = Psql-Scalar "SELECT pronargs FROM pg_proc WHERE proname='RTSData_SetUserStatus';"
$pLog   = Psql-Scalar "SELECT (prosrc LIKE '%RTSData_UserStatusLog%') FROM pg_proc WHERE proname='RTSData_SetUserStatus';"
if ($pCount -ne "1") { $fail += "RTSData_SetUserStatus count=$pCount (expected 1)" }
elseif ($pKind -ne "p") { $fail += "RTSData_SetUserStatus prokind=$pKind (expected p)" }
elseif ($pArgs -ne "15") { $fail += "RTSData_SetUserStatus pronargs=$pArgs (expected 15)" }
elseif ($pLog -ne "t") { $fail += "RTSData_SetUserStatus missing UserStatusLog write" }
else { Write-Host "  (c) RTSData_SetUserStatus: 1 procedure, 15 params, log insert OK" -ForegroundColor Green }

if ($fail.Count -gt 0) {
    Write-Host "" ; Write-Host "VERIFY FAILED:" -ForegroundColor Red
    $fail | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    $env:PGPASSWORD = ""; throw "Patch verification failed."
}
Write-Host "  ALL VERIFY CHECKS PASSED." -ForegroundColor Green

# --- Step 5: pg_dump for production transfer -----------------------------------------------
if (-not $SkipDump) {
    Write-Host "" ; Write-Host "[ 5/5 ] pg_dump (custom format)..." -ForegroundColor Cyan
    if (-not $pgdump) { throw "pg_dump not found." }
    if (-not $DumpPath) {
        $instDir = Join-Path $RepoRoot "Installations"
        if (-not (Test-Path $instDir)) { New-Item -ItemType Directory -Path $instDir | Out-Null }
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $DumpPath = Join-Path $instDir "${Database}_origin_v2_${stamp}.backup"
    }
    & $pgdump -h $DBHost -p $DBPort -U $AppUser -d $Database -Fc -f $DumpPath
    if ($LASTEXITCODE -ne 0) { throw "pg_dump failed." }
    $sz = [math]::Round((Get-Item $DumpPath).Length / 1MB, 2)
    Write-Host "  Dump written: $DumpPath ($sz MB)" -ForegroundColor Green
    Write-Host "  Restore to prod via deploy/Restore-SqlDump.ps1 (auto-detects custom format)." -ForegroundColor Gray
} else { Write-Host "" ; Write-Host "[ 5/5 ] pg_dump skipped (-SkipDump)." -ForegroundColor Yellow }

$env:PGPASSWORD = ""
Write-Host "" ; Write-Host "Patch-ToOriginV2 complete for $Database." -ForegroundColor Green
```

After writing: `sync && tail -3 db/tools/Patch-ToOriginV2.ps1 && wc -l db/tools/Patch-ToOriginV2.ps1`
(last line must be the closing `Write-Host`, ~250 lines).

---

## Task B — test on `rtmviewdb1` (do NOT touch `rtmviewdb` prod)

Precondition: `rtmviewdb1` exists as a near-origin/v2 copy (restored prod snapshot or dev clone).
If it does NOT exist, STOP and report — do not invent a baseline.

```powershell
cd "D:\Claude\Projects\RTM View Shell"
# 1. First run — applies patch, verifies, dumps:
powershell -ExecutionPolicy Bypass -File db\tools\Patch-ToOriginV2.ps1 -Database rtmviewdb1
# 2. IDEMPOTENCY — second run must be a clean no-op (EF skips, migrations ledger-skip, verify passes):
powershell -ExecutionPolicy Bypass -File db\tools\Patch-ToOriginV2.ps1 -Database rtmviewdb1 -SkipDump
```

Capture and report for BOTH runs:
- step 1 line: `Catalogue columns present: N/12`
- step 4 (a)(b)(c) results, the `CATALOGUED_TOTAL` number, and any `MISSING_FROM_DB` rows
- the dump path + size from run 1
- confirm run 2 prints `skip (applied)` for the migrations and still `ALL VERIFY CHECKS PASSED`

If `CATALOGUED_TOTAL` ≠ 198, list the MISSING_FROM_DB metric ids so the operator can confirm
they are the known duplicates/absent rows (do not "fix" by inventing metrics).

---

## Task C — commit (S3/S4/S4b) and STOP

Commit ONLY `db/tools/Patch-ToOriginV2.ps1` (prefix `db:`). The dump file goes to
`Installations/` (gitignored — do NOT commit it). Then run the S4 journal/release and S4b flush.
Do NOT push. Report the dump path to the operator for the production restore step.

## Report back to operator
- both-run verify output (the numbers above),
- dump path/size,
- whether `rtmviewdb1` existed or had to be reported as missing,
- commit hash.
