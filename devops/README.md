# RTM View Shell — Server Upgrade Runbook

> **What this is:** the single, complete, step-by-step procedure for upgrading an
> already-installed RTM View Shell server (Shell + RTM Service + DB) to a new release.
> Everything you need is in this `devops/` folder. Follow the steps in order.
> Do not skip the pre-flight checks — they are the difference between a 20-minute
> upgrade and a 2-hour blind recovery.

---

## ⚠ КРИТИЧНО — прочитать перед стартом (RU)

Три вещи, которые ломали апгрейд раньше. Не пропускай:

1. **Shell `appsettings.json` затирается при деплое бинарников.** На server45 Shell не
   стартовал, потому что publish перезаписал рабочий `appsettings.json`. **STEP 6** —
   ОБЯЗАТЕЛЬНО сделать резервную копию обоих `appsettings.json` И `appsettings.Production.json`
   ПЕРЕД копированием бинарников, и вернуть их ПОСЛЕ. Проверить, что Shell стартует.
2. **Миграция `20260605_004_metrics_dedup.sql` падает (42703).** Она содержит 4 битые строки.
   Если она в наборе to-apply — DB-фаза умрёт на ON_ERROR_STOP. На момент написания её чинит
   отдельная сессия. **Не запускай DB-фазу, пока я не подтвержу, что `_004` исправлена.**
3. **PS1-файлы должны быть UTF-8 BOM + CRLF** (§35). Все скрипты в этой папке уже такие.
   Если правишь руками — сохраняй с BOM, иначе Windows PowerShell 5.1 упадёт на парсинге.

Пароль БД (postgres и ccdashboard_user на тестовых серверах): `!@#qweASDzxc`
PostgreSQL: server45 → PG17, остальные → **PG18** (`C:\Program Files\PostgreSQL\18\bin`).

---

## 0. Roles, paths, names (confirm these for YOUR target server)

| Thing | Value (default) | Confirm on target |
|---|---|---|
| DB name | `rtmviewdb` | `\l` in psql |
| DB app user | `ccdashboard_user` | read-only is enough for Compare/probe |
| DB superuser | `postgres` | needed for migrations + functions (DDL) |
| Install root | `C:\RTMView` (Shell\, RTM\) — orchestrator default | **verify**: some installs use `C:\Program Files\CcDashboard` |
| Ops root | `C:\RTMView-Ops` (§43) | create if absent |
| Shell service | `RTMViewShell` | `Get-Service` |
| RTM service | `RTMService` | `Get-Service` |
| IIS app pools | `CcDashboard.Web`, `CcDashboard.Api` | `Get-WebAppPoolState` |
| psql / pg_dump | `C:\Program Files\PostgreSQL\18\bin` | PG17 on server45 |

> **Ops layout (§43):** `C:\RTMView-Ops\incoming\` (staged scripts), `applied\` (archive + `_ledger.txt`),
> `output\` (reports + logs), `backup\` (pre-change pg_dump + binary backups).

---

## 1. What's in this folder

```
devops/
├── README.md                         ← this runbook
└── tools/
    ├── Compare-ToBaseline.ps1         ← READ-ONLY drift report: server vs repo baseline
    ├── Apply-Server45Upgrade.ps1      ← automated orchestrator (see §A — status/caveats!)
    ├── server45_dependency_probe.sql  ← READ-ONLY go/no-go pre-flight gate
    ├── Restore-SqlDump.ps1            ← DB restore (rollback)
    ├── Update-RTMView.ps1             ← binary deploy helper
    ├── Install-RTMView.ps1            ← fresh-install helper (not used for upgrade)
    ├── functions/                     ← 4 function files (for the orchestrator)
    ├── migrations/                    ← all 16 migration files (for the orchestrator)
    ├── db/                            ← FULL repo baseline (schema+functions+data+migrations)
    │                                     used by Compare-ToBaseline -BaselineDir
    └── known-fixes/
        └── fix_setchatmessage_server45.sql  ← standalone RTM-SEC-002 fix (reference)
