#Requires -Version 5.1
<#
  BOX 234 / clean install from package 08092026.1037.zip
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433.

  TWO MODES, AND THE DEFAULT ONE CHANGES NOTHING:
    without -Proceed : reads every per-server value from disk, prints them, and EXITS.
                       Nothing is stopped, deleted, installed or dropped.
    with -Proceed    : preserves the current configs, installs the package, and takes the
                       one-shot data.sys reading. It does NOT restore data.sys and does NOT
                       touch the adapter - those are separate steps by decision.

  WHY THE GUARD IS SHAPED LIKE THIS: a previous box on this machine ran its steps 2 and 3
  WITHOUT the flag, because the guard function did not terminate the script and control fell
  through into the next step. Here the guard calls Fin, which calls exit, and the install
  section ALSO re-checks the flag itself and refuses on its own. Two independent refusals.

  THE IRREVERSIBLE PART, NAMED: Provision-FreshDb terminates connections and runs
  dropdb --if-exists on rtmviewdb at port 5433. The database now on 5433 - the one carrying the
  wrong tenant Id 01a07e07 - IS DESTROYED. That is the intent of this pass, not a side effect.
  The old PG 15.5 database on port 5432 is NOT touched by anything here.
  The installer also stops and sc-deletes RTMViewShell and RTMService; RTMTwilio_1 is not in
  its list and is expected to survive - which we verify afterwards rather than assume.

  Passwords are typed on this machine with masked input and are never printed - only lengths.

  FOUND BEFORE RUNNING, NOT AFTER: Install-RTMView.ps1:230-233 validates -RedisPassword and calls
  Write-Error - under $ErrorActionPreference = Stop that THROWS - and it does so BEFORE the check
  of whether the Garnet service already exists. So on this machine, where Garnet is running, the
  install would have died at [2/6] without ever reaching the database. This box therefore reads
  the Redis password out of the machine's own Shell config and passes it; if it is not there, the
  box stops and says so rather than inventing -SkipRedis on its own.
#>

param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$ZIP      = "C:\Temp\08092026.1037.zip"
$ZIPSHA   = "D24E7C7ABE3B1C52B796854A4E42591453635F8B6C252A2150853A9CE58C8F38"
$EXTRACT  = "C:\Temp\install_1037"
$FQDN     = "insightense.com"
$CERTSUBJ = "insightense.com"
$OutDir   = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_install.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "VERDICT: PASS" } else { "VERDICT: FAIL" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name match {0} / uuid match {1}" -f $nameOk, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say ("  mode : {0}" -f $(if ($Proceed) { "PROCEED - this run WILL install" } else { "DRY - this run changes nothing" }))
Say "  G0 PASS"
Say ""

Say "===== G1  the instrument checks itself - INCLUDING WHICH VERSION OF ITSELF ====="
$self = $MyInvocation.MyCommand.Path
$selfText = [IO.File]::ReadAllText($self)
$hasRedisFix = $selfText.Contains('"-RedisPassword",$redisPw')
Say ("  this file : {0}" -f $self)
Say ("  sha256    : {0}" -f (Get-Sha256Of $self))
Say ("  carries the -RedisPassword fix : {0}   (must be True)" -f $hasRedisFix)
Say ("  NEGCTL same predicate for a marker that cannot be there : {0}   (must be False)" -f $selfText.Contains('"-ZzzNoSuchParam"'))
if (-not $hasRedisFix) {
    Say "  *** THIS IS THE OLD COPY OF THE BOX. The fix lives in the repo, not in the file that is"
    Say "      running. Copy the current .probes\probe_234_20260908_install.ps1 to this machine again."
    Fin $false
}
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such.bin"))
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say "  G1 PASS"
Say ""

Say "===== G2  the package is the gated one ====="
Say ("  file   : {0}   exists {1}" -f $ZIP, (Test-Path $ZIP))
if (-not (Test-Path $ZIP)) { Say "  *** package missing"; Fin $false }
$sha = Get-Sha256Of $ZIP
Say ("  sha256 expected {0}" -f $ZIPSHA)
Say ("  sha256 actual   {0}" -f $sha)
if ($sha -ne $ZIPSHA) { Say "  *** hash mismatch - refusing"; Fin $false }
Say "  G2 PASS"
Say ""

Say "===== 1  PER-SERVER VALUES, READ FROM THE MACHINE'S OWN CONFIG ====="
Say "  (the 3 July incident put literal REPLACE_FQDN into a live config because these were omitted)"
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$rtmCfg   = "C:\RTMView\RTM\appsettings.json"
$vals = @{}
if (-not (Test-Path $shellCfg)) { Say ("  {0} : ABSENT - cannot read per-server values" -f $shellCfg); Fin $false }
$rawShell = Get-Content $shellCfg -Raw
$jsonShell = $rawShell | ConvertFrom-Json
Say ("  Shell config top-level keys : {0}" -f (($jsonShell.PSObject.Properties.Name) -join ", "))
$cs = ""
if ($jsonShell.ConnectionStrings) {
    Say ("  ConnectionStrings keys : {0}" -f (($jsonShell.ConnectionStrings.PSObject.Properties.Name) -join ", "))
    foreach ($p in $jsonShell.ConnectionStrings.PSObject.Properties) {
        if ("$($p.Value)" -match "(?i)Host=|Database=") { $cs = "$($p.Value)"; Say ("  using connection string from key '{0}'" -f $p.Name) }
    }
}
if (-not $cs) { Say "  *** no Postgres connection string found in the Shell config"; Fin $false }
foreach ($pair in @(@("DBHost","Host"), @("DBName","Database"), @("DBAppUser","Username"), @("DBPort","Port"))) {
    $m = [regex]::Match($cs, ("(?i)" + $pair[1] + "\s*=\s*([^;]+)"))
    $vals[$pair[0]] = $(if ($m.Success) { $m.Groups[1].Value.Trim() } else { "" })
    Say ("  {0,-12} = '{1}'" -f $pair[0], $vals[$pair[0]])
}
$mp = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)")
$vals["DBAppPassword"] = $(if ($mp.Success) { $mp.Groups[1].Value.Trim() } else { "" })
Say ("  DBAppPassword = present {0}, {1} characters (never printed)" -f $mp.Success, $vals["DBAppPassword"].Length)
if (-not $mp.Success) { Say "  *** no application DB password in the config"; Fin $false }

