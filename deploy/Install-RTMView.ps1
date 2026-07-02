#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Свежая установка RTM View Shell + RTM Service на сервер.
.DESCRIPTION
    Запускать из распакованного zip-пакета (C:\Temp\<zip>\).
    Устанавливает Garnet (Redis-compatible cache), разворачивает Shell и RTM Service,
    регистрирует Windows Services, создаёт БД и восстанавливает backup.
    Минимум ручных операций — нужен только data.sys.

    NOTE: Garnet (MIT, native Windows) replaced Memurai as of INC-001(d) Phase 2.
    For rollback to Memurai, pass -UseMemurai.

.PARAMETER Mode
    Full  = Shell + RTM (default)
    Shell = только Shell
    RTM   = только RTM
.PARAMETER InstallRoot
    Корневая папка установки (default: C:\RTMView)
.PARAMETER ShellPort / RTMPort
    Порты Kestrel (default: 5000 / 8088)
.PARAMETER DBHost / DBPort / DBName / DBUser / DBPassword
    Параметры PostgreSQL. DBPassword — пароль суперпользователя для
    создания БД и пользователя приложения.
.PARAMETER DBAppUser / DBAppPassword
    Пользователь приложения (default: ccdashboard_user).
    Создаётся автоматически если не существует.
.PARAMETER SkipDB
    Не трогать БД (уже настроена).
.PARAMETER SkipRedis
    Не устанавливать Garnet/Memurai (Redis-compatible cache уже есть).
.PARAMETER UseMemurai
    Use legacy Memurai instead of Garnet (rollback path). Default: Garnet.
.PARAMETER RedisPassword
    Пароль Garnet/Memurai/Redis. REQUIRED for Garnet (no anonymous auth).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 -Mode RTM -SkipDB
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 -DBPassword "PgSup3r!" -RedisPassword "R3dis!"
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 -UseMemurai  # Rollback to Memurai
#>

[CmdletBinding()]
param(
    [ValidateSet("Full","Shell","RTM")]
    [string]$Mode          = "Full",

    [string]$InstallRoot   = "C:\RTMView",
    [int]   $ShellPort     = 5000,
    [int]   $RTMPort       = 8088,

    # PostgreSQL — superuser (for CREATE DATABASE / CREATE USER)
    [string]$DBHost        = "localhost",
    [int]   $DBPort        = 5432,
    [string]$DBName        = "rtmviewdb",
    [string]$DBUser        = "postgres",
    [string]$DBPassword    = "",

    # PostgreSQL — application user
    [string]$DBAppUser     = "ccdashboard_user",
    [string]$DBAppPassword = "",

    [switch]$SkipDB,
    [Alias("SkipMemurai")]
    [switch]$SkipRedis,
    [switch]$UseMemurai,
    [switch]$GarnetNoAuth,     # Local dev: omit --auth/--password (bare Garnet, no auth)
    [switch]$CacheOnly,        # Install only [2/6] Garnet/Memurai, skip [3/6]-[6/6]
    [string]$RedisPassword = "",

    [string]$GarnetInstallDir = "C:\Garnet",
    [string]$GarnetSvcName = "Garnet",

    [string]$ShellSvcName  = "RTMViewShell",
    [string]$RTMSvcName    = "RTMService"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Auto-detect Mode from package contents if not explicitly overridden
if ($Mode -eq "Full") {
    $hasShell = Test-Path (Join-Path $ScriptDir "Shell")
    $hasRTM   = Test-Path (Join-Path $ScriptDir "RTM")
    if ($hasShell -and $hasRTM) { $Mode = "Full" }
    elseif ($hasShell)          { $Mode = "Shell"; Write-Host "  [Auto] No RTM\ folder found — switching to Mode=Shell" -ForegroundColor Yellow }
    elseif ($hasRTM)            { $Mode = "RTM";   Write-Host "  [Auto] No Shell\ folder found — switching to Mode=RTM" -ForegroundColor Yellow }
}

$InstallShell = $Mode -in @("Full","Shell")
$InstallRTM   = $Mode -in @("Full","RTM")

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellDest  = Join-Path $InstallRoot "Shell"
$RTMDest    = Join-Path $InstallRoot "RTM"
$BackupRoot = Join-Path $InstallRoot "Backup"
$LogPath    = Join-Path $InstallRoot "Logs"

# ── Helper: find PostgreSQL tool ──────────────────────────────────────────────
function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in 18,17,16,15,14,13,12) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = "$base\$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Invoke-PSQL([string]$Tool, [string]$Cmd, [string]$DB = "postgres") {
    $env:PGPASSWORD = $DBPassword
    $result = & $Tool -h $DBHost -p $DBPort -U $DBUser -d $DB -tAc $Cmd 2>&1
    $env:PGPASSWORD = ""
    return $result
}

