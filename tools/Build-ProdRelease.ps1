#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a unified Prod Release package: RTM View Shell + RTM Service + DB backup + Garnet (Redis alternative).
.DESCRIPTION
    Выполняет:
      1. dotnet publish CcDashboard.Web  -> publish\shell\
      2. dotnet publish RTM\RTM          -> publish\rtm\
      3. pg_dump rtmviewdb               -> publish\db\
      4. Копирует Garnet + NSSM          из tools\cache\garnet-*\ и tools\cache\nssm\
      5. Упаковывает всё в              Installations\DDMMYYYY.HHMM.zip
    Включает в zip: Install-RTMView.ps1, Update-RTMView.ps1, README.txt из deploy\

    NOTE: Memurai MSI is deprecated. Garnet (MIT, native Windows) replaces it as of INC-001(d) Phase 2.
    For rollback to Memurai, pass -UseMemurai (retained for rollback path).

.PARAMETER DBHost
    PostgreSQL хост (default: localhost)
.PARAMETER DBPort
    PostgreSQL порт (default: 5432)
.PARAMETER DBName
    Имя базы данных (default: rtmviewdb)
.PARAMETER DBUser
    Пользователь PostgreSQL (default: postgres)
.PARAMETER DBPassword
    Пароль PostgreSQL (если пусто — используется .pgpass или peer-auth)
.PARAMETER SkipDB
    Пропустить pg_dump (если backup уже есть или делается отдельно)
.PARAMETER SkipBuild
    Пропустить dotnet publish (использовать уже готовые publish\shell\ и publish\rtm\)
.PARAMETER UseMemurai
    Use legacy Memurai MSI instead of Garnet (rollback path). Default: Garnet.
.PARAMETER GarnetDir
    Path to Garnet net8.0 binaries folder. Default: tools\cache\garnet-1.1.10-win-x64-net8\
.PARAMETER NssmDir
    Path to NSSM folder (contains nssm.exe). Default: tools\cache\nssm\

.EXAMPLE
    .\Build-ProdRelease.ps1
    .\Build-ProdRelease.ps1 -SkipDB
    .\Build-ProdRelease.ps1 -DBPassword "MyPwd!" -DBUser "ccdashboard_user"
    .\Build-ProdRelease.ps1 -UseMemurai  # Rollback to Memurai (deprecated)
#>

[CmdletBinding()]
param(
    # Build mode: Full | Shell | RTM
    #   Full  = Shell + RTM + DB (default)
    #   Shell = Shell + DB only
    #   RTM   = RTM + DB only
    [ValidateSet("Full","Shell","RTM")]
    [string]$Mode        = "Full",

    [string]$DBHost      = "localhost",
    [int]   $DBPort      = 5432,
    [string]$DBName      = "rtmviewdb",
    [string]$DBUser      = "postgres",
    [string]$DBPassword  = "",
    [switch]$SkipDB,
    [string]$DumpFile    = "",
    [switch]$SkipBuild,
    [switch]$UseMemurai,
    [string]$GarnetDir   = "",
    [string]$NssmDir     = "",
    [string]$MemuraiMsi  = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Helper: run native commands (git, dotnet) without stderr throwing under -Stop
function Invoke-Native([scriptblock]$Sb) {
    $p = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & $Sb } finally { $ErrorActionPreference = $p }
}

# ── Mode flags ────────────────────────────────────────────────────────────────
$BuildShell = $Mode -in @("Full","Shell")
$BuildRTM   = $Mode -in @("Full","RTM")

# ── Paths ─────────────────────────────────────────────────────────────────────
$Root         = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ShellProj    = Join-Path $Root "src\CcDashboard.Web\CcDashboard.Web.csproj"
$RTMProj      = Join-Path $Root "RTM\RTM\RTM.csproj"
$PublishShell = Join-Path $Root "publish\shell"
$PublishRTM   = Join-Path $Root "publish\rtm"
$PublishDB    = Join-Path $Root "publish\db"
$DeployDir    = Join-Path $Root "deploy"
$CacheDir     = Join-Path $Root "tools\cache"
$OutDir       = Join-Path $Root "Installations"

# Garnet defaults (INC-001(d) Phase 2 — Memurai replacement)
if (-not $GarnetDir) {
    $GarnetDir = Join-Path $CacheDir "garnet-1.1.10-win-x64-net8"
}
if ($GarnetDir -and -not [System.IO.Path]::IsPathRooted($GarnetDir)) {
    $GarnetDir = Join-Path $Root $GarnetDir
}
if (-not $NssmDir) {
    $NssmDir = Join-Path $CacheDir "nssm"
}
if ($NssmDir -and -not [System.IO.Path]::IsPathRooted($NssmDir)) {
    $NssmDir = Join-Path $Root $NssmDir
}