$redisPw = ""
if ($jsonShell.ConnectionStrings -and $jsonShell.ConnectionStrings.Redis) {
    $rs = "$($jsonShell.ConnectionStrings.Redis)"
    $rm = [regex]::Match($rs, "(?i)password\s*=\s*([^,;\s]+)")
    if ($rm.Success) { $redisPw = $rm.Groups[1].Value }
    Say ("  Redis connection string present : True , password found : {0} , {1} characters (never printed)" -f $rm.Success, $redisPw.Length)
    Say ("  NEGCTL same predicate on a string without a password : {0}   (must be False)" -f ([regex]::Match("localhost:6379", "(?i)password\s*=\s*([^,;\s]+)").Success))
} else { Say "  Redis connection string : ABSENT from the Shell config" }
if (-not $redisPw) {
    Say "  *** no Redis password available. The installer validates -RedisPassword BEFORE it checks"
    Say "      whether Garnet already exists (Install-RTMView.ps1:230-233), so the install would die"
    Say "      at [2/6]. Not choosing -SkipRedis on my own - stopping for a decision."
    Fin $false
}

$httpsPort = 0
$urls = @([regex]::Matches($rawShell, "(?i)https://[^`"]*:(\d+)"))
foreach ($u in $urls) { if ($httpsPort -eq 0) { $httpsPort = [int]$u.Groups[1].Value } }
Say ("  https endpoints named in the config : {0}" -f $(if ($urls.Count -eq 0) { "none" } else { (($urls | ForEach-Object { $_.Value }) -join ", ") }))
Say ("  ShellHttpsPort to pass : {0}   (installer default is 5239 - passing it explicitly is the point)" -f $httpsPort)
if ($httpsPort -eq 0) { Say "  *** could not read the https port from the config - stop, do not guess"; Fin $false }

if (-not (Test-Path $rtmCfg)) { Say ("  {0} : ABSENT" -f $rtmCfg); Fin $false }
$jsonRtm = Get-Content $rtmCfg -Raw | ConvertFrom-Json
$vals["RTMPipeName"] = "$($jsonRtm.RTM.PipeName)"
$vals["RTMTenantId"] = "$($jsonRtm.RTM.TenantId)"
Say ("  RTMPipeName  = '{0}'" -f $vals["RTMPipeName"])
Say ("  RTMTenantId  = '{0}'   (expected 019e03e9-60dd-72da-bd01-648ffdb2b433)" -f $vals["RTMTenantId"])
Say ("  AdaptorServiceName to pass = 'RTMTwilio_1'   (explicit - the legacy RTM.Twilio must never be driven by us)")
Say ("  Fqdn / CertSubject to pass = '{0}' / '{1}'   (operator-confirmed values)" -f $FQDN, $CERTSUBJ)
Say ""

Say "===== 2  WHAT THIS INSTALL WILL DESTROY, stated before it is asked for ====="
$svcNow = @()
foreach ($s in @("RTMViewShell","RTMService","RTMTwilio_1","RTM.Twilio","RTM","Garnet")) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ("  {0,-14} ABSENT" -f $s) }
    else { Say ("  {0,-14} {1,-9} {2}" -f $svc.Name, $svc.State, $svc.PathName); $svcNow += $svc.Name }
}
Say "  The installer stops and DELETES RTMViewShell and RTMService, then recreates them."
Say "  RTMTwilio_1 is NOT in its list - expected to survive, verified afterwards, not assumed."
Say "  Provision-FreshDb runs dropdb --if-exists on rtmviewdb at 5433: THAT DATABASE IS DESTROYED."
Say "  The PG 15.5 database on port 5432 is not touched by anything in this box."
Say ""