```

**Two ways to do the upgrade:**
- **MANUAL (recommended, fully visible)** — STEPs 1–10 below. You see every command.
- **AUTOMATED** — the orchestrator, §A. Faster but currently s45/PG17-shaped; read its caveats first.

Binaries (Shell + RTM published output) are **built on a Windows machine** and copied to the
server — they are NOT in this folder (see STEP 5).

---

## 2. Before you start — build the binaries (on Windows, from the repo)

From the repo root `D:\Claude\Projects\RTM View Shell`:

```powershell
# Option A — prod-release skill / Build-ProdRelease.ps1 (preferred; produces a zip)
powershell -ExecutionPolicy Bypass -File tools\Build-ProdRelease.ps1 -Mode Full -DBPassword "!@#qweASDzxc"

# Option B — direct publish (fallback if Build-ProdRelease has issues)
dotnet publish src\CcDashboard.Web -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\shell"
dotnet publish RTM\RTM          -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTM View Shell\publish\rtm"
```

Result you carry to the server: a `Shell\` folder and an `RTM\` folder of published binaries.

---

## 3. STEP 1 — Transfer everything to the server

Copy to `C:\RTMView-Ops\incoming\` on the target server:

| From (this folder / build) | To (server) |
|---|---|
| `devops\tools\` (whole folder) | `C:\RTMView-Ops\incoming\tools\` |
| published `Shell\` | `C:\RTMView-Ops\incoming\bin\Shell\` |
| published `RTM\` | `C:\RTMView-Ops\incoming\bin\RTM\` |

After copy, on the server:

```powershell
# sanity: tools present
Get-ChildItem C:\RTMView-Ops\incoming\tools
Get-ChildItem C:\RTMView-Ops\incoming\tools\migrations   # expect 16 .sql
Get-ChildItem C:\RTMView-Ops\incoming\tools\functions    # expect 4 .sql
# ops dirs exist
foreach ($d in "output","backup","applied") { New-Item -ItemType Directory -Force "C:\RTMView-Ops\$d" | Out-Null }
```

---

## 4. STEP 2 — Compare-ToBaseline (READ-ONLY) → know the gap

This tells you EXACTLY what the server is missing vs the repo baseline: schema drift (A),
routine-kind drift (B = the RTM-SEC-002 / 42809 class), metric drift (C), and which migrations
are unapplied (D). It NEVER writes to the DB. Run it FIRST.

```powershell
cd C:\RTMView-Ops\incoming\tools
powershell -ExecutionPolicy Bypass -File .\Compare-ToBaseline.ps1 `
  -Database "rtmviewdb" `
  -User "ccdashboard_user" `
  -Password "!@#qweASDzxc" `
  -BaselineDir "C:\RTMView-Ops\incoming\tools\db" `
  -OutDir "C:\RTMView-Ops\output"
```

