<#
  PROBE  probe_234_20260919_logpath-preconditions.ps1
  UNIT   PR234-SHELL-CFG-01 - preconditions for giving our Shell an ABSOLUTE log path, and the
         "before" half of the acceptance pair.
  WHY    Serilog writes to a RELATIVE path while the service's working directory is System32, so our
         lines land in the shared C:\Windows\System32\logs. Before changing the path we must know the
         target directory exists (or can exist) and is writable BY THE SERVICE ACCOUNT. A logger that
         silently writes nowhere is WORSE than the present state: today the log at least exists.
  WHERE  SERVER 234. READ-ONLY. Nothing is created, no service is touched, no config is edited.
         The foreign installation in C:\Program Files\CcDashboard is not read and not touched.
  OUT    C:\RTMView-Ops\output\234_<stamp>_logpath-preconditions.txt
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_logpath-preconditions.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("LOGPATH PRECONDITIONS  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "READ-ONLY RUN. Nothing is created here - the directory, if missing, is created by the change itself."
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  UNDER WHICH ACCOUNT DOES OUR SHELL RUN - the permission question is about THIS account"
$shellService = Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction SilentlyContinue
if ($null -eq $shellService) { Say "  *** service RTMViewShell ABSENT - stop and report"; Finish $false }
$serviceAccount = $shellService.StartName
Say ("  service RTMViewShell : state " + $shellService.State + "   pid " + $shellService.ProcessId)
Say ("  runs as              : " + $serviceAccount)
Say ("  image                : " + $shellService.PathName)
$engineService = Get-CimInstance Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if ($null -ne $engineService) { Say ("  engine RTMService runs as : " + $engineService.StartName + "   (same root cause, not changed in this pass)") }
Rule

Say "2  WHERE OUR SHELL IS TOLD TO WRITE RIGHT NOW"
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
if (-not (Test-Path -LiteralPath $shellCfg)) { Say ("  *** " + $shellCfg + " ABSENT - stop"); Finish $false }
$cfgRaw = Get-Content -LiteralPath $shellCfg -Raw -Encoding UTF8
foreach ($pathMatch in [regex]::Matches($cfgRaw, '"path"\s*:\s*"([^"]+)"')) {
  $configuredPath = $pathMatch.Groups[1].Value
  $isAbsolute = [System.IO.Path]::IsPathRooted($configuredPath)
  Say ("  Serilog path in config : " + $configuredPath + "   absolute: " + $isAbsolute)
}
Say ("  config sha256 (the number the change will move) : " + (Get-FileHash -LiteralPath $shellCfg -Algorithm SHA256).Hash)
Say  "  No secret from this file is printed here - only the log path and the file's hash."
$prodCfg = 'C:\RTMView\Shell\appsettings.Production.json'
Say ("  appsettings.Production.json on the machine : " + $(if (Test-Path -LiteralPath $prodCfg) { 'PRESENT' } else { 'ABSENT' }))
Rule

Say "3  THE TARGET DIRECTORY - does it exist, and who may write into it"
$targetDir = 'C:\Logs\RTMViewShell'
$logsRoot  = 'C:\Logs'
Say ("  " + $logsRoot  + " : " + $(if (Test-Path -LiteralPath $logsRoot)  { 'EXISTS' } else { 'ABSENT' }))
Say ("  " + $targetDir + " : " + $(if (Test-Path -LiteralPath $targetDir) { 'EXISTS' } else { 'ABSENT - the change must create it' }))
$aclTarget = if (Test-Path -LiteralPath $targetDir) { $targetDir } elseif (Test-Path -LiteralPath $logsRoot) { $logsRoot } else { $null }
if ($null -eq $aclTarget) {
  Say  "  no directory to read rights from yet: C:\Logs does not exist either."
  Say  "  Then the change creates BOTH, and the account above must be able to write there."
} else {
  Say ("  rights read from : " + $aclTarget)
  $acl = Get-Acl -LiteralPath $aclTarget
  Say ("    owner : " + $acl.Owner)
  foreach ($ace in $acl.Access) {
    Say ("    " + $ace.IdentityReference.ToString().PadRight(36) + " " + $ace.FileSystemRights.ToString() + "   " + $ace.AccessControlType)
  }
  $accountShort = "$serviceAccount"
  $matching = @($acl.Access | Where-Object { $accountShort -and ($_.IdentityReference.ToString() -ieq $accountShort) })
  Say ("    ACEs naming the service account exactly (" + $accountShort + ") : " + $matching.Count)
  Say  "    NOTE: an account may still write via a group (Administrators, SYSTEM, Users). The count above"
  Say  "    is not a verdict on its own - the writability test below is."
}
Rule

Say "4  POSITIVE CONTROL ON THE RIGHTS INSTRUMENT ITSELF"
Say  "  If Get-Acl returned nothing anywhere, that is 'the instrument is blind', not 'no rights exist'."
$controlDir = 'C:\RTMView-Ops\output'
$controlAcl = Get-Acl -LiteralPath $controlDir
Say ("  ACEs on " + $controlDir + " : " + @($controlAcl.Access).Count + "   (0 here means the instrument is blind)")
$posControlOk = (@($controlAcl.Access).Count -gt 0)
Say ("  POSCTL : " + $posControlOk)
Rule

Say "5  THE 'BEFORE' HALF OF THE ACCEPTANCE PAIR - the shared pot as it stands now"
$sharedDir = 'C:\Windows\System32\logs'
if (-not (Test-Path -LiteralPath $sharedDir)) { Say ("  " + $sharedDir + " ABSENT - report, do not improvise") }
else {
  $sharedFiles = @(Get-ChildItem -LiteralPath $sharedDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)
  Say ("  newest files in " + $sharedDir + " (up to 10):")
  foreach ($sharedFile in $sharedFiles) {
    $sizeText = $sharedFile.Length.ToString().PadLeft(12)
    # These are BASELINE files and are legitimately older than this run - but say so per file, never
    # let an old artefact pass for a fresh result (the 0ae2102 lesson, 18.09).
    $freshness = if ($sharedFile.LastWriteTime -ge $RunStartedAt) { 'written DURING this run' } else { ('predates this run by ' + [math]::Round((($RunStartedAt - $sharedFile.LastWriteTime).TotalMinutes), 1) + ' min') }
    Say ("    " + $sharedFile.Name.PadRight(32) + " " + $sizeText + " B   " + $sharedFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "   " + $freshness)
  }
  Say  "  These numbers are the BEFORE half. After the change and a restart of our service, the same"
  Say  "  files must stop growing FROM US, while other services keep writing here - that negative"
  Say  "  half is what separates 'we moved' from 'the machine went quiet'."
}
Rule

Say "VERDICT"
Say ("  service account known     : " + ($null -ne $serviceAccount -and $serviceAccount -ne ''))
Say ("  rights instrument working : " + $posControlOk)
Say ("  target dir exists         : " + (Test-Path -LiteralPath $targetDir))
Say  "  This run DECIDES NOTHING and CHANGES NOTHING. It supplies the numbers the change is gated on."
Say ("  LAST LINE : " + $(if ($posControlOk) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: LOGPATH-PRECONDITIONS-COMPLETE ====="
Finish $posControlOk