function Invoke-PSQLFile([string]$Tool, [string]$File, [string]$DB) {
    $env:PGPASSWORD = $DBPassword
    & $Tool -h $DBHost -p $DBPort -U $DBUser -d $DB -f $File
    $code = $LASTEXITCODE
    $env:PGPASSWORD = ""
    return $code
}

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         RTM View Shell — FRESH INSTALLATION          ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  Mode   : $Mode"
if ($InstallShell) { Write-Host "  Shell  -> $ShellDest :$ShellPort" }
if ($InstallRTM)   { Write-Host "  RTM    -> $RTMDest   :$RTMPort"   }
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Admin check ───────────────────────────────────────────────────────────────
$p = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Run as Administrator."
}

# ── Check package contents ────────────────────────────────────────────────────
if ($InstallShell -and -not (Test-Path (Join-Path $ScriptDir "Shell"))) {
    Write-Error "Folder 'Shell\' not found. Unzip the package first, or use -Mode RTM."
}
if ($InstallRTM -and -not (Test-Path (Join-Path $ScriptDir "RTM"))) {
    Write-Error "Folder 'RTM\' not found. Unzip the package first, or use -Mode Shell."
}

# ── [1/6] Create directories ──────────────────────────────────────────────────
Write-Host "[ 1/6 ] Creating directory structure..." -ForegroundColor Cyan
foreach ($d in @($InstallRoot, $BackupRoot, $LogPath)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}
if ($InstallShell -and -not (Test-Path $ShellDest)) { New-Item -ItemType Directory -Path $ShellDest -Force | Out-Null }
if ($InstallRTM   -and -not (Test-Path $RTMDest))   { New-Item -ItemType Directory -Path $RTMDest   -Force | Out-Null }
Write-Host "  OK: $InstallRoot" -ForegroundColor Green

