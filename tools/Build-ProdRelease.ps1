#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a unified Prod Release package: RTM View Shell + RTM Service + DB backup + Memurai.
.DESCRIPTION
    Выполняет:
      1. dotnet publish CcDashboard.Web  -> publish\shell\
      2. dotnet publish RTM\RTM          -> publish\rtm\
      3. pg_dump rtmviewdb               -> publish\db\
      4. Копирует Memurai installer      из tools\cache\
      5. Упаковывает всё в              Installations\DDMMYYYY.HHMM.zip
    Включает в zip: Install-RTMView.ps1, Update-RTMView.ps1, README.txt из deploy\

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
.PARAMETER MemuraiMsi
    Путь к Memurai MSI. По умолчанию tools\cache\memurai-developer.msi

.EXAMPLE
    .\Build-ProdRelease.ps1
    .\Build-ProdRelease.ps1 -SkipDB
    .\Build-ProdRelease.ps1 -DBPassword "MyPwd!" -DBUser "ccdashboard_user"
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
    [switch]$SkipBuild,
    [string]$MemuraiMsi  = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

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

if (-not $MemuraiMsi) {
    $MemuraiMsi = Join-Path $CacheDir "memurai-developer.msi"
}
# Resolve relative path against project root
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
    $dotnetVer = & dotnet --version 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Error "dotnet SDK not found. Install .NET 8 SDK." }
    Write-Host "  dotnet  : $dotnetVer" -ForegroundColor Gray
}

# Memurai MSI
if (-not (Test-Path $MemuraiMsi)) {
    Write-Host ""
    Write-Host "  [WARN] Memurai installer not found:" -ForegroundColor Yellow
    Write-Host "         $MemuraiMsi" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Download from https://www.memurai.com/get-memurai" -ForegroundColor Yellow
    Write-Host "  Save as: tools\cache\memurai-developer.msi" -ForegroundColor Yellow
    Write-Host ""
    Write-Error "Memurai MSI not found: $MemuraiMsi`nПоложите файл в tools\cache\ или передайте правильный путь через -MemuraiMsi."
} else {
    Write-Host "  Memurai : OK ($MemuraiMsi)" -ForegroundColor Gray
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

# ── Step 1: Build Shell ───────────────────────────────────────────────────────
if ($BuildShell) {
    if (-not $SkipBuild) {
        Write-Host ""
        Write-Host "[ 1/4 ] Building CcDashboard.Web (Shell)..." -ForegroundColor Cyan
        if (Test-Path $PublishShell) { Remove-Item -Recurse -Force $PublishShell }
        & dotnet publish $ShellProj -c Release -r win-x64 --self-contained true -o $PublishShell
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
        & dotnet publish $RTMProj -c Release -r win-x64 --self-contained true -o $PublishRTM
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
if (-not $SkipDB) {
    Write-Host "[ 3/4 ] Running pg_dump for $DBName..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PublishDB -Force | Out-Null
    $dumpFile = Join-Path $PublishDB ("$DBName`_" + (Get-Date -Format "ddMMyyyy") + ".sql")

    $env:PGPASSWORD = $DBPassword
    & pg_dump -h $DBHost -p $DBPort -U $DBUser -d $DBName -F p --no-password -f $dumpFile
    $env:PGPASSWORD = ""

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dumpFile)) {
        Write-Host "  [WARN] pg_dump failed. DB backup will not be included." -ForegroundColor Yellow
    } else {
        $sizeMB = [math]::Round((Get-Item $dumpFile).Length / 1MB, 2)
        Write-Host "  Dump  : $dumpFile ($sizeMB MB)" -ForegroundColor Green
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
}

# DB backup
if (-not $SkipDB -and (Test-Path $PublishDB)) {
    $stgDB = Join-Path $StagingDir "DB"
    Copy-Item -Recurse -Force $PublishDB $stgDB
    Write-Host "  + DB/" -ForegroundColor Gray
}

# Memurai — only when RTM is included (Redis is RTM dependency)
if ($BuildRTM -and $MemuraiMsi -and (Test-Path $MemuraiMsi)) {
    $stgExtras = Join-Path $StagingDir "Extras"
    New-Item -ItemType Directory -Path $stgExtras -Force | Out-Null
    Copy-Item $MemuraiMsi -Destination $stgExtras -Force
    Write-Host "  + Extras/memurai-developer.msi" -ForegroundColor Gray
}

# Deploy scripts and README
foreach ($f in @("Install-RTMView.ps1", "Update-RTMView.ps1", "README.txt")) {
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
