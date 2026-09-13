#Requires -Version 5.1
<#
  PROBE 234 / adapter-inventory   -   READ ONLY. Nothing is installed, extracted or changed.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  PURPOSE       : the adapter has to be installed by hand, but WITH WHAT is not yet established.
                  C:\RTMView\RTM.Twilio was deleted with everything else, and the two adapter
                  snapshots inside Backup (rtmtwilio_20260712_152233, rtmtwilio_predeploy_...)
                  were on the DELIBERATELY RELEASED list - so they are gone too. That was a
                  decision taken with the numbers in hand, not an accident; but it means the
                  binaries must come from somewhere else, and that somewhere must be found and
                  proved before anything is installed.
  ASKS ONLY     : what exists, where, how big, and what is inside it. Nothing is assumed present.
  ABSENCE IS AN ANSWER : if nothing suitable is on the machine, the probe says so plainly.
#>

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Incoming  = Join-Path $OpsRoot "incoming"
$Preserve  = Join-Path $OpsRoot "preserve_20260906_1230"
$CurDir    = Join-Path $Preserve "configs\current"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_adapter-inventory.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name {0} / uuid {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** not server 234"; Fin $false }
Say "  G0 PASS"

Say ""
Say "===== 1  is the adapter directory there at all ====="
$dir = "C:\RTMView\RTM.Twilio"
Say ("  {0} exists : {1}   (expected False - it went with the wipe)" -f $dir, (Test-Path $dir))
Say ("  service RTMTwilio_1 : {0}   (expected: not registered)" -f $(if (Get-Service -Name RTMTwilio_1 -ErrorAction SilentlyContinue) { (Get-Service RTMTwilio_1).Status } else { "not registered" }))
Say ("  NEVER  RTM.Twilio   : {0}   (production - must stay Stopped, we do not touch it)" -f $(if (Get-Service -Name RTM.Twilio -ErrorAction SilentlyContinue) { (Get-Service RTM.Twilio).Status } else { "not present" }))

Say ""
Say "===== 2  its config - the one thing we DID evacuate ====="
$cfg = Join-Path $CurDir "RTM.Twilio__appsettings.json"
if (Test-Path $cfg) {
    Say ("  {0}" -f $cfg)
    Say ("  size {0}, sha256 {1}" -f (Get-Item $cfg).Length, (Get-FileHash $cfg -Algorithm SHA256).Hash)
    $t = [IO.File]::ReadAllText($cfg)
    foreach ($k in @('PipeName','ServiceName','TenantId','AccountSid','ApiKey','AuthToken','Url','BaseUrl')) {
        $mm = [regex]::Match($t, '"' + $k + '"\s*:\s*"([^"]*)"')
        if ($mm.Success) {
            if ($k -match '(?i)token|key|sid|secret|password') { Say ("      {0,-12} : <length {1}, never printed>" -f $k, $mm.Groups[1].Value.Length) }
            else { Say ("      {0,-12} : {1}" -f $k, $mm.Groups[1].Value) }
        } else { Say ("      {0,-12} : key absent" -f $k) }
    }
} else { Say ("  *** the adapter config is NOT in preserve_: {0}" -f $cfg) }

Say ""
Say "===== 3  what is in incoming\ - candidates for the binaries ====="
$items = @(Get-ChildItem $Incoming -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ("  files in incoming : {0}" -f $items.Count)
foreach ($f in $items) {
    Say ("      {0,-52} {1,12}  {2}" -f $f.Name, $f.Length, $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
}

Say ""
Say "===== 4  inside every zip that could be the adapter - by CONTENT, not by name ====="
Add-Type -AssemblyName System.IO.Compression.FileSystem
$found = 0
foreach ($z in @($items | Where-Object { $_.Extension -eq '.zip' })) {
    Say ("  --- {0} ---" -f $z.Name)
    Say ("      sha256 {0}" -f (Get-FileHash $z.FullName -Algorithm SHA256).Hash)
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
        $zip.Dispose()
    } catch {
        Say ("      *** cannot open: {0}" -f $_.Exception.Message)
        continue
    }
    $exe = @($names | Where-Object { $_ -match '(?i)RTM\.Twilio\.exe$' })
    $dll = @($names | Where-Object { $_ -match '(?i)\.dll$' })
    $json= @($names | Where-Object { $_ -match '(?i)appsettings.*\.json$' })
    Say ("      entries {0} | RTM.Twilio.exe {1} | dll {2} | appsettings {3}" -f $names.Count, $exe.Count, $dll.Count, $json.Count)
    foreach ($e in $exe)  { Say ("          exe : {0}" -f $e) }
    foreach ($j in $json) { Say ("          cfg : {0}" -f $j) }
    if ($exe.Count -gt 0) { $found++; Say "      -> this archive CONTAINS the adapter executable" }
    else { Say "      -> no adapter executable here" }
}
Say ("  archives containing RTM.Twilio.exe : {0}" -f $found)
if ($found -eq 0) { Say "  *** NOTHING ON THIS MACHINE CAN INSTALL THE ADAPTER. That is the answer - report it." }

Say ""
Say "===== 5  did anything of the adapter survive under preserve_ (by content) ====="
$pres = @(Get-ChildItem $Preserve -Recurse -File -Filter "RTM.Twilio.exe" -ErrorAction SilentlyContinue)
Say ("  RTM.Twilio.exe under preserve_ : {0}" -f $pres.Count)
foreach ($p2 in $pres) { Say ("      {0}   {1} bytes" -f $p2.FullName, $p2.Length) }
Say ("  NEGCTL a file that cannot be there : {0}   (must be 0)" -f @(Get-ChildItem $Preserve -Recurse -File -Filter "ZZZNoSuch.exe" -ErrorAction SilentlyContinue).Count)

Say ""
Say "===== 6  what the deployed RTM config expects the adapter to be called ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
if (Test-Path $rtmCfg) {
    $rt = [IO.File]::ReadAllText($rtmCfg)
    foreach ($k in @('AdaptorServiceName','PipeName','TenantId')) {
        $mm = [regex]::Match($rt, '"' + $k + '"\s*:\s*"([^"]*)"')
        Say ("      {0,-20} : {1}   (read from disk, not from the install log)" -f $k, $(if ($mm.Success) { $mm.Groups[1].Value } else { "key absent" }))
    }
} else { Say ("  *** deployed RTM config missing: {0}" -f $rtmCfg) }

Say ""
Say "===== END-OF-RUN MARKER: ADAPTER-INVENTORY-COMPLETE ====="
Say ""
Say "NOTHING WAS INSTALLED, EXTRACTED OR CHANGED."
Fin $true
