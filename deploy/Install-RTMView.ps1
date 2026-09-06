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
    [string]$RTMSvcName    = "RTMService",

    # Kestrel HTTPS config (per-server, injected into deployed appsettings.json)
    [string]$Fqdn          = "",
    [string]$CertSubject   = "",
    [int]   $ShellHttpsPort = 5239,

    # Shell: Superadmin password (injected into Seed:SuperadminPassword)
    [string]$SuperadminPassword = "",

    # RTM appsettings params (for side-by-side installs)
    [string]$RTMPipeName       = "",         # RTM:PipeName (e.g. rtmpipe_v3)
    [string]$RTMTenantId       = "",         # RTM:TenantId (UUID)
    [string]$AdaptorServiceName = "",        # RTM:AdaptorServiceName (e.g. RTMView.Nayax)

    # Control switches
    [switch]$NoStartServices,   # Register services but do NOT start them (DB not ready)
    [switch]$FreshDb            # Use Provision-FreshDb.ps1 instead of dump restore
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path

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
            $garnetArgs = "--bind 127.0.0.1 --port 6379 --checkpointdir `"$checkpointDir`" --recover true"
            Write-Host "  [GarnetNoAuth] Bare Garnet (no auth) — local dev only" -ForegroundColor Yellow
        } else {
            $garnetArgs = "--bind 127.0.0.1 --port 6379 --auth Password --password $RedisPassword --checkpointdir `"$checkpointDir`" --recover true"
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
    # Preserve machine configuration before the package overwrites it.
    # Idiom taken verbatim from Update-RTMView.ps1 (RTM branch), not invented here.
    # Byte-exact on purpose: a text round-trip via Set-Content -Encoding UTF8 adds a BOM on PS 5.1.
    $preserveShell = @("appsettings.json","appsettings.Production.json","nlog.config")
    $preservedShell = @{}
    foreach ($pf in $preserveShell) {
        $existing = Join-Path $ShellDest $pf
        if (Test-Path $existing) { $preservedShell[$pf] = [System.IO.File]::ReadAllBytes($existing) }
    }
    Copy-Item -Path (Join-Path $ScriptDir "Shell\*") -Destination $ShellDest -Recurse -Force
    foreach ($kv in $preservedShell.GetEnumerator()) {
        [System.IO.File]::WriteAllBytes((Join-Path $ShellDest $kv.Key), $kv.Value)
        Write-Host "  Preserved: $($kv.Key) (package version ignored)" -ForegroundColor Gray
    }
    Write-Host "  Shell -> $ShellDest" -ForegroundColor Green

    # ── [4b/6] Inject per-server config into deployed appsettings.json ────────
    $shellAppSettings = Join-Path $ShellDest "appsettings.json"
    if (Test-Path $shellAppSettings) {
        $cfg = Get-Content $shellAppSettings -Raw | ConvertFrom-Json

        # FIX 4: Inject ConnectionStrings:Default with -DBAppPassword
        if ($DBAppPassword) {
            $connStr = "Host=$DBHost;Port=$DBPort;Database=$DBName;Username=$DBAppUser;Password=$DBAppPassword;SSL Mode=Prefer"
            $cfg.ConnectionStrings.Default = $connStr
            Write-Host "  Injected ConnectionStrings:Default" -ForegroundColor Gray
        } else {
            Write-Host "  [WARN] -DBAppPassword not provided — ConnectionStrings:Default left as placeholder" -ForegroundColor Yellow
        }

        # FIX: Inject ConnectionStrings:Redis (Garnet requires auth)
        if ($RedisPassword) {
            $redisConnStr = "localhost:6379,password=$RedisPassword"
            if (-not $cfg.ConnectionStrings) {
                $cfg | Add-Member -NotePropertyName "ConnectionStrings" -NotePropertyValue @{}
            }
            $cfg.ConnectionStrings | Add-Member -NotePropertyName "Redis" -NotePropertyValue $redisConnStr -Force
            Write-Host "  Injected ConnectionStrings:Redis" -ForegroundColor Gray
        } elseif (-not $GarnetNoAuth) {
            Write-Host "  [WARN] -RedisPassword not provided — ConnectionStrings:Redis may fail if Garnet uses --auth" -ForegroundColor Yellow
        }

        # FIX: Inject Seed:SuperadminPassword (required for fresh DB)
        if ($SuperadminPassword) {
            if (-not $cfg.Seed) {
                $cfg | Add-Member -NotePropertyName "Seed" -NotePropertyValue @{}
            }
            $cfg.Seed | Add-Member -NotePropertyName "SuperadminPassword" -NotePropertyValue $SuperadminPassword -Force
            Write-Host "  Injected Seed:SuperadminPassword" -ForegroundColor Gray
        }

        # FIX 5: Inject Kestrel HTTPS config (per-server FQDN/port/cert)
        # Prompt if not provided (install is interactive)
        if (-not $Fqdn) {
            $Fqdn = Read-Host "Enter FQDN for Shell (e.g. rtmview.example.com, or 'localhost' for local dev)"
            if (-not $Fqdn) { $Fqdn = "localhost" }
        }
        if (-not $CertSubject -and $Fqdn -ne "localhost") {
            $CertSubject = Read-Host "Enter certificate Subject for HTTPS (e.g. 'CN=rtmview.example.com', or empty to skip HTTPS)"
        }

        # Ensure Kestrel section exists
        if (-not $cfg.Kestrel) {
            $cfg | Add-Member -NotePropertyName "Kestrel" -NotePropertyValue @{ Endpoints = @{} }
        }
        if (-not $cfg.Kestrel.Endpoints) {
            $cfg.Kestrel | Add-Member -NotePropertyName "Endpoints" -NotePropertyValue @{}
        }

        # HTTP endpoint
        $cfg.Kestrel.Endpoints | Add-Member -NotePropertyName "Http" -NotePropertyValue @{
            Url = "http://${Fqdn}:$ShellPort"
        } -Force

        # HTTPS endpoint (if CertSubject provided)
        if ($CertSubject) {
            $cfg.Kestrel.Endpoints | Add-Member -NotePropertyName "Https" -NotePropertyValue @{
                Url = "https://${Fqdn}:$ShellHttpsPort"
                Certificate = @{
                    Subject = $CertSubject
                    Store = "My"
                    Location = "LocalMachine"
                    AllowInvalid = "true"
                }
            } -Force
            Write-Host "  Injected Kestrel HTTPS (Fqdn=$Fqdn, Port=$ShellHttpsPort, Cert=$CertSubject)" -ForegroundColor Gray
        } else {
            Write-Host "  Kestrel HTTP only (Fqdn=$Fqdn, Port=$ShellPort)" -ForegroundColor Gray
        }

        # Write back with UTF-8 BOM (§35)
        $cfgJson = $cfg | ConvertTo-Json -Depth 10
        $BOM = [byte[]](0xEF, 0xBB, 0xBF)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($cfgJson)
        [System.IO.File]::WriteAllBytes($shellAppSettings, $BOM + $bytes)
        Write-Host "  Updated: $shellAppSettings" -ForegroundColor Green
    }
}
if ($InstallRTM) {
    $preserveRTM = @("data.sys","appsettings.json")
    $preservedRTM = @{}
    foreach ($pf in $preserveRTM) {
        $existing = Join-Path $RTMDest $pf
        if (Test-Path $existing) { $preservedRTM[$pf] = [System.IO.File]::ReadAllBytes($existing) }
    }
    Copy-Item -Path (Join-Path $ScriptDir "RTM\*") -Destination $RTMDest -Recurse -Force
    foreach ($kv in $preservedRTM.GetEnumerator()) {
        [System.IO.File]::WriteAllBytes((Join-Path $RTMDest $kv.Key), $kv.Value)
        Write-Host "  Preserved: $($kv.Key) (package version ignored)" -ForegroundColor Gray
    }
    Write-Host "  RTM   -> $RTMDest" -ForegroundColor Green
    if (-not (Test-Path (Join-Path $RTMDest "data.sys"))) {
        Write-Host "  [!] data.sys not found in $RTMDest — copy before starting service!" -ForegroundColor Yellow
    }

    # ── [4c/6] Inject RTM appsettings (side-by-side params) ───────────────────
    $rtmAppSettings = Join-Path $RTMDest "appsettings.json"
    if (Test-Path $rtmAppSettings) {
        $rtmCfg = Get-Content $rtmAppSettings -Raw -Encoding UTF8 | ConvertFrom-Json

        # Inject RTM:PipeName
        if ($RTMPipeName) {
            if (-not $rtmCfg.RTM) { $rtmCfg | Add-Member -NotePropertyName "RTM" -NotePropertyValue @{} }
            $rtmCfg.RTM | Add-Member -NotePropertyName "PipeName" -NotePropertyValue $RTMPipeName -Force
            Write-Host "  Injected RTM:PipeName = $RTMPipeName" -ForegroundColor Gray
        }

        # Inject RTM:TenantId
        if ($RTMTenantId) {
            if (-not $rtmCfg.RTM) { $rtmCfg | Add-Member -NotePropertyName "RTM" -NotePropertyValue @{} }
            $rtmCfg.RTM | Add-Member -NotePropertyName "TenantId" -NotePropertyValue $RTMTenantId -Force
            Write-Host "  Injected RTM:TenantId = $RTMTenantId" -ForegroundColor Gray
        }

        # Inject RTM:AdaptorServiceName
        if ($AdaptorServiceName) {
            if (-not $rtmCfg.RTM) { $rtmCfg | Add-Member -NotePropertyName "RTM" -NotePropertyValue @{} }
            $rtmCfg.RTM | Add-Member -NotePropertyName "AdaptorServiceName" -NotePropertyValue $AdaptorServiceName -Force
            Write-Host "  Injected RTM:AdaptorServiceName = $AdaptorServiceName" -ForegroundColor Gray
        }

        # Inject Kestrel port (for side-by-side: e.g. 8089 instead of 8088)
        if ($RTMPort -ne 8088) {
            if (-not $rtmCfg.Kestrel) { $rtmCfg | Add-Member -NotePropertyName "Kestrel" -NotePropertyValue @{ Endpoints = @{} } }
            if (-not $rtmCfg.Kestrel.Endpoints) { $rtmCfg.Kestrel | Add-Member -NotePropertyName "Endpoints" -NotePropertyValue @{} }
            $rtmCfg.Kestrel.Endpoints | Add-Member -NotePropertyName "Http" -NotePropertyValue @{
                Url = "http://127.0.0.1:$RTMPort"
            } -Force
            Write-Host "  Injected RTM Kestrel port = $RTMPort" -ForegroundColor Gray
        }

        # The Shell connection string is built from parameters; RTM's never was, so a
        # side-by-side install on a non-default port left RTM pointing at 5432.
        # Key name comes from the code that reads it: AppConfig.cs:51 -> "ConnectionStrings:RTMConnectionString".
        if ($DBAppPassword) {
            $rtmConn = "Host=$DBHost;Port=$DBPort;Database=$DBName;Username=$DBAppUser;Password=$DBAppPassword;Pooling=true;Maximum Pool Size=5000;"
            if (-not $rtmCfg.ConnectionStrings) { $rtmCfg | Add-Member -NotePropertyName "ConnectionStrings" -NotePropertyValue @{} }
            $rtmCfg.ConnectionStrings | Add-Member -NotePropertyName "RTMConnectionString" -NotePropertyValue $rtmConn -Force
            Write-Host "  Injected ConnectionStrings:RTMConnectionString (Port=$DBPort)" -ForegroundColor Gray
        } else {
            Write-Host "  [WARN] -DBAppPassword not provided - RTM connection string left as-is" -ForegroundColor Yellow
        }

        # Write back with UTF-8 (preserve Hebrew AgentWGPerfixList etc.)
        $rtmCfgJson = $rtmCfg | ConvertTo-Json -Depth 10
        $BOM = [byte[]](0xEF, 0xBB, 0xBF)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($rtmCfgJson)
        [System.IO.File]::WriteAllBytes($rtmAppSettings, $BOM + $bytes)
        Write-Host "  Updated: $rtmAppSettings" -ForegroundColor Green
    }
}