# Memurai path (legacy rollback)
if (-not $MemuraiMsi) {
    $MemuraiMsi = Join-Path $CacheDir "Memurai-for-Redis-v4.2.2.msi"
}
if ($MemuraiMsi -and -not [System.IO.Path]::IsPathRooted($MemuraiMsi)) {
    $MemuraiMsi = Join-Path $Root $MemuraiMsi
}

$Timestamp    = Get-Date -Format "ddMMyyyy.HHmm"
$ModeSuffix   = if ($Mode -ne "Full") { "_$Mode" } else { "" }
$ZipName      = "$Timestamp$ModeSuffix.zip"
$ZipPath      = Join-Path $OutDir $ZipName
$StagingDir   = Join-Path $env:TEMP "RTMRelease_$Timestamp"

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          RTM View Shell — Prod Release Builder       ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  Mode   : $Mode" -ForegroundColor Cyan
Write-Host "║  Output : $ZipName" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Pre-flight checks ─────────────────────────────────────────────────────────
Write-Host "[ PRE-FLIGHT ]" -ForegroundColor Yellow

# dotnet
if (-not $SkipBuild) {
    $dotnetVer = Invoke-Native { & dotnet --version 2>&1 }
    if ($LASTEXITCODE -ne 0) { Write-Error "dotnet SDK not found. Install .NET 8 SDK." }
    Write-Host "  dotnet  : $dotnetVer" -ForegroundColor Gray
}

# Cache check: Garnet (default) or Memurai (rollback)
if ($UseMemurai) {
    # Legacy Memurai path
    if (-not (Test-Path $MemuraiMsi)) {
        Write-Host ""
        Write-Host "  [WARN] Memurai installer not found:" -ForegroundColor Yellow
        Write-Host "         $MemuraiMsi" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Download from https://www.memurai.com/get-memurai" -ForegroundColor Yellow
        Write-Host "  Save as: tools\cache\Memurai-for-Redis-v4.2.2.msi" -ForegroundColor Yellow
        Write-Host ""
        Write-Error "Memurai MSI not found: $MemuraiMsi`nПоложите файл в tools\cache\ или передайте правильный путь через -MemuraiMsi."
    } else {
        Write-Host "  Memurai : OK ($MemuraiMsi) [LEGACY ROLLBACK]" -ForegroundColor Yellow
    }
} else {
    # Garnet (default, INC-001(d))
    $garnetExe = Join-Path $GarnetDir "GarnetServer.exe"
    if (-not (Test-Path $garnetExe)) {
        Write-Host ""
        Write-Host "  [ERROR] Garnet binaries not found:" -ForegroundColor Red
        Write-Host "          $GarnetDir" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Download Garnet 1.1.10 from:" -ForegroundColor Yellow
        Write-Host "    https://github.com/microsoft/garnet/releases/tag/v1.1.10" -ForegroundColor Yellow
        Write-Host "  Get: win-x64-based-readytorun.zip -> extract net8.0 folder -> tools\cache\garnet-1.1.10-win-x64-net8\" -ForegroundColor Yellow
        Write-Host ""
        Write-Error "Garnet not found: $garnetExe`nDownload and extract to tools\cache\garnet-1.1.10-win-x64-net8\"
    } else {
        Write-Host "  Garnet  : OK ($GarnetDir)" -ForegroundColor Gray
    }
    # NSSM check
    $nssmExe = Join-Path $NssmDir "nssm.exe"
    if (-not (Test-Path $nssmExe)) {
        Write-Host ""
        Write-Host "  [ERROR] NSSM not found:" -ForegroundColor Red
        Write-Host "          $NssmDir" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Download NSSM (public domain) from:" -ForegroundColor Yellow
        Write-Host "    https://nssm.cc/download" -ForegroundColor Yellow
        Write-Host "  Extract nssm.exe (win64 version) to: tools\cache\nssm\" -ForegroundColor Yellow
        Write-Host ""
        Write-Error "NSSM not found: $nssmExe`nDownload and extract to tools\cache\nssm\"
    } else {
        Write-Host "  NSSM    : OK ($NssmDir)" -ForegroundColor Gray
    }
}

