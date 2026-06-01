#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Свежая установка RTM View Shell + RTM Service на сервер.
.DESCRIPTION
    Запускать из распакованного zip-пакета (C:\Temp\<zip>\).
    Устанавливает Memurai, разворачивает Shell и RTM Service,
    регистрирует Windows Services, создаёт БД и восстанавливает backup.
    Минимум ручных операций — нужен только data.sys.

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
.PARAMETER SkipMemurai
    Не устанавливать Memurai (Redis уже есть).
.PARAMETER RedisPassword
    Пароль Memurai/Redis.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 -Mode RTM -SkipDB
    powershell -ExecutionPolicy Bypass -File Install-RTMView.ps1 -DBPassword "PgSup3r!" -RedisPassword "R3dis!"
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
    [switch]$SkipMemurai,
    [string]$RedisPassword = "",

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

# ── [2/6] Install Memurai ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 2/6 ] Memurai (Redis for Windows)..." -ForegroundColor Cyan
if ($SkipMemurai -or -not $InstallRTM) {
    Write-Host "  Skipped." -ForegroundColor Gray
} else {
    $redisSvc = Get-Service -Name "Memurai" -ErrorAction SilentlyContinue
    if ($redisSvc) {
        Write-Host "  Already installed — $($redisSvc.Status)" -ForegroundColor Green
    } else {
        $msi = Get-ChildItem -Path (Join-Path $ScriptDir "Extras") -Filter "memurai*.msi" -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if (-not $msi) {
            Write-Host "  [WARN] memurai*.msi not found in Extras\ — install Redis manually." -ForegroundColor Yellow
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
}

# ── [3/6] Stop existing services ─────────────────────────────────────────────
Write-Host ""
Write-Host "[ 3/6 ] Stopping existing services..." -ForegroundColor Cyan
foreach ($svcName in @($ShellSvcName, $RTMSvcName)) {
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

        # 5a — Create database if not exists
        Write-Host "  Checking database '$DBName'..." -ForegroundColor Gray
        $existsRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
            "SELECT 1 FROM pg_database WHERE datname='$DBName';" 2>&1
        $exists = if ($existsRaw -ne $null) { "$existsRaw".Trim() } else { "" }
        if ($exists -eq "1") {
            Write-Host "  DB '$DBName' already exists." -ForegroundColor Gray
        } else {
            Write-Host "  Creating database '$DBName'..." -ForegroundColor Gray
            & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c "CREATE DATABASE $DBName ENCODING 'UTF8';" | Out-Null
            Write-Host "  Created: $DBName" -ForegroundColor Green
        }

        # 5b — Create application user if specified and not exists
        if ($DBAppUser -and $DBAppPassword) {
            Write-Host "  Checking user '$DBAppUser'..." -ForegroundColor Gray
            $userExistsRaw = & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -tAc `
                "SELECT 1 FROM pg_roles WHERE rolname='$DBAppUser';" 2>&1
            $userExists = if ($userExistsRaw -ne $null) { "$userExistsRaw".Trim() } else { "" }
            if ($userExists -eq "1") {
                Write-Host "  User '$DBAppUser' already exists." -ForegroundColor Gray
                # Update password
                & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c `
                    "ALTER USER `"$DBAppUser`" WITH PASSWORD '$DBAppPassword';" | Out-Null
            } else {
                & $psql -h $DBHost -p $DBPort -U $DBUser -d postgres -c `
                    "CREATE USER `"$DBAppUser`" WITH PASSWORD '$DBAppPassword';" | Out-Null
                Write-Host "  Created user: $DBAppUser" -ForegroundColor Green
            }
            # Grant privileges
            & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c `
                "GRANT ALL PRIVILEGES ON DATABASE `"$DBName`" TO `"$DBAppUser`";" | Out-Null
            & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -c `
                "GRANT ALL ON SCHEMA public TO `"$DBAppUser`";" | Out-Null
            Write-Host "  Grants applied." -ForegroundColor Gray
        }

        # 5c — Restore from SQL backup
        $sqlFile = Get-ChildItem -Path (Join-Path $ScriptDir "DB") -Filter "*.sql" -ErrorAction SilentlyContinue |
                   Sort-Object Name -Descending | Select-Object -First 1
        if ($sqlFile) {
            Write-Host "  Restoring $($sqlFile.Name)..." -ForegroundColor Gray
            & $psql -h $DBHost -p $DBPort -U $DBUser -d $DBName -f $sqlFile.FullName
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  DB restored successfully." -ForegroundColor Green
            } else {
                Write-Host "  [WARN] psql exited $LASTEXITCODE — check DB manually." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  No SQL backup found in DB\ — skipping restore." -ForegroundColor Gray
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