# ── [2/6] Install Redis-compatible cache (Garnet default, Memurai legacy) ────
Write-Host ""
Write-Host "[ 2/6 ] Redis-compatible cache (Garnet/Memurai)..." -ForegroundColor Cyan
if ($SkipRedis -or -not $InstallRTM) {
    Write-Host "  Skipped." -ForegroundColor Gray
} elseif ($UseMemurai) {
    # ── LEGACY PATH: Memurai MSI (rollback) ──────────────────────────────────
    Write-Host "  Using LEGACY Memurai (rollback path)..." -ForegroundColor Yellow
    $redisSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
    if ($redisSvc) {
        Write-Host "  Already installed — $($redisSvc.Status)" -ForegroundColor Green
    } else {
        $msi = Get-ChildItem -Path (Join-Path $ScriptDir "Extras") -Filter "*.msi" -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match "memurai|Memurai" } | Select-Object -First 1
        if (-not $msi) {
            Write-Host "  [WARN] Memurai MSI not found in Extras\ — install manually." -ForegroundColor Yellow
        } else {
            Write-Host "  Installing $($msi.Name)..." -ForegroundColor Gray
            Start-Process "msiexec.exe" -ArgumentList @("/i",$msi.FullName,"/quiet","/norestart","ADDDEFAULT=ALL") -Wait -NoNewWindow

            if ($RedisPassword) {
                $conf = "C:\Program Files\Memurai\memurai.conf"
                if (Test-Path $conf) {
                    $cfg = Get-Content $conf -Raw
                    if ($cfg -notmatch "requirepass") { Add-Content $conf "`nrequirepass $RedisPassword" }
                    else { Set-Content $conf ($cfg -replace "requirepass\s+\S+","requirepass $RedisPassword") }
                }
            }
            Start-Sleep 3
            $s = Get-Service "Memurai" -ErrorAction SilentlyContinue
            Write-Host "  Memurai: $($s.Status)" -ForegroundColor $(if ($s.Status -eq "Running") {"Green"} else {"Yellow"})
        }
    }
    # Harden Memurai service
    $memSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
    if ($memSvc) {
        try {
            Set-Service -Name "Memurai" -StartupType Automatic -ErrorAction Stop
            & sc.exe failure "Memurai" reset= 86400 actions= restart/5000/restart/10000/restart/60000 | Out-Null
            & sc.exe failureflag "Memurai" 1 | Out-Null
            Write-Host "  Memurai resilience: StartupType=Automatic, recovery=auto-restart" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not set Memurai resilience: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} else {
    # ── DEFAULT PATH: Garnet (INC-001(d) Phase 2) ────────────────────────────
    Write-Host "  Installing Garnet (MIT, native Windows)..." -ForegroundColor Cyan

    # Validate RedisPassword is provided (Garnet requires auth) — unless GarnetNoAuth (local bare)
    if (-not $RedisPassword -and -not $GarnetNoAuth) {
        Write-Error "RedisPassword is REQUIRED for Garnet. Pass -RedisPassword <password> or -GarnetNoAuth for local dev."
    }

    # Check if Garnet service already exists
    $garnetSvc = Get-Service -Name $GarnetSvcName -ErrorAction SilentlyContinue
    if ($garnetSvc) {
        Write-Host "  Garnet service already exists — $($garnetSvc.Status)" -ForegroundColor Green
    } else {
        # Copy Garnet binaries
        $garnetSrc = Join-Path $ScriptDir "Extras\Garnet"
        if (-not (Test-Path $garnetSrc)) {
            Write-Error "Garnet binaries not found at $garnetSrc. Use a package built with -Mode Full or -Mode RTM."
        }
        if (-not (Test-Path $GarnetInstallDir)) {
            New-Item -ItemType Directory -Path $GarnetInstallDir -Force | Out-Null
        }
        Copy-Item -Path "$garnetSrc\*" -Destination $GarnetInstallDir -Recurse -Force
        Write-Host "  Copied Garnet binaries to $GarnetInstallDir" -ForegroundColor Gray

        # Create checkpoint directory
        $checkpointDir = Join-Path $GarnetInstallDir "data"
        if (-not (Test-Path $checkpointDir)) {
            New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
        }

        # Copy NSSM
        $nssmSrc = Join-Path $ScriptDir "Extras\nssm"
        $nssmExe = Join-Path $nssmSrc "nssm.exe"
        if (-not (Test-Path $nssmExe)) {
            Write-Error "NSSM not found at $nssmExe. Use a package built with Garnet support."
        }
        $nssmDest = Join-Path $GarnetInstallDir "nssm.exe"
        Copy-Item $nssmExe -Destination $nssmDest -Force
        Write-Host "  Copied NSSM to $nssmDest" -ForegroundColor Gray

        # Register Garnet as Windows Service via NSSM
        $garnetExe = Join-Path $GarnetInstallDir "GarnetServer.exe"
        # Build Garnet args: with auth (prod) or without (local dev via -GarnetNoAuth)
        if ($GarnetNoAuth) {
            $garnetArgs = "--bind 127.0.0.1 --port 6379 --checkpointdir `"$checkpointDir`" --recover --checkpoint-freq 300"
            Write-Host "  [GarnetNoAuth] Bare Garnet (no auth) — local dev only" -ForegroundColor Yellow
        } else {
            $garnetArgs = "--bind 127.0.0.1 --port 6379 --auth Password --password $RedisPassword --checkpointdir `"$checkpointDir`" --recover --checkpoint-freq 300"
        }

        Write-Host "  Registering $GarnetSvcName service via NSSM..." -ForegroundColor Gray
        & $nssmDest install $GarnetSvcName $garnetExe $garnetArgs | Out-Null
        & $nssmDest set $GarnetSvcName AppDirectory $GarnetInstallDir | Out-Null
        & $nssmDest set $GarnetSvcName Start SERVICE_AUTO_START | Out-Null
        & $nssmDest set $GarnetSvcName DisplayName "Garnet (Redis-compatible cache)" | Out-Null
        & $nssmDest set $GarnetSvcName Description "Microsoft Garnet - Redis-compatible cache for RTM View Shell (INC-001d)" | Out-Null

        # Start the service
        Start-Sleep 2
        Start-Service $GarnetSvcName -ErrorAction SilentlyContinue
        Start-Sleep 3
        $s = Get-Service $GarnetSvcName -ErrorAction SilentlyContinue
        Write-Host "  $GarnetSvcName : $($s.Status)" -ForegroundColor $(if ($s.Status -eq "Running") {"Green"} else {"Yellow"})
    }

    # Harden Garnet service: auto-start + auto-restart on failure (parity with da4cd7e Memurai hardening)
    $garnetSvc = Get-Service -Name $GarnetSvcName -ErrorAction SilentlyContinue
    if ($garnetSvc) {
        try {
            Set-Service -Name $GarnetSvcName -StartupType Automatic -ErrorAction Stop
            & sc.exe failure $GarnetSvcName reset= 86400 actions= restart/5000/restart/10000/restart/60000 | Out-Null
            & sc.exe failureflag $GarnetSvcName 1 | Out-Null
            Write-Host "  Garnet resilience: StartupType=Automatic, recovery=auto-restart" -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] Could not set Garnet resilience: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ── CacheOnly: exit early after [2/6] ─────────────────────────────────────────
if ($CacheOnly) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║         CACHE-ONLY INSTALLATION COMPLETE             ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "  -CacheOnly: skipped [3/6]-[6/6]. Garnet/Memurai installed." -ForegroundColor Yellow
    exit 0
}

# ── [3/6] Stop existing services ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/6 ] Stopping existing services..." -ForegroundColor Cyan
$svcsToStop = @()
if ($InstallShell) { $svcsToStop += $ShellSvcName }
if ($InstallRTM)   { $svcsToStop += $RTMSvcName }
foreach ($svcName in $svcsToStop) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service $svcName -Force -ErrorAction SilentlyContinue
        sc.exe delete $svcName | Out-Null
        Start-Sleep 2
        Write-Host "  Removed: $svcName" -ForegroundColor Gray
    }
}