# pg_dump
if (-not $SkipDB) {
    $pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
    if (-not $pgDump) {
        # Try to find pg_dump in standard locations
        $pgDump = @(18,17,16,15,14,13) |
            ForEach-Object { "C:\Program Files\PostgreSQL\$_\bin\pg_dump.exe" } |
            Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($pgDump) { $env:PATH += ";$(Split-Path $pgDump)" }
    } else {
        $pgDump = $pgDump.Source
    }
    if (-not $pgDump) {
        Write-Host "  [WARN] pg_dump not found — DB backup will be skipped." -ForegroundColor Yellow
        $SkipDB = $true
    } else {
        Write-Host "  pg_dump : $pgDump" -ForegroundColor Gray
    }
}

New-Item -ItemType Directory -Path $OutDir   -Force | Out-Null
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null


# ── Step 0: Integrity check — restore truncated files from HEAD (§0.6a/PD-007) ──
Write-Host ""
Write-Host "[ 0/4 ] Integrity check — restoring any truncated files from HEAD..." -ForegroundColor Cyan

$modified = Invoke-Native { & git diff --name-only HEAD 2>$null }
foreach ($f in $modified) {
    if (-not (Test-Path $f)) { continue }
    $headLines = (Invoke-Native { & git show "HEAD:$f" 2>$null } | Measure-Object -Line).Lines
    $wtLines   = (Get-Content $f | Measure-Object -Line).Lines
    if ($headLines -gt 5 -and $wtLines -lt [math]::Floor($headLines * 0.90)) {
        Write-Host "  TRUNCATED: $f (HEAD=$headLines, wt=$wtLines) — restoring" -ForegroundColor Yellow
        Invoke-Native { & git show "HEAD:$f" } | Set-Content $f -Encoding UTF8
    }
}
Write-Host "  Integrity check done." -ForegroundColor Green

# ── Step 1: Build Shell ───────────────────────────────────────────────────────
if ($BuildShell) {
    if (-not $SkipBuild) {
        Write-Host ""
        Write-Host "[ 1/4 ] Building CcDashboard.Web (Shell)..." -ForegroundColor Cyan
        if (Test-Path $PublishShell) { Remove-Item -Recurse -Force $PublishShell }
        Invoke-Native { & dotnet publish $ShellProj -c Release -r win-x64 --self-contained true -o $PublishShell }
        if ($LASTEXITCODE -ne 0) { Write-Error "Shell build failed." }
        Write-Host "  Done: $PublishShell" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ 1/4 ] Shell build skipped (using existing $PublishShell)" -ForegroundColor Yellow
        if (-not (Test-Path $PublishShell)) { Write-Error "publish\shell\ not found. Run without -SkipBuild." }
    }
} else {
    Write-Host ""
    Write-Host "[ 1/4 ] Shell — skipped (Mode=$Mode)" -ForegroundColor Gray
}

# ── Step 2: Build RTM Service ─────────────────────────────────────────────────
if ($BuildRTM) {
    if (-not $SkipBuild) {
        Write-Host ""
        Write-Host "[ 2/4 ] Building RTM Service..." -ForegroundColor Cyan
        if (Test-Path $PublishRTM) { Remove-Item -Recurse -Force $PublishRTM }
        Invoke-Native { & dotnet publish $RTMProj -c Release -r win-x64 --self-contained true -o $PublishRTM }
        if ($LASTEXITCODE -ne 0) { Write-Error "RTM build failed." }
        Write-Host "  Done: $PublishRTM" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ 2/4 ] RTM build skipped (using existing $PublishRTM)" -ForegroundColor Yellow
        if (-not (Test-Path $PublishRTM)) { Write-Error "publish\rtm\ not found. Run without -SkipBuild." }
    }
} else {
    Write-Host ""
    Write-Host "[ 2/4 ] RTM — skipped (Mode=$Mode)" -ForegroundColor Gray
}

