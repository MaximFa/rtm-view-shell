#Requires -Version 5.1
<#
  BOX 234 / adapter-eyes-then-test
  WHERE IT RUNS : server 234. It touches ONLY our adapter RTMTwilio_1 and creates ONE file that
  is currently missing. The engine is NOT restarted. C:\IceDash\ is not touched. No existing
  file is edited - if the target file already exists, this box refuses and changes nothing.

  STEP 1 - EYES. C:\RTMView\RTM.Twilio\log4net.config is missing, and RTM:LogConfig points at it,
  so log4net is never initialised and the adapter cannot write a single line. The content written
  here is the BYTE-EXACT file from the working machine 140 (sha256 1D520F4D...13FA2), carried over
  as base64 so nothing can re-encode it in transit. It logs to C:\Logs\RTM.Twilio\log.txt.
  This is the ADDITION of an absent file, not a change to a working one.

  STEP 2 - THE TEST. Restart ONLY the adapter while the engine is already listening. Reason:
  revision 8abd19a connects to the pipe ONCE at startup and never retries (RTMAdapter.cs:58-71);
  today the adapter process started at 11:47:29 and the engine's pipe server at 11:47:29.617, so
  the adapter may have knocked before anyone was listening. Starting it against a listening server
  is the one experiment that separates that from a real feed failure.

  Counters are read three times so growth appears as a DELTA. Two identical zeros are not a wire.
#>

