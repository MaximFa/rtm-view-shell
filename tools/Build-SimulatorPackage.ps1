# Build-SimulatorPackage.ps1
# Builds RTM View Shell + SignalR Simulator and packages everything as a ZIP.
#
# PREREQUISITES (run once before packaging):
#   1. Start the app in dev mode to apply all EF migrations and seed the DB.
#   2. Run: powershell -ExecutionPolicy Bypass -File tools\Export-SimulatorDB.ps1
#      This creates tools\simulator_db.dump bundled in the ZIP.
#
# Usage (from solution root):
#   powershell -ExecutionPolicy Bypass -File tools\Build-SimulatorPackage.ps1
#   powershell -ExecutionPolicy Bypass -File tools\Build-SimulatorPackage.ps1 -ExportDB -DBPassword "pwd"

[CmdletBinding()]
param(
    [string]$OutputDir  = ".\publish\simulator",
    [string]$ZipName    = "RTMViewShell-Simulator.zip",

    # If set, exports the dev DB automatically before building.
    [switch]$ExportDB,
    [string]$DBPassword = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SolutionRoot   = Split-Path -Parent $PSScriptRoot
$WebProject     = Join-Path $SolutionRoot "src\CcDashboard.Web\CcDashboard.Web.csproj"
$SignalRProject  = Join-Path $SolutionRoot "tools\SignalRSimulator\SignalRSimulator.csproj"
$ToolsDir        = $PSScriptRoot
$PublishDir      = Join-Path $SolutionRoot $OutputDir
$SignalRDir      = Join-Path $PublishDir "SignalRSimulator"
$DumpFile        = Join-Path $ToolsDir "simulator_db.dump"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  RTM View Shell -- Simulator Package Builder"     -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# ---- 0. Verify solution root ------------------------------------------------
if (-not (Test-Path (Join-Path $SolutionRoot "CcDashboard.sln"))) {
    Write-Error "CcDashboard.sln not found. Run this script from the solution root."
}

# ---- 1. Optionally export dev DB -------------------------------------------
if ($ExportDB) {
    Write-Host "Exporting simulator database..." -ForegroundColor Green
    $exportScript = Join-Path $ToolsDir "Export-SimulatorDB.ps1"
    $exportArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DBPassword)) {
        $exportArgs += "-DBPassword", $DBPassword
    }
    & powershell -ExecutionPolicy Bypass -File $exportScript @exportArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "DB export failed." }
}

# ---- 2. Verify DB dump exists -----------------------------------------------
if (-not (Test-Path $DumpFile)) {
    Write-Error @"
DB dump not found: $DumpFile

Run the export first:
  powershell -ExecutionPolicy Bypass -File tools\Export-SimulatorDB.ps1

Or add -ExportDB flag:
  .\tools\Build-SimulatorPackage.ps1 -ExportDB -DBPassword "yourpassword"
"@
}
$dumpSizeMB = [math]::Round((Get-Item $DumpFile).Length / 1MB, 1)
Write-Host "DB dump: simulator_db.dump ($dumpSizeMB MB)" -ForegroundColor Gray

# ---- 3. Clean previous output -----------------------------------------------
if (Test-Path $PublishDir) {
    Write-Host "Cleaning: $PublishDir" -ForegroundColor Yellow
    Remove-Item $PublishDir -Recurse -Force
}

# ---- 4. Publish CcDashboard.Web (self-contained, win-x64) ------------------
Write-Host "Publishing CcDashboard.Web..." -ForegroundColor Green

dotnet publish $WebProject `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $PublishDir `
    /p:PublishSingleFile=false `
    /p:PublishTrimmed=false

if ($LASTEXITCODE -ne 0) { Write-Error "CcDashboard.Web publish failed." }
Write-Host "CcDashboard.Web published." -ForegroundColor Green

# ---- 5. Publish SignalRSimulator (self-contained, win-x64) -----------------
Write-Host "Publishing SignalRSimulator..." -ForegroundColor Green

dotnet publish $SignalRProject `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    --output $SignalRDir `
    /p:PublishSingleFile=false `
    /p:PublishTrimmed=false

if ($LASTEXITCODE -ne 0) { Write-Error "SignalRSimulator publish failed." }
Write-Host "SignalRSimulator published." -ForegroundColor Green

# ---- 6. Copy install scripts and DB dump ------------------------------------
Write-Host "Copying install scripts and DB dump..."

Copy-Item (Join-Path $ToolsDir "Install-CcDashboard.ps1")   $PublishDir -Force
Copy-Item (Join-Path $ToolsDir "Uninstall-CcDashboard.ps1") $PublishDir -Force
Copy-Item $DumpFile $PublishDir -Force

$SimGuide = Join-Path $SolutionRoot "INSTALL-SIMULATOR.md"
if (Test-Path $SimGuide) { Copy-Item $SimGuide $PublishDir -Force }

# ---- 7. Remove .pdb files ---------------------------------------------------
Get-ChildItem $PublishDir -Filter "*.pdb" -Recurse -ErrorAction SilentlyContinue |
    Remove-Item -Force

# ---- 8. Create ZIP ----------------------------------------------------------
$ZipFull = Join-Path $SolutionRoot "publish\$ZipName"
if (Test-Path $ZipFull) { Remove-Item $ZipFull -Force }

Write-Host "Creating archive: $ZipFull" -ForegroundColor Green
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($PublishDir, $ZipFull)

$ZipSizeMB = [math]::Round((Get-Item $ZipFull).Length / 1MB, 1)
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Package ready: publish\$ZipName ($ZipSizeMB MB)" -ForegroundColor Cyan
Write-Host "  Contents:"                                        -ForegroundColor Cyan
Write-Host "    CcDashboard.Web.exe  (main app, port 5000)"    -ForegroundColor Cyan
Write-Host "    SignalRSimulator\    (SignalR hubs, port 5001)" -ForegroundColor Cyan
Write-Host "    simulator_db.dump    (pre-baked DB snapshot)"   -ForegroundColor Cyan
Write-Host "    Install-CcDashboard.ps1"                        -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To install on target machine:"                     -ForegroundColor White
Write-Host "  powershell -ExecutionPolicy Bypass -File Install-CcDashboard.ps1" -ForegroundColor Yellow
Write-Host ""