# ── Step 3: DB Backup ─────────────────────────────────────────────────────────
Write-Host ""
if ($DumpFile -ne "" -and (Test-Path $DumpFile)) {
    Write-Host "[ 3/4 ] Using existing dump: $DumpFile" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $destDump = Join-Path $PublishDB ([System.IO.Path]::GetFileName($DumpFile))
    Copy-Item $DumpFile -Destination $destDump -Force
    $sizeMB = [math]::Round((Get-Item $destDump).Length / 1MB, 2)
    Write-Host "  Dump  : $destDump ($sizeMB MB)" -ForegroundColor Green
} elseif (-not $SkipDB) {
    Write-Host "[ 3/4 ] Running pg_dump for $DBName..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $pgDumpFile = Join-Path $PublishDB ("$DBName`_" + (Get-Date -Format "ddMMyyyy") + ".sql")

    $env:PGPASSWORD = $DBPassword
    Invoke-Native { & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F c --no-password -f $pgDumpFile }
    $env:PGPASSWORD = ""

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pgDumpFile)) {
        Write-Host "  [WARN] pg_dump failed. DB backup will not be included." -ForegroundColor Yellow
    } else {
        $sizeMB = [math]::Round((Get-Item $pgDumpFile).Length / 1MB, 2)
        Write-Host "  Dump  : $pgDumpFile ($sizeMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "[ 3/4 ] DB backup skipped." -ForegroundColor Yellow
}

# ── Step 4: Assemble staging folder ──────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/4 ] Assembling package..." -ForegroundColor Cyan

# Shell binaries
if ($BuildShell -and (Test-Path $PublishShell)) {
    $stgShell = Join-Path $StagingDir "Shell"
    Copy-Item -Recurse -Force $PublishShell $stgShell
    Write-Host "  + Shell/" -ForegroundColor Gray
    
    # C: Ship docs/metrics-catalog.json (MetricsPage reads it from content root)
    $metricsCatalog = Join-Path $Root "docs\metrics-catalog.json"
    if (Test-Path $metricsCatalog) {
        $stgShellDocs = Join-Path $stgShell "docs"
        if (-not (Test-Path $stgShellDocs)) { New-Item -ItemType Directory -Path $stgShellDocs -Force | Out-Null }
        Copy-Item $metricsCatalog -Destination $stgShellDocs -Force
        Write-Host "  + Shell/docs/metrics-catalog.json" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] docs/metrics-catalog.json not found — MetricsPage will use DB fallback" -ForegroundColor Yellow
    }
}

# RTM binaries
if ($BuildRTM -and (Test-Path $PublishRTM)) {
    $stgRTM = Join-Path $StagingDir "RTM"
    Copy-Item -Recurse -Force $PublishRTM $stgRTM
    Write-Host "  + RTM/" -ForegroundColor Gray

    # app.dat (included in package — data.sys must be provided separately)
    $appDatSrc = Join-Path $Root "RTM\deployment\app.dat"
    if (Test-Path $appDatSrc) {
        Copy-Item $appDatSrc -Destination $stgRTM -Force
        Write-Host "  + RTM/app.dat" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] RTM\deployment\app.dat not found — skipping" -ForegroundColor Yellow
    }

    # data.sys
    $dataSysSrc = Join-Path $Root "RTM\deployment\data.sys"
    if (Test-Path $dataSysSrc) {
        Copy-Item $dataSysSrc -Destination $stgRTM -Force
        Write-Host "  + RTM/data.sys" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] RTM\deployment\data.sys not found" -ForegroundColor Yellow
    }

    # log4net.config — from deployment folder
    $log4netSrc = Join-Path $Root "RTM\deployment\log4net.config"
    if (Test-Path $log4netSrc) {
        Copy-Item $log4netSrc -Destination $stgRTM -Force
        Write-Host "  + RTM/log4net.config" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] log4net.config not found in publish\rtm\" -ForegroundColor Yellow
    }
}

# DB backup (dump file)
if (-not $SkipDB -and (Test-Path $PublishDB)) {
    $stgDB = Join-Path $StagingDir "DB"
    Copy-Item -Recurse -Force $PublishDB $stgDB
    Write-Host "  + DB/ (dump)" -ForegroundColor Gray
}

# DB module (schema.sql + functions + data + tools) — required for -FreshDb mode
$dbDir = Join-Path $Root "db"
if (Test-Path $dbDir) {
    $stgDbModule = Join-Path $StagingDir "db"
    New-Item -ItemType Directory -Path $stgDbModule -Force | Out-Null

    # Copy schema.sql
    $schemaFile = Join-Path $dbDir "schema.sql"
    if (Test-Path $schemaFile) {
        Copy-Item $schemaFile -Destination $stgDbModule -Force
        Write-Host "  + db/schema.sql" -ForegroundColor Gray
    }

    # Copy setup/
    $setupDir = Join-Path $dbDir "setup"
    if (Test-Path $setupDir) {
        $stgSetup = Join-Path $stgDbModule "setup"
        Copy-Item -Recurse -Force $setupDir $stgSetup
        Write-Host "  + db/setup/" -ForegroundColor Gray
    }

    # Copy functions/
    $functionsDir = Join-Path $dbDir "functions"
    if (Test-Path $functionsDir) {
        $stgFunctions = Join-Path $stgDbModule "functions"
        Copy-Item -Recurse -Force $functionsDir $stgFunctions
        Write-Host "  + db/functions/" -ForegroundColor Gray
    }

    # Copy data/
    $dataDir = Join-Path $dbDir "data"
    if (Test-Path $dataDir) {
        $stgData = Join-Path $stgDbModule "data"
        Copy-Item -Recurse -Force $dataDir $stgData
        Write-Host "  + db/data/" -ForegroundColor Gray
    }

    # Copy tools/ (Provision-FreshDb.ps1, etc.)
    $toolsDir = Join-Path $dbDir "tools"
    if (Test-Path $toolsDir) {
        $stgTools = Join-Path $stgDbModule "tools"
        Copy-Item -Recurse -Force $toolsDir $stgTools
        Write-Host "  + db/tools/" -ForegroundColor Gray
    }
}

# Cache service — Garnet (default) or Memurai (rollback) — only when RTM is included
if ($BuildRTM) {
    $stgExtras = Join-Path $StagingDir "Extras"
    New-Item -ItemType Directory -Path $stgExtras -Force | Out-Null

    if ($UseMemurai) {
        # Legacy Memurai MSI (rollback path)
        if (Test-Path $MemuraiMsi) {
            Copy-Item $MemuraiMsi -Destination $stgExtras -Force
            Write-Host "  + Extras/$([System.IO.Path]::GetFileName($MemuraiMsi)) [LEGACY]" -ForegroundColor Yellow
        }
    } else {
        # Garnet (default, INC-001(d) Phase 2)
        $stgGarnet = Join-Path $stgExtras "Garnet"
        New-Item -ItemType Directory -Path $stgGarnet -Force | Out-Null
        Copy-Item -Path "$GarnetDir\*" -Destination $stgGarnet -Recurse -Force
        Write-Host "  + Extras/Garnet/ (net8.0 binaries)" -ForegroundColor Gray

        # Copy NSSM for service registration
        $stgNssm = Join-Path $stgExtras "nssm"
        New-Item -ItemType Directory -Path $stgNssm -Force | Out-Null
        Copy-Item -Path "$NssmDir\*" -Destination $stgNssm -Recurse -Force
        Write-Host "  + Extras/nssm/ (service wrapper)" -ForegroundColor Gray

        # Copy redis-cli if available (for health probes)
        $redisCli = Join-Path $CacheDir "redis-cli.exe"
        if (Test-Path $redisCli) {
            Copy-Item $redisCli -Destination $stgGarnet -Force
            Write-Host "  + Extras/Garnet/redis-cli.exe (health probes)" -ForegroundColor Gray
        }
    }
}

# Deploy scripts and README
foreach ($f in @("Install-RTMView.ps1", "Update-RTMView.ps1", "Restore-SqlDump.ps1", "README.txt")) {
    $src = Join-Path $DeployDir $f
    if (Test-Path $src) {
        Copy-Item $src -Destination $StagingDir -Force
        Write-Host "  + $f" -ForegroundColor Gray
    } else {
        Write-Host "  [WARN] $f not found in deploy\" -ForegroundColor Yellow
    }
}

# ── Create ZIP (CRLF + BOM for PS1/TXT — required by Windows PowerShell) ────
Write-Host ""
Write-Host "[ ZIP ] Creating $ZipName..." -ForegroundColor Cyan
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

# Convert PS1 and TXT files to UTF-8 BOM + CRLF before zipping
$BOM = [byte[]](0xEF, 0xBB, 0xBF)
Get-ChildItem $StagingDir -Recurse -Include "*.ps1","*.txt" | ForEach-Object {
    $raw = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
    $crlf = $raw -replace "`r`n", "`n" -replace "`n", "`r`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($crlf)
    $withBOM = $BOM + $bytes
    [System.IO.File]::WriteAllBytes($_.FullName, $withBOM)
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($StagingDir, $ZipPath)
Remove-Item -Recurse -Force $StagingDir

$zipMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║               BUILD COMPLETE                        ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "  Package : $ZipPath"
Write-Host "  Size    : $zipMB MB"
Write-Host "  Copy to : C:\Temp\ on target server"
Write-Host "  Install : powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1"
Write-Host "  Update  : powershell -ExecutionPolicy Bypass -File Update-RTMView.ps1"
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  *** ВАЖНО: перед установкой скопируйте data.sys в C:\RTMView\RTM\  ***" -ForegroundColor Yellow
Write-Host "  *** app.dat уже включён в пакет (RTM\app.dat)                 ***" -ForegroundColor Yellow
Write-Host ""