# ── [5/6] Database ────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[ 5/6 ] Database setup..." -ForegroundColor Cyan
if ($SkipDB) {
    Write-Host "  Skipped (SkipDB)." -ForegroundColor Gray
} elseif ($FreshDb) {
    # FreshDb mode: use Provision-FreshDb.ps1 (canonical Design-B)
    $provisionScript = Join-Path $ScriptDir "db\tools\Provision-FreshDb.ps1"
    if (-not (Test-Path $provisionScript)) {
        Write-Host "  [ERROR] Provision-FreshDb.ps1 not found at $provisionScript" -ForegroundColor Red
        Write-Host "  The package must include db\tools\Provision-FreshDb.ps1 for -FreshDb mode." -ForegroundColor Yellow
    } else {
        $shellExe = Join-Path $ShellDest "CcDashboard.Web.exe"
        Write-Host "  Calling Provision-FreshDb.ps1 (Design B fresh install)..." -ForegroundColor Gray
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & powershell -ExecutionPolicy Bypass -File $provisionScript `
            -DBHost $DBHost `
            -DBPort $DBPort `
            -Database $DBName `
            -SuperUser $DBUser `
            -SuperPassword $DBPassword `
            -AppUser $DBAppUser `
            -AppPassword $DBAppPassword `
            -ShellExe $shellExe
        $ErrorActionPreference = $prevPref
    }
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
        sc.exe create $ShellSvcName binPath= "`"$exe`"" start= auto | Out-Null
        sc.exe description $ShellSvcName "RTM View Shell (Blazor Server)" | Out-Null
        sc.exe failure $ShellSvcName reset= 86400 actions= restart/30000/restart/60000/restart/120000 | Out-Null
        if ($NoStartServices) {
            Write-Host "  $ShellSvcName : registered (NOT started due to -NoStartServices)" -ForegroundColor Yellow
        } else {
            Start-Service $ShellSvcName -ErrorAction SilentlyContinue
            Write-Host "  $ShellSvcName : $((Get-Service $ShellSvcName).Status)" -ForegroundColor Green
        }
    }
}

if ($InstallRTM) {
    $exe = Join-Path $RTMDest "RTM.exe"
    if (Test-Path $exe) {
        sc.exe create $RTMSvcName binPath= "`"$exe`"" start= auto | Out-Null
        sc.exe description $RTMSvcName "RTM Real-Time Monitoring Service" | Out-Null
        sc.exe failure $RTMSvcName reset= 86400 actions= restart/30000/restart/60000/restart/120000 | Out-Null

        if ($NoStartServices) {
            Write-Host "  $RTMSvcName : registered (NOT started due to -NoStartServices)" -ForegroundColor Yellow
        } elseif (Test-Path (Join-Path $RTMDest "data.sys")) {
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