if (-not $Proceed) {
    Say "===== DRY RUN ENDS HERE ====="
    Say "  Nothing was stopped, deleted, installed or dropped."
    Say "  Re-run the same file with  -Proceed  to install with exactly the values printed above."
    Fin $true
}

Say "===== 3  PROCEED CONFIRMED - the install section checks the flag on its own ====="
if (-not $Proceed) { Say "  *** the flag is not set - refusing (second, independent guard)"; Fin $false }
Say "  flag present. Continuing."
Say ""

Say "===== 4  preserve what exists, before the package can overwrite it ====="
$pres = Join-Path "C:\RTMView-Ops" ("preserve_install_{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $pres | Out-Null
foreach ($src in @($shellCfg, $rtmCfg, "C:\RTMView\RTM\data.sys")) {
    if (Test-Path $src) {
        $dst = Join-Path $pres (($src -replace "[:\\]","_"))
        Copy-Item $src -Destination $dst -Force
        Say ("  saved {0}`n        -> {1}`n        sha256 {2}" -f $src, $dst, (Get-Sha256Of $dst))
    } else { Say ("  {0} : ABSENT, nothing to save" -f $src) }
}
Say ""

Say "===== 5  passwords - typed here, masked, never printed ====="
$secSuper = Read-Host "PostgreSQL SUPERUSER (postgres) password" -AsSecureString
$secAdmin = Read-Host "Superadmin password for the Shell" -AsSecureString
$pwSuper = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secSuper))
$pwAdmin = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secAdmin))
Say ("  superuser password : {0} characters" -f $pwSuper.Length)
Say ("  superadmin password: {0} characters" -f $pwAdmin.Length)
if ($pwSuper.Length -eq 0 -or $pwAdmin.Length -eq 0) { Say "  *** an empty password was entered - stop"; Fin $false }
Say ""

Say "===== 6  unpack the package ====="
if (Test-Path $EXTRACT) { Say ("  {0} already exists - using a new folder to avoid mixing two packages" -f $EXTRACT); $EXTRACT = "$EXTRACT`_$stamp" }
New-Item -ItemType Directory -Force -Path $EXTRACT | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($ZIP, $EXTRACT)
Get-ChildItem $EXTRACT -Recurse -Filter "*.ps1" | Unblock-File
$inst = Join-Path $EXTRACT "Install-RTMView.ps1"
Say ("  extracted to : {0}" -f $EXTRACT)
Say ("  files        : {0}" -f @(Get-ChildItem $EXTRACT -Recurse -File).Count)
Say ("  installer    : {0}   exists {1}" -f $inst, (Test-Path $inst))
Say ("  seed file    : {0}" -f (Test-Path (Join-Path $EXTRACT "db\data\01_tenants.sql")))
Say ("  provision    : {0}" -f (Test-Path (Join-Path $EXTRACT "db\tools\Provision-FreshDb.ps1")))
if (-not (Test-Path $inst)) { Say "  *** installer not found after extraction"; Fin $false }
Say ""