$ErrorActionPreference = "Continue"
$CFG      = "C:\RTMView\RTM.Twilio\log4net.config"
$REFSHA   = "1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2"
$ADAPTLOG = "C:\Logs\RTM.Twilio\log.txt"
$OutDir   = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_adapter-eyes.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "RUN COMPLETE" } else { "RUN ABORTED" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }
function Svc($n) { return (Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $n) -ErrorAction SilentlyContinue) }
function PipeServed($n) {
    $p = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
    return @{ Total = $p.Count; Served = ($p -contains $n) }
}
$script:psql = $null; $script:pw = ""; $script:usr = "ccdashboard_user"; $script:db = "rtmviewdb"; $script:port = "5433"
function DbCounts($label) {
    if ($null -eq $script:psql -or -not $script:pw) { Say ("  [{0}] database unavailable - GAP" -f $label); return }
    $f = Join-Path $env:TEMP ("c_{0}_{1}.sql" -f $label, $stamp)
    $sql = @'
SELECT 'BU=' || count(*)::text FROM public."NGC_BusinessUnit";
SELECT 'Queues=' || count(*)::text FROM public."NGC_Queues";
SELECT 'Interaction=' || count(*)::text FROM public."RTSData_Interaction";
SELECT 'UserStatus=' || count(*)::text FROM public."RTSData_UserStatus";
'@
    [IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $script:pw
    $rows = & $script:psql -h 127.0.0.1 -p $script:port -U $script:usr -d $script:db -At -f $f 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $f -ErrorAction SilentlyContinue
    Say ("  [{0}] {1}   (psql rc {2})" -f $label, (($rows | ForEach-Object { "$_" }) -join "  "), $rc)
}

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  this file sha256 : {0}" -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

Say "===== G1  refuse unless the machine is in the state this box expects ====="
$eng = Svc "RTMService"
$ad  = Svc "RTMTwilio_1"
if ($null -eq $eng -or $null -eq $ad) { Say "  one of our services is ABSENT - refusing"; Fin $false }
Say ("  RTMService  {0}" -f $eng.State)
Say ("  RTMTwilio_1 {0}" -f $ad.State)
if ($eng.State -ne "Running") { Say "  *** the engine is not Running - the experiment needs it listening. Refusing."; Fin $false }
$pp = PipeServed "rtmpipe_v3"
Say ("  pipe rtmpipe_v3 served BEFORE anything : {0} (of {1} pipes)" -f $pp.Served, $pp.Total)
if (-not $pp.Served) { Say "  *** the engine is not serving its pipe - nothing to connect to. Refusing."; Fin $false }
foreach ($n in @("RTM.Twilio","RTM")) {
    $s = Svc $n
    if ($null -ne $s) {
        Say ("  {0,-12} {1}   <- production/legacy, must stay untouched" -f $s.Name, $s.State)
        if ($s.State -eq "Running") { Say "  *** a production service is Running - refusing"; Fin $false }
    }
}
Say "  G1 PASS"
Say ""

Say "===== STEP 1  EYES - write the missing log4net.config, byte-exact from machine 140 ====="
Say ("  target : {0}" -f $CFG)
if (Test-Path $CFG) {
    Say ("  the file ALREADY EXISTS (sha256 {0})" -f (Get-Sha256Of $CFG))
    Say "  *** this box only ADDS an absent file; it does not overwrite. Refusing to touch it."
    Fin $false
}
$b64 = '' +
  'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiID8+DQo8Y29uZmlndXJhdGlvbj4NCgk8bG9nNG5ldD4NCgkJPGFw' +
  'cGVuZGVyIG5hbWU9IkxvZ0ZpbGVBcHBlbmRlciIgdHlwZT0ibG9nNG5ldC5BcHBlbmRlci5Sb2xsaW5nRmlsZUFwcGVuZGVyIj4N' +
  'CgkJCTxwYXJhbSBuYW1lPSJGaWxlIiB2YWx1ZT0iQzpcTG9nc1xSVE0uVHdpbGlvXGxvZy50eHQiLz4NCgkJCTxsb2NraW5nTW9k' +
  'ZWwgdHlwZT0ibG9nNG5ldC5BcHBlbmRlci5GaWxlQXBwZW5kZXIrTWluaW1hbExvY2siIC8+DQoJCQk8YXBwZW5kVG9GaWxlIHZh' +
  'bHVlPSJ0cnVlIiAvPg0KCQkJPHJvbGxpbmdTdHlsZSB2YWx1ZT0iU2l6ZSIgLz4NCgkJCTxtYXhTaXplUm9sbEJhY2t1cHMgdmFs' +
  'dWU9IjEwMCIgLz4NCgkJCTxtYXhpbXVtRmlsZVNpemUgdmFsdWU9IjVNQiIgLz4NCgkJCTxzdGF0aWNMb2dGaWxlTmFtZSB2YWx1' +
  'ZT0idHJ1ZSIgLz4NCgkJCTxsYXlvdXQgdHlwZT0ibG9nNG5ldC5MYXlvdXQuUGF0dGVybkxheW91dCI+DQoJCQkJPHBhcmFtIG5h' +
  'bWU9IkNvbnZlcnNpb25QYXR0ZXJuIiB2YWx1ZT0iJWRhdGV7ZGQvTU0veXl5eSBISDptbTpzcyxmZmZ9ICUtNXAgJW0lbiAlZXhj' +
  'ZXB0aW9uIi8+DQoJCQk8L2xheW91dD4NCgkJPC9hcHBlbmRlcj4NCgkJPHJvb3Q+DQoJCQk8bGV2ZWwgdmFsdWU9IkFMTCIgLz4N' +
  'CgkJCTxhcHBlbmRlci1yZWYgcmVmPSJMb2dGaWxlQXBwZW5kZXIiIC8+DQoJCTwvcm9vdD4NCg0KCTwvbG9nNG5ldD4NCjwvY29u' +
  'ZmlndXJhdGlvbj4='
$bytes = [Convert]::FromBase64String($b64)
Say ("  bytes to write : {0}" -f $bytes.Length)
[IO.File]::WriteAllBytes($CFG, $bytes)
$after = Get-Sha256Of $CFG
Say ("  written. re-read from disk, sha256 : {0}" -f $after)
Say ("  reference from machine 140          : {0}" -f $REFSHA)
Say ("  identical : {0}   (must be True)" -f ($after -eq $REFSHA))
if ($after -ne $REFSHA) { Say "  *** the file on disk is not what we meant to write. Refusing to go further."; Fin $false }
Say ("  size on disk : {0} bytes" -f (Get-Item $CFG).Length)
Say "  --- its content, read back from disk, verbatim ---"
foreach ($t in (Get-Content $CFG)) { Say ("      {0}" -f $t) }
$logDir = Split-Path $ADAPTLOG -Parent
Say ("  the log directory it names : {0}   exists {1}" -f $logDir, (Test-Path $logDir))
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null; Say ("  created {0}" -f $logDir) }
Say ""

Say "===== 2  the database handle, and the counters BEFORE the experiment ====="
$cs = "$((Get-Content 'C:\RTMView\Shell\appsettings.json' -Raw | ConvertFrom-Json).ConnectionStrings.Default)"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $script:pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $script:usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $script:db  = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $script:port = $m.Groups[1].Value }
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $script:psql)) { $script:psql = $c }
}
DbCounts "T0"
Say ""