# ── [4/6] Deploy files ────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 4/6 ] Deploying files..." -ForegroundColor Cyan
if ($InstallShell) {
    Copy-Item -Path (Join-Path $ScriptDir "Shell\*") -Destination $ShellDest -Recurse -Force
    Write-Host "  Shell -> $ShellDest" -ForegroundColor Green
}
if ($InstallRTM) {
    Copy-Item -Path (Join-Path $ScriptDir "RTM\*") -Destination $RTMDest -Recurse -Force
    Write-Host "  RTM   -> $RTMDest" -ForegroundColor Green
    if (-not (Test-Path (Join-Path $RTMDest "data.sys"))) {
        Write-Host "  [!] data.sys not found in $RTMDest — copy before starting service!" -ForegroundColor Yellow
    }
}

# ── [5/6] Database ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5/6 ] Database setup..." -ForegroundColor Cyan
if ($SkipDB) {
    Write-Host "  Skipped (SkipDB)." -ForegroundColor Gray
} else {
    $psql   = Find-PGTool "psql"
    $pgdump = Find-PGTool "pg_dump"

    if (-not $psql) {
        Write-Host "  [WARN] psql not found — skipping DB setup. Add PostgreSQL bin to PATH." -ForegroundColor Yellow
    } else {
        if ($DBPassword) { $env:PGPASSWORD = $DBPassword }

        # 5 — Restore via Restore-SqlDump.ps1
        $restoreScript = Join-Path $ScriptDir "Restore-SqlDump.ps1"
        $dbDumpFile = Get-ChildItem -Path (Join-Path $ScriptDir "DB") -ErrorAction SilentlyContinue |
                      Sort-Object Name -Descending | Select-Object -First 1
        if (-not (Test-Path $restoreScript)) {
            Write-Host "  [WARN] Restore-SqlDump.ps1 not found — skipping DB restore." -ForegroundColor Yellow
        } elseif (-not $dbDumpFile) {
            Write-Host "  [WARN] No dump file found in DB\ — skipping DB restore." -ForegroundColor Yellow
        } else {
            Write-Host "  Calling Restore-SqlDump.ps1 with $($dbDumpFile.Name)..." -ForegroundColor Gray
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & powershell -ExecutionPolicy Bypass -File $restoreScript `
                -DumpFile $dbDumpFile.FullName `
                -DBPassword $DBPassword `
                -DBAppUser $DBAppUser `
                -DBAppPassword $DBAppPassword
            $ErrorActionPreference = $prevPref
        }

        $env:PGPASSWORD = ""
    }
}

