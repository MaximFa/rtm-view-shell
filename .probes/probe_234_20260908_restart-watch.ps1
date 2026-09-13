#Requires -Version 5.1
<#
  BOX 234 / restart-and-watch
  WHERE IT RUNS : server 234. This one WRITES: it restarts OUR RTMService and, by the standing
  invariant, our adapter RTMTwilio_1 after it. Nothing else is touched.

  *** NOT TOUCHED, and this is a prohibition, not an omission:
     the production adapter RTM.Twilio and the legacy RTM under C:\IceDash\ - neither is
     started, stopped or read. Garnet, the database and every file outside our two services
     are left alone. No configuration is edited.

  WHY A RESTART AT ALL: everything after the pipe is alive and empty; everything before it is
  unobservable (the adapter writes no log, the engine logs no client connections). Our own
  lesson of 2026-07-13 says a bounce of OUR RTMService re-triggers the adapter's snapshot on the
  pipe and is what populates NGC_Queues. So this is the one action that can produce the missing
  observation - on an empty system where there is nothing to lose.

  It measures BEFORE, restarts, then measures TWICE with a wait between, so growth shows up as a
  DELTA rather than as a single number that cannot be told from a standing zero.
#>

$ErrorActionPreference = "Continue"
$WAIT1 = 60
$WAIT2 = 120
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_restart-watch.txt"
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

$script:psql = $null
$script:pw = ""; $script:usr = "ccdashboard_user"; $script:db = "rtmviewdb"; $script:port = "5433"
function DbCounts($label) {
    if ($null -eq $script:psql -or -not $script:pw) { Say ("  [{0}] database section unavailable - GAP" -f $label); return }
    $f = Join-Path $env:TEMP ("cnt_{0}_{1}.sql" -f $label, $stamp)
    $sql = @'
SELECT 'NGC_BusinessUnit=' || count(*)::text FROM public."NGC_BusinessUnit";
SELECT 'NGC_Queues=' || count(*)::text FROM public."NGC_Queues";
SELECT 'RTSData_Interaction=' || count(*)::text FROM public."RTSData_Interaction";
SELECT 'RTSData_UserStatus=' || count(*)::text FROM public."RTSData_UserStatus";
SELECT 'NGC_Site=' || count(*)::text FROM public."NGC_Site";
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

Say "===== G1  refuse if the machine is not in the state this box was written for ====="
$ours = @("RTMService","RTMTwilio_1")
foreach ($n in $ours) {
    $s = Svc $n
    if ($null -eq $s) { Say ("  {0} ABSENT -> refusing" -f $n); Fin $false }
    Say ("  {0,-13} {1,-9} {2}" -f $s.Name, $s.State, $s.PathName)
}
foreach ($n in @("RTM.Twilio","RTM")) {
    $s = Svc $n
    if ($null -ne $s) {
        Say ("  {0,-13} {1,-9} {2}   <- PRODUCTION/LEGACY, must stay untouched" -f $s.Name, $s.State, $s.PathName)
        if ($s.State -eq "Running") { Say "  *** a production service is Running - refusing to restart anything now"; Fin $false }
    }
}
Say "  G1 PASS - only our two services will be touched"
Say ""

Say "===== 1  the database handle, prepared once ====="
$cs = "$((Get-Content 'C:\RTMView\Shell\appsettings.json' -Raw | ConvertFrom-Json).ConnectionStrings.Default)"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $script:pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $script:usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $script:db  = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $script:port = $m.Groups[1].Value }
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $script:psql)) { $script:psql = $c }
}
Say ("  psql {0} , user {1} , db {2} , port {3} , password {4} chars" -f $(if ($script:psql) { "found" } else { "NOT FOUND" }), $script:usr, $script:db, $script:port, $script:pw.Length)
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
$sizeBefore = $(if (Test-Path $rtmLog) { (Get-Item $rtmLog).Length } else { 0 })
Say ("  engine log size before : {0} bytes" -f $sizeBefore)
Say ""

Say "===== 2  BEFORE ====="
DbCounts "T0"
$pp = PipeServed "rtmpipe_v3"
Say ("  [T0] pipes total {0} , rtmpipe_v3 served {1}" -f $pp.Total, $pp.Served)
Say ""