Say "===== 7  INSTALL ====="
$installLog = Join-Path $OutDir "234_$($stamp)_install-console.txt"
$t0 = Get-Date
$argList = @(
    "-ExecutionPolicy","Bypass","-NoProfile","-File",$inst,
    "-FreshDb",
    "-DBHost",$vals["DBHost"], "-DBPort","5433", "-DBName",$vals["DBName"],
    "-DBUser","postgres", "-DBPassword",$pwSuper,
    "-DBAppUser",$vals["DBAppUser"], "-DBAppPassword",$vals["DBAppPassword"],
    "-Fqdn",$FQDN, "-CertSubject",$CERTSUBJ, "-ShellHttpsPort","$httpsPort",
    "-SuperadminPassword",$pwAdmin,
    "-RTMPipeName",$vals["RTMPipeName"], "-RTMTenantId",$vals["RTMTenantId"],
    "-AdaptorServiceName","RTMTwilio_1",
    "-RedisPassword",$redisPw
)
Say "  command (passwords shown as <hidden>):"
$shown = @()
$skipNext = $false
foreach ($a in $argList) {
    if ($skipNext) { $shown += "<hidden>"; $skipNext = $false; continue }
    if ($a -eq "-DBPassword" -or $a -eq "-DBAppPassword" -or $a -eq "-SuperadminPassword" -or $a -eq "-RedisPassword") { $skipNext = $true }
    $shown += $a
}
Say ("      powershell {0}" -f ($shown -join " "))
$out = & powershell.exe @argList 2>&1
$rc = $LASTEXITCODE
$elapsed = ((Get-Date) - $t0).TotalSeconds
[IO.File]::WriteAllLines($installLog, @($out | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
Say ("  exit code {0}   elapsed {1:N0} s   console lines {2}" -f $rc, $elapsed, @($out).Count)
Say ("  full console -> {0}" -f $installLog)
Say "  --- last 25 console lines ---"
foreach ($ol in (@($out) | Select-Object -Last 25)) { Say ("      {0}" -f $ol) }
Say ""

Say "===== 8  ONE-SHOT READING: data.sys as the installer left it, BEFORE we return ours ====="
Say "  This window exists once. After we copy our file the question cannot be asked again."
$live = "C:\RTMView\RTM\data.sys"
if (-not (Test-Path $live)) {
    Say ("  {0} : ABSENT   <- that is an ANSWER, not a probe failure: the installer created none" -f $live)
} else {
    $h = Get-Sha256Of $live
    Say ("  {0}" -f $live)
    Say ("  sha256 {0}" -f $h)
    Say ("  size {0} bytes, modified {1}" -f (Get-Item $live).Length, (Get-Item $live).LastWriteTime)
    Say ("  equals the machine file 24F0BFAC...DE43 : {0}" -f ($h -eq "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"))
    Say ("  equals the package file 7745C5CA...476D : {0}" -f ($h -eq "7745C5CA4DF0DD4AE24584343A16A38180CB3E930D1630CD88766C66C44F476D"))
}
Say ""

Say "===== 9  what stands right after the install (reading only) ====="
foreach ($s in @("RTMViewShell","RTMService","RTMTwilio_1","RTM.Twilio","RTM","Garnet")) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ("  {0,-14} ABSENT" -f $s) }
    else { Say ("  {0,-14} {1,-9} {2,-10} {3}" -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
Say ("  C:\RTMView\RTM.Twilio directory survived : {0}" -f (Test-Path "C:\RTMView\RTM.Twilio"))
if (Test-Path $rtmCfg) {
    $j2 = Get-Content $rtmCfg -Raw | ConvertFrom-Json
    Say ("  RTM:AdaptorServiceName on disk after install : '{0}'" -f $j2.RTM.AdaptorServiceName)
    Say ("  RTM:PipeName on disk after install           : '{0}'" -f $j2.RTM.PipeName)
    Say ("  RTM:TenantId on disk after install           : '{0}'" -f $j2.RTM.TenantId)
}
Say ""

Say "===== SUMMARY ====="
Say ("  install exit code : {0}" -f $rc)
Say ("  preserve folder   : {0}" -f $pres)
Say "  data.sys was NOT returned by this box, the adapter was NOT touched - next steps, separately."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: INSTALL-COMPLETE ====="
Fin ($rc -eq 0)