Say "===== STEP 2  THE TEST - restart ONLY the adapter, engine untouched and listening ====="
Say ("  engine before : {0} , pipe served : {1}" -f (Svc 'RTMService').State, (PipeServed 'rtmpipe_v3').Served)
Say "  Stopping RTMTwilio_1..."
Stop-Service RTMTwilio_1 -Force -ErrorAction SilentlyContinue
Start-Sleep 5
Say ("  RTMTwilio_1 now : {0}" -f (Svc "RTMTwilio_1").State)
$orph = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\RTM.Twilio\*" })
Say ("  orphan adapter processes after stop : {0}   (matched BY PATH)" -f $orph.Count)
$pp = PipeServed "rtmpipe_v3"
Say ("  pipe still served while the adapter is down : {0}   (proves the server side is the engine, not the adapter)" -f $pp.Served)
Say ("  engine state unchanged : {0}" -f (Svc 'RTMService').State)
Say "  Starting RTMTwilio_1 against a server that is already listening..."
Start-Service RTMTwilio_1 -ErrorAction SilentlyContinue
Start-Sleep 8
Say ("  RTMTwilio_1 now : {0}" -f (Svc "RTMTwilio_1").State)
$p = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\RTM.Twilio\*" })
foreach ($pp2 in $p) { Say ("  process {0} pid {1} started {2}" -f $pp2.ProcessName, $pp2.Id, $pp2.StartTime) }
Say ""

Say "===== 3  WATCH - 60 s and 150 s after the adapter came up ====="
Start-Sleep 60
DbCounts "T1"
Say ("  [T1] adapter log exists : {0}" -f (Test-Path $ADAPTLOG))
if (Test-Path $ADAPTLOG) { Say ("  [T1] adapter log size : {0} bytes" -f (Get-Item $ADAPTLOG).Length) }
Start-Sleep 90
DbCounts "T2"
if (Test-Path $ADAPTLOG) { Say ("  [T2] adapter log size : {0} bytes" -f (Get-Item $ADAPTLOG).Length) }
Say "  A number that grows between T1 and T2 is a live wire. Two identical zeros are not."
Say ""

Say "===== 4  WHAT THE ADAPTER SAYS - its first words in two days ====="
if (-not (Test-Path $ADAPTLOG)) {
    Say ("  {0} : ABSENT" -f $ADAPTLOG)
    Say "  The adapter still wrote nothing. With the config now in place that is itself a finding:"
    Say "  either it never reads the key, or it dies before logging starts."
    $alt = @(Get-ChildItem "C:\Logs" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-10) })
    Say ("  any file under C:\Logs written in the last 10 minutes : {0}   (POSITIVE control on where to look)" -f $alt.Count)
    foreach ($a in $alt) { Say ("      {0}  {1} bytes  {2}" -f $a.FullName, $a.Length, $a.LastWriteTime) }
} else {
    $fi = Get-Item $ADAPTLOG
    Say ("  {0}  {1} bytes, modified {2}" -f $ADAPTLOG, $fi.Length, $fi.LastWriteTime)
    foreach ($pat in @("ERROR","Exception","pipe","Pipe","Connect","Twilio","Target")) {
        $c = @(Select-String -Path $ADAPTLOG -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue).Count
        Say ("  lines containing '{0}' : {1}" -f $pat, $c)
    }
    Say ("  NEGCTL 'ZzzNoSuchWord' : {0}   (must be 0)" -f @(Select-String -Path $ADAPTLOG -Pattern "ZzzNoSuchWord" -SimpleMatch -ErrorAction SilentlyContinue).Count)
    Say "  --- first 20 lines ---"
    foreach ($t in (Get-Content $ADAPTLOG -TotalCount 20)) { Say ("      {0}" -f $t) }
    Say "  --- last 25 lines ---"
    foreach ($t in (Get-Content $ADAPTLOG -Tail 25)) { Say ("      {0}" -f $t) }
}
Say ""

Say "===== 5  the engine's side during the same window ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (Test-Path $rtmLog) {
    Say ("  {0}  {1} bytes, modified {2}" -f $rtmLog, (Get-Item $rtmLog).Length, (Get-Item $rtmLog).LastWriteTime)
    Say "  --- last 12 lines ---"
    foreach ($t in (Get-Content $rtmLog -Tail 12)) { Say ("      {0}" -f $t) }
} else { Say "  engine log ABSENT" }
$pp = PipeServed "rtmpipe_v3"
Say ("  pipe served at the end : {0}" -f $pp.Served)
foreach ($n in @("RTMService","RTMTwilio_1","RTM.Twilio","RTM","RTMViewShell")) {
    $s = Svc $n
    Say ("  {0,-13} {1}" -f $n, $(if ($null -eq $s) { "ABSENT" } else { $s.State }))
}
Say ""

Say "===== SUMMARY ====="
Say "  One file was created (it was absent). Only the adapter service was restarted."
Say "  The engine was not restarted. C:\IceDash\ was not touched. No existing file was edited."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: ADAPTER-EYES-COMPLETE ====="
Fin $true