Say "===== 3  RESTART - our RTMService, then our adapter by the invariant ====="
Say "  Stopping RTMService..."
Stop-Service RTMService -Force -ErrorAction SilentlyContinue
Start-Sleep 6
Say ("  RTMService now : {0}" -f (Svc "RTMService").State)
$orph = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\RTM\*" })
Say ("  orphan processes under C:\RTMView\RTM after stop : {0}   (matched BY PATH, not by service status)" -f $orph.Count)
foreach ($o in $orph) { Say ("      {0} pid {1}" -f $o.ProcessName, $o.Id) }
Say "  Starting RTMService..."
Start-Service RTMService -ErrorAction SilentlyContinue
Start-Sleep 10
Say ("  RTMService now : {0}" -f (Svc "RTMService").State)
$ad = Svc "RTMTwilio_1"
Say ("  RTMTwilio_1 after the engine came up : {0}   (the engine restarts it itself; we check, then act only if needed)" -f $ad.State)
if ($ad.State -ne "Running") {
    Say "  adapter is not Running - starting it explicitly, per the invariant"
    Start-Service RTMTwilio_1 -ErrorAction SilentlyContinue
    Start-Sleep 6
    Say ("  RTMTwilio_1 now : {0}" -f (Svc "RTMTwilio_1").State)
} else {
    Say "  adapter already Running - nothing to do here (this branch says so instead of staying silent)"
}
foreach ($n in @("RTM.Twilio","RTM")) {
    $s = Svc $n
    if ($null -ne $s) { Say ("  {0,-13} {1,-9}  <- confirmed still untouched" -f $s.Name, $s.State) }
}
Say ""

Say ("===== 4  WATCH - two readings, {0} s and {1} s after the restart =====" -f $WAIT1, $WAIT2)
Start-Sleep $WAIT1
$pp = PipeServed "rtmpipe_v3"
Say ("  [T1] pipes total {0} , rtmpipe_v3 served {1}" -f $pp.Total, $pp.Served)
DbCounts "T1"
Start-Sleep ($WAIT2 - $WAIT1)
$pp = PipeServed "rtmpipe_v3"
Say ("  [T2] pipes total {0} , rtmpipe_v3 served {1}" -f $pp.Total, $pp.Served)
DbCounts "T2"
Say "  A number that grows between T1 and T2 is a live wire. Two identical zeros are not."
Say ""

Say "===== 5  what the engine wrote DURING this run - verbatim ====="
if (-not (Test-Path $rtmLog)) { Say "  engine log ABSENT" }
else {
    $sizeAfter = (Get-Item $rtmLog).Length
    Say ("  engine log size : before {0} , after {1} , grew by {2} bytes" -f $sizeBefore, $sizeAfter, ($sizeAfter - $sizeBefore))
    if (($sizeAfter - $sizeBefore) -le 0) { Say "  *** the engine wrote nothing at all during a restart - that itself is a finding" }
    Say "  --- last 30 lines ---"
    foreach ($t in (Get-Content $rtmLog -Tail 30)) { Say ("      {0}" -f $t) }
    foreach ($pat in @("Client","Connect","Union","Queue","Snapshot","ERROR","Exception","License")) {
        $c = @(Select-String -Path $rtmLog -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue).Count
        Say ("  total lines containing '{0}' : {1}" -f $pat, $c)
    }
    Say ("  NEGCTL 'ZzzNoSuchWord' : {0}   (must be 0)" -f @(Select-String -Path $rtmLog -Pattern "ZzzNoSuchWord" -SimpleMatch -ErrorAction SilentlyContinue).Count)
}
Say ""

Say "===== 6  liveness after the bounce - the pair ====="
$curl = "$env:SystemRoot\System32\curl.exe"
if (Test-Path $curl) {
    $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $negc = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/zzz") 2>$null
    Say ("  /health -> {0} , NEGCTL /zzz -> {1}" -f $code, $negc)
} else { Say "  curl.exe absent - not calling it green" }
$pp = PipeServed "rtmpipe_v3"
Say ("  pipe served : {0} (of {1} pipes)" -f $pp.Served, $pp.Total)
Say ""

Say "===== SUMMARY ====="
foreach ($n in @("RTMService","RTMTwilio_1","RTM.Twilio","RTM","RTMViewShell")) {
    $s = Svc $n
    Say ("  {0,-13} {1}" -f $n, $(if ($null -eq $s) { "ABSENT" } else { $s.State }))
}
Say "  Our two services were restarted. C:\IceDash\ was not touched. No file was edited."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: RESTART-WATCH-COMPLETE ====="
Fin $true