`-BaselineDir` is **required** here (standalone run — there's no repo on the server).
Output: `C:\RTMView-Ops\output\baseline_delta_rtmviewdb_<ts>.txt` (read it) and an
`align_*.sql` (⚠ **advisory only — do NOT run on a real server**, it can revert a correct
server against a stale baseline, see CLAUDE.md §38.5).

**What to read in the delta:**
- **B (ROUTINE KIND):** must end at **B=0** after the upgrade. Any "expected PROCEDURE, server
  has FUNCTION" is an RTM-SEC-002 hole that will 42809 the RTM Service.
- **D (MIGRATION LEDGER):** the `[MISSING]` list = your **to-apply set** for STEP 7.
- A and C are informational; don't auto-fix schema with raw ALTERs.

> **Send the delta `.txt` back to the coordinator session** before proceeding — it confirms the
> exact migration set and catches false-MISSING probes.

---

## 5. STEP 3 — Pre-flight probe (READ-ONLY) → go / no-go

```powershell
cd C:\RTMView-Ops\incoming\tools
$env:PGPASSWORD = "!@#qweASDzxc"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -h localhost -U ccdashboard_user -d rtmviewdb -f .\server45_dependency_probe.sql
$env:PGPASSWORD = $null
```

Every row must be `...|t` **except** `db_patch_history` which may be `f` (the `_002` migration
creates it). **Any other `|f` → STOP**, do not begin the upgrade, report to coordinator.

---

## 6. STEP 4 — Backups (rollback point) — do BOTH

**4a. Database (custom-format dump):**
```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$env:PGPASSWORD = "!@#qweASDzxc"
& "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" -h localhost -U postgres -d rtmviewdb -Fc `
  -f "C:\RTMView-Ops\backup\rtmviewdb_$ts.backup"
$env:PGPASSWORD = $null
# verify the file is > a few KB
Get-Item "C:\RTMView-Ops\backup\rtmviewdb_$ts.backup" | Select Length
```

**4b. Current binaries:**
```powershell
$bk = "C:\RTMView-Ops\backup\binaries_$ts"
New-Item -ItemType Directory -Force $bk | Out-Null
Copy-Item "C:\RTMView\Shell" "$bk\Shell" -Recurse -Force   # adjust install root if different
Copy-Item "C:\RTMView\RTM"   "$bk\RTM"   -Recurse -Force
```

> Keep `$ts` / `$bk` in the same PowerShell session — rollback (§ROLLBACK) reuses them.

---

## 7. STEP 5 — Stop services (downtime window opens)

```powershell
Stop-Service RTMService   -Force -ErrorAction SilentlyContinue
Stop-Service RTMViewShell -Force -ErrorAction SilentlyContinue
Import-Module WebAdministration
Stop-WebAppPool CcDashboard.Web -ErrorAction SilentlyContinue
Stop-WebAppPool CcDashboard.Api -ErrorAction SilentlyContinue
Get-Service RTMService, RTMViewShell | Select Name, Status
```

---

## 8. STEP 6 — Deploy binaries  ⚠ PRESERVE CONFIGS

**This is the step that bit us on server45.** Save the configs first, copy, then restore them.

```powershell
$shellDir = "C:\RTMView\Shell"   # adjust to your install root
$rtmDir   = "C:\RTMView\RTM"

# --- 6a. SAVE configs that must survive the copy ---
# Shell — BOTH must be preserved (the install uses plain appsettings.json):
$shellKeep = "appsettings.json","appsettings.Production.json","web.config","nlog.config"
$save = "C:\RTMView-Ops\backup\config_$ts"; New-Item -ItemType Directory -Force $save | Out-Null
foreach ($f in $shellKeep) { if (Test-Path "$shellDir\$f") { Copy-Item "$shellDir\$f" "$save\shell_$f" -Force } }
# RTM — runtime/state files (binary): data.sys, appsettings.json, log4net.config, app.dat:
$rtmKeep = "data.sys","appsettings.json","log4net.config","app.dat"
foreach ($f in $rtmKeep) { if (Test-Path "$rtmDir\$f") { Copy-Item "$rtmDir\$f" "$save\rtm_$f" -Force } }

# --- 6b. COPY new binaries over ---
Copy-Item "C:\RTMView-Ops\incoming\bin\Shell\*" $shellDir -Recurse -Force
Copy-Item "C:\RTMView-Ops\incoming\bin\RTM\*"   $rtmDir   -Recurse -Force

# --- 6c. RESTORE the preserved configs ---
foreach ($f in $shellKeep) { if (Test-Path "$save\shell_$f") { Copy-Item "$save\shell_$f" "$shellDir\$f" -Force } }
foreach ($f in $rtmKeep)   { if (Test-Path "$save\rtm_$f")   { Copy-Item "$save\rtm_$f"   "$rtmDir\$f"   -Force } }

# --- 6d. CONFIRM appsettings.json survived (this is the s45 failure point) ---
Get-Content "$shellDir\appsettings.json" -TotalCount 5
Get-Content "$rtmDir\appsettings.json"   -TotalCount 5
```

If `appsettings.json` is empty or wrong → restore from `$save` (or `$bk` binary backup) before going on.

---

## 9. STEP 7 — Apply migrations (as postgres, name-ordered, fail-fast)

Apply ONLY the migrations the Compare delta (STEP 2, dimension D) marked `[MISSING]`,
in **filename order**. Each runs with `-v ON_ERROR_STOP=1` so a failure halts immediately.

> ⚠ If `20260605_004_metrics_dedup.sql` is in your MISSING set — **do NOT apply it until
> confirmed fixed** (it currently raises 42703). Ask the coordinator session.

```powershell
$env:PGPASSWORD = "!@#qweASDzxc"
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$migDir = "C:\RTMView-Ops\incoming\tools\migrations"

# EXAMPLE — replace with YOUR delta's MISSING set, in order:
$toApply = @(
  "20260604_001_add_agent_state_pct_metrics.sql"
  # "20260605_004_metrics_dedup.sql"   # <-- only when confirmed fixed
  "20260606_005_history_unavailable_metrics.sql"
  "20260606_008_daytrend_fn_bu_scope.sql"
  "20260607_002_db_patch_history.sql"
  "20260607_003_fix_curlogintimestamp.sql"
)
foreach ($m in $toApply) {
  Write-Host "Applying $m ..."
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$migDir\$m"
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $m — STOP, go to ROLLBACK" -ForegroundColor Red; break }
  Add-Content "C:\RTMView-Ops\applied\_ledger.txt" "$(Get-Date -Format s) | $m | OK"
}
$env:PGPASSWORD = $null
```

---

## 10. STEP 8 — Re-apply all functions (as postgres)

Functions are idempotent (`CREATE OR REPLACE`, sig-agnostic DROP for the RTM-SEC-002 routines).
Re-apply all four, in order:

```powershell
$env:PGPASSWORD = "!@#qweASDzxc"
$fnDir = "C:\RTMView-Ops\incoming\tools\functions"
foreach ($f in "01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql") {
  Write-Host "Applying $f ..."
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$fnDir\$f"
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $f — STOP, go to ROLLBACK" -ForegroundColor Red; break }
}
$env:PGPASSWORD = $null
```

---

## 11. STEP 9 — Start services

```powershell
Start-WebAppPool CcDashboard.Web -ErrorAction SilentlyContinue
Start-WebAppPool CcDashboard.Api -ErrorAction SilentlyContinue
Start-Service RTMViewShell
Start-Sleep 5; Get-Service RTMViewShell | Select Name, Status   # must be Running
Start-Service RTMService
Start-Sleep 5; Get-Service RTMService   | Select Name, Status   # must be Running
```

If `RTMViewShell` will not start → 99% it's `appsettings.json` (STEP 6). Restore it from
`$save` / `$bk`, then `Start-Service RTMViewShell` again.

---

## 12. STEP 10 — Verify (the upgrade is NOT done until these pass)

1. **Routine kind clean (B=0)** — re-run Compare (STEP 2). The delta must show
   `B. Routine kind issues: 0`.
2. **RTM log clean** — no `42809` (wrong object type) / `42883` (no such function):
   ```powershell
   Get-Content "C:\RTMView\RTM\logs\*.log" -Tail 80 | Select-String "42809|42883|ERROR"
   ```
   (adjust log path to your RTM install).
3. **Shell up** — browse to the site, log in.
4. **DayTrend widget renders** — open a dashboard with a DayTrend widget; the chart must draw
   (proves the `_008` fn + new Shell binaries are paired — RTM-DEPLOY-001).

All four green → upgrade complete. Archive: move applied scripts to `C:\RTMView-Ops\applied\`,
keep the log in `output\`. Report GREEN to coordinator.

Any failure → ROLLBACK.

---

## ROLLBACK (if any step fails)

```powershell
# 1. stop again
Stop-Service RTMService, RTMViewShell -Force -ErrorAction SilentlyContinue
Stop-WebAppPool CcDashboard.Web; Stop-WebAppPool CcDashboard.Api

# 2. restore DB from the STEP 4a dump
powershell -ExecutionPolicy Bypass -File C:\RTMView-Ops\incoming\tools\Restore-SqlDump.ps1 `
  -DumpFile "C:\RTMView-Ops\backup\rtmviewdb_$ts.backup" -Database rtmviewdb -SuperPassword "!@#qweASDzxc"

# 3. restore binaries from the STEP 4b backup
Copy-Item "$bk\Shell\*" "C:\RTMView\Shell" -Recurse -Force
Copy-Item "$bk\RTM\*"   "C:\RTMView\RTM"   -Recurse -Force

# 4. start
Start-WebAppPool CcDashboard.Web; Start-WebAppPool CcDashboard.Api
Start-Service RTMViewShell; Start-Service RTMService
```

---

## Troubleshooting — real failures we have hit

| Symptom | Cause | Fix |
|---|---|---|
| `RTMViewShell` won't start after deploy | publish clobbered Shell `appsettings.json` (STEP 6) | restore `appsettings.json` from `$save` / binary backup, restart |
| Migration `_004` → `ERROR: column "MetricId" does not exist (42703)` | `_004_metrics_dedup.sql` has 4 invalid `UPDATE "RTSGrid_Column" SET "MetricId"` lines | skip until fixed; coordinator is repairing it |
| PS1 fails: `Unexpected token` / mojibake | file is not UTF-8 BOM (§35) | re-save as UTF-8 **with BOM**, CRLF |
| RTM log floods `42809 wrong object type` | an RTM-write routine is a FUNCTION, must be PROCEDURE (RTM-SEC-002) | re-apply `functions/01` + `02`; for a stuck one use `known-fixes/fix_setchatmessage_server45.sql` pattern (sig-agnostic DROP + CREATE PROCEDURE) |
| `42883 no such function` right after migration | fn signature changed but old Shell still calls old sig (RTM-DEPLOY-001) | ship DB + Shell together; never apply the fn migration without the matching Shell build |
| Compare reports a migration MISSING that you know is applied | pre-ledger probe heuristic (dimension D) | cross-check manually; the `db_patch_history` ledger makes newer migrations exact |
| `Compare-ToBaseline` → "Cannot derive repo root" | ran standalone without `-BaselineDir` | pass `-BaselineDir C:\RTMView-Ops\incoming\tools\db` |

---

## §A. Automated option — Apply-Server45Upgrade.ps1 (read caveats first)

The orchestrator runs STEPs 3→9 in one go (probe → stop → DB backup → deploy binaries →
migrations → functions → start → prints verify + rollback). Run it from
`C:\RTMView-Ops\incoming\tools` (it expects `server45_dependency_probe.sql`, `migrations\`,
`functions\` next to itself — all present in this bundle).

```powershell
cd C:\RTMView-Ops\incoming\tools
.\Apply-Server45Upgrade.ps1 `
  -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc" `
  -InstallRoot "C:\RTMView" `
  -ShellPublish "C:\RTMView-Ops\incoming\bin\Shell" `
  -RtmPublish   "C:\RTMView-Ops\incoming\bin\RTM"
```

**⚠ Current caveats — why the MANUAL path is recommended right now:**
- **Migration list is hardcoded** to the server45 to-apply set (6 entries, incl. the broken
  `_004`). For a different server it is the WRONG set — the orchestrator does not read your
  Compare delta. Until a per-server / delta-driven variant exists, prefer manual STEP 7.
- **Shell-preserve list is missing plain `appsettings.json`** (only `.Production.json`,
  `web.config`, `nlog.config`). This is the server45 failure. Hardening is pending; until then,
  do STEP 6a/6c manually even if you use the orchestrator, and verify STEP 6d.
- It is labelled PG17/server45 but `Find-PGTool` already prefers PG18, so tool discovery works
  on PG18 boxes. A clean `-PgVersion` parameter + delta-driven migration set are pending review.

When the hardened, delta-driven version lands, this section will be updated and the orchestrator
becomes the primary path.

---

*Bundle assembled from repo HEAD (origin/v2). Tools are copies — the source of truth lives in
`db/`, `deploy/`, `staging/` in the repo. Regenerate this bundle after any change to those.*