# ── [6/6] Register and start services ────────────────────────────────────────
Write-Host ""
Write-Host "[ 6/6 ] Registering Windows Services..." -ForegroundColor Cyan

if ($InstallShell) {
    $exe = Join-Path $ShellDest "CcDashboard.Web.exe"
    if (Test-Path $exe) {
        sc.exe create $ShellSvcName binPath= "`"$exe`" --urls=http://localhost:$ShellPort" start= auto | Out-Null
        sc.exe description $ShellSvcName "RTM View Shell (Blazor Server)" | Out-Null
        sc.exe failure $ShellSvcName reset= 86400 actions= restart/30000/restart/60000/restart/120000 | Out-Null
        Start-Service $ShellSvcName -ErrorAction SilentlyContinue
        Write-Host "  $ShellSvcName : $((Get-Service $ShellSvcName).Status)" -ForegroundColor Green
    }
}

if ($InstallRTM) {
    $exe = Join-Path $RTMDest "RTM.exe"
    if (Test-Path $exe) {
        sc.exe create $RTMSvcName binPath= "`"$exe`"" start= auto | Out-Null
        sc.exe description $RTMSvcName "RTM Real-Time Monitoring Service" | Out-Null
        sc.exe failure $RTMSvcName reset= 86400 actions= restart/30000/restart/60000/restart/120000 | Out-Null

        if (Test-Path (Join-Path $RTMDest "data.sys")) {
            Start-Service $RTMSvcName -ErrorAction SilentlyContinue
            Start-Sleep 6
            Write-Host "  $RTMSvcName : $((Get-Service $RTMSvcName).Status)" -ForegroundColor Green
        } else {
            Write-Host "  $RTMSvcName registered but NOT started — copy data.sys first." -ForegroundColor Yellow
            Write-Host "  Then run: Start-Service $RTMSvcName" -ForegroundColor Yellow
        }
    }
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              INSTALLATION COMPLETE                   ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
if ($InstallShell) { Write-Host "  Shell : http://localhost:$ShellPort" }
if ($InstallRTM)   { Write-Host "  RTM   : http://localhost:$RTMPort"   }
Write-Host "  Logs  : $LogPath"
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
