#Requires -Version 5.1
<#
  PROBE 234 / adapter-config   -   READ ONLY. Nothing is started, stopped, edited or created.
  WHERE IT RUNS : server 234. No database, no service action.
  QUESTION      : why does the adapter write no log, and where is it actually sending data.

  Basis, measured in the object store, not remembered: RTM.Twilio reads the key RTM:LogConfig as
  a PATH and hands it to AsyncLogger.InitializeLog4Net (TwilioAdapter.cs:111-112). The sample
  config in the repository points that path at C:\IceDash\RTM.Twilio\log4net.config - the
  PRODUCTION adapter's folder. So the missing log4net.config in our own folder is expected by
  design; what matters is where OUR copy points and whether that file exists.
  The same config carries RTM:Targets - the address and pipe the adapter feeds. The repository
  sample still names the legacy pipe. This probe prints both, verbatim.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_adapter-config.txt"
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

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

$cfg = "C:\RTMView\RTM.Twilio\appsettings.json"
Say "===== 1  our adapter's config, as bytes and as keys ====="
Say ("  file : {0}   exists {1}" -f $cfg, (Test-Path $cfg))
if (-not (Test-Path $cfg)) { Say "  *** the adapter has no appsettings.json"; Fin $false }
$fi = Get-Item $cfg
Say ("  {0} bytes, modified {1}" -f $fi.Length, $fi.LastWriteTime)
Say ("  sha256 {0}" -f (Get-Sha256Of $cfg))
$raw = Get-Content $cfg -Raw
$j = $raw | ConvertFrom-Json
Say ("  top-level keys : {0}" -f (($j.PSObject.Properties.Name) -join ", "))
if ($j.RTM) { Say ("  RTM section keys : {0}" -f (($j.RTM.PSObject.Properties.Name) -join ", ")) }
Say ""

Say "===== 2  LOGGING - the reason the adapter is silent, or not ====="
$logCfgPath = ""
if ($j.RTM -and $j.RTM.LogConfig) { $logCfgPath = "$($j.RTM.LogConfig)" }
if (-not $logCfgPath) { Say "  RTM:LogConfig - the key is ABSENT from our config entirely" }
else {
    Say ("  RTM:LogConfig = '{0}'" -f $logCfgPath)
    $exists = Test-Path $logCfgPath
    Say ("  that file exists : {0}   <- if False, log4net is never initialised and the adapter cannot log" -f $exists)
    if ($exists) {
        Say ("  its sha256 : {0}" -f (Get-Sha256Of $logCfgPath))
        Say ("  points at C:\IceDash (the PRODUCTION adapter folder) : {0}" -f ($logCfgPath -like "*IceDash*"))
        Say "  --- the file's own content, verbatim (it says where the log would be written) ---"
        foreach ($t in (Get-Content $logCfgPath)) { Say ("      {0}" -f $t) }
    }
}
Say ("  NEGCTL Test-Path on a path that cannot exist : {0}   (must be False)" -f (Test-Path "C:\zzz-no-such-dir\zzz.config"))
Say ""

Say "===== 3  where would the log land - every candidate directory, listed ====="
foreach ($d in @("C:\Logs\RTMView","C:\Logs\RTMTwilio","C:\Logs","C:\RTMView\RTM.Twilio","C:\RTMView\Logs")) {
    if (-not (Test-Path $d)) { Say ("  {0,-28} : does not exist" -f $d); continue }
    $files = @(Get-ChildItem $d -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5)
    Say ("  {0,-28} : files {1}" -f $d, @(Get-ChildItem $d -File -ErrorAction SilentlyContinue).Count)
    foreach ($f in $files) { Say ("        {0,-40} {1,10} bytes   {2}" -f $f.Name, $f.Length, $f.LastWriteTime) }
}
Say ""

Say "===== 4  TARGETS - where the adapter actually sends, verbatim ====="
if (-not $j.RTM.Targets) {
    Say "  RTM:Targets ABSENT - checking the backward-compatible single-target keys instead"
    foreach ($k in @("RTM_URL","Pipe","Url")) {
        if ($j.RTM.PSObject.Properties.Name -contains $k) { Say ("  RTM:{0} = '{1}'" -f $k, $j.RTM.$k) }
    }
} else {
    $i = 0
    foreach ($t in $j.RTM.Targets) {
        $i++
        Say ("  target {0} : keys {1}" -f $i, (($t.PSObject.Properties.Name) -join ", "))
        foreach ($pn in $t.PSObject.Properties.Name) { Say ("      {0} = '{1}'" -f $pn, $t.$pn) }
    }
    Say ("  targets total : {0}" -f $i)
}
Say "  For reference, measured in the object store: the repository SAMPLE names pipe 'rtmpipe'"
Say "  and url 'http://20.80.36.234:8088'. Ours must name 'rtmpipe_v3'. This is a comparison to"
Say "  be made by eye on the lines above, not a verdict printed here."
Say ""

Say "===== 5  the rest of the RTM section, minus anything secret-looking ====="
foreach ($pn in $j.RTM.PSObject.Properties.Name) {
    if ($pn -eq "Targets") { continue }
    $v = "$($j.RTM.$pn)"
    if ($pn -match "(?i)pass|secret|token|key|sid|auth") { Say ("  RTM:{0} = <hidden>, {1} characters" -f $pn, $v.Length) }
    else { Say ("  RTM:{0} = '{1}'" -f $pn, $v) }
}
if ($j.Twilio) {
    Say "  --- Twilio section: names only, values hidden ---"
    foreach ($pn in $j.Twilio.PSObject.Properties.Name) {
        $v = "$($j.Twilio.$pn)"
        Say ("  Twilio:{0} : present {1}, {2} characters" -f $pn, ($v.Length -gt 0), $v.Length)
    }
}
Say ""

Say "===== 6  the process, and whether it holds any file handle we can see ====="
$p = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\RTM.Twilio\*" })
foreach ($pp in $p) {
    Say ("  {0} pid {1} started {2}" -f $pp.ProcessName, $pp.Id, $pp.StartTime)
    Say ("      working set {0:N0} KB , threads {1}" -f ($pp.WorkingSet64/1KB), $pp.Threads.Count)
}
Say ("  adapter processes : {0}" -f $p.Count)
$tcp = @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -in ($p | ForEach-Object { $_.Id }) })
Say ("  TCP connections owned by the adapter : {0}" -f $tcp.Count)
foreach ($c in ($tcp | Select-Object -First 10)) { Say ("      {0}:{1} -> {2}:{3}  {4}" -f $c.LocalAddress, $c.LocalPort, $c.RemoteAddress, $c.RemotePort, $c.State) }
Say ""

Say "===== SUMMARY ====="
Say "  This probe prints. It does not conclude, and it changed nothing."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: ADAPTER-CONFIG-COMPLETE ====="
Fin $true
