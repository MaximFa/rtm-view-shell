#Requires -Version 5.1
<#
  PROBE 234 / liveness   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  THE PAIR      : /health returning 200 is NOT liveness on its own. The web host comes up whether
                  or not the engine did. Liveness is /health 200 AND a named pipe whose name is
                  the one in the deployed config. Either alone has lied to us before.
  READ FROM DISK: the pipe name is taken from C:\RTMView\RTM\appsettings.json, not from memory
                  and not from the install log. We check for the pipe the app actually asks for.
  BOTH CONTROLS : the pipe list is also searched for a name that cannot exist - if that "finds"
                  something, the search is broken and its positive answer means nothing.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_liveness.txt"
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

$fail = 0

Say ""
Say "===== 1  services ====="
foreach ($nm in @('RTMViewShell','RTMService','RTMTwilio_1')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $st = $(if ($s) { "$($s.Status)" } else { "not registered" })
    Say ("  {0,-16} {1}" -f $nm, $st)
    if ($st -ne 'Running') { $fail++ }
}
foreach ($nm in @('RTM.Twilio','RTM')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    Say ("  NEVER {0,-14} {1}" -f $nm, $(if ($s) { $s.Status } else { "not present" }))
}

Say ""
Say "===== 2  the pipe name the app actually asks for - read FROM DISK ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$pipeName = $null
if (Test-Path $rtmCfg) {
    $mm = [regex]::Match([IO.File]::ReadAllText($rtmCfg), '"PipeName"\s*:\s*"([^"]*)"')
    if ($mm.Success) { $pipeName = $mm.Groups[1].Value }
}
Say ("  PipeName on disk : {0}" -f $(if ($pipeName) { $pipeName } else { "<absent>" }))
if (-not $pipeName) { Say "  *** STOP - no pipe name in the deployed config; there is nothing to look for."; Fin $false }

Say ""
Say "===== 3  is that pipe actually served ====="
$pipes = @([System.IO.Directory]::GetFiles("\\.\pipe\"))
Say ("  named pipes on the machine : {0}" -f $pipes.Count)
$ours = @($pipes | Where-Object { $_ -like "*$pipeName*" })
Say ("  pipes matching '{0}' : {1}" -f $pipeName, $ours.Count)
foreach ($p2 in $ours) { Say ("      {0}" -f $p2) }
$pipeOk = ($ours.Count -gt 0)
Say ("  NEGCTL a pipe name that cannot exist : {0}   (must be 0 - if this finds something the search is broken)" -f @($pipes | Where-Object { $_ -like "*zzz_no_such_pipe_xyz*" }).Count)
Say  "  (for context, a few pipe names present, to show the list is real:)"
foreach ($p3 in ($pipes | Select-Object -First 5)) { Say ("      {0}" -f $p3) }
if (-not $pipeOk) { Say ("  *** the pipe '{0}' is NOT served" -f $pipeName); $fail++ }

Say ""
Say "===== 4  /health - the half that lies on its own ====="
foreach ($url in @("http://127.0.0.1:5000/health", "http://localhost:5000/health")) {
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
        Say ("  {0,-40} HTTP {1}   body: {2}" -f $url, $r.StatusCode, ("$($r.Content)").Trim().Substring(0, [Math]::Min(60, ("$($r.Content)").Trim().Length)))
        if ($r.StatusCode -ne 200) { $fail++ }
    } catch {
        Say ("  {0,-40} FAILED: {1}" -f $url, $_.Exception.Message)
        $fail++
    }
}
Say  "  NEGCTL a path that must NOT answer 200:"
try {
    $r2 = Invoke-WebRequest -Uri "http://127.0.0.1:5000/zzz-no-such-endpoint" -UseBasicParsing -TimeoutSec 10
    Say ("      /zzz-no-such-endpoint -> HTTP {0}   (200 here would mean the check cannot fail)" -f $r2.StatusCode)
    if ($r2.StatusCode -eq 200) { $fail++ }
} catch {
    Say ("      /zzz-no-such-endpoint -> refused/404 as it should ({0})" -f $_.Exception.Response.StatusCode.value__)
}

Say ""
Say "===== 5  the pair, stated as one verdict ====="
$httpOk = ($fail -eq 0 -or $pipeOk)
Say ("  /health 200 : see above")
Say ("  pipe '{0}' served : {1}" -f $pipeName, $pipeOk)
Say  "  LIVENESS = both. One without the other is not liveness:"
Say  "     - /health alone: the web host answers even when the engine never started;"
Say  "     - pipe alone: the engine may be up while the UI is unreachable."

Say ""
Say "===== 6  what the engine says about itself, last lines of its log ====="
$logDir = "C:\RTMView\Logs"
if (Test-Path $logDir) {
    $lg = @(Get-ChildItem $logDir -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    foreach ($f in $lg) {
        Say ("  --- {0}  ({1} bytes, {2}) ---" -f $f.Name, $f.Length, $f.LastWriteTime)
        $tail = @(Get-Content $f.FullName -Tail 12 -ErrorAction SilentlyContinue)
        foreach ($t in $tail) { Say ("      {0}" -f $t) }
    }
    Say ("  KeyNotFoundException anywhere in the logs : {0}   (the standing prediction says 0)" -f @(Get-ChildItem $logDir -File -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern 'KeyNotFoundException' -List -ErrorAction SilentlyContinue).Count)
    Say ("  QueueNumberOfLoggedAgents mentioned      : {0}   (the removed metric; 0 expected)" -f @(Get-ChildItem $logDir -File -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern 'QueueNumberOfLoggedAgents' -List -ErrorAction SilentlyContinue).Count)
    Say ("  NEGCTL a word that must appear (INF)     : {0}   (must be > 0 - proves the log search works)" -f @(Get-ChildItem $logDir -File -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern 'INF' -List -ErrorAction SilentlyContinue).Count)
} else { Say ("  log directory absent: {0}" -f $logDir) }

Say ""
Say "===== END-OF-RUN MARKER: LIVENESS-COMPLETE ====="
Say ""
Say "NOTHING WAS STARTED, STOPPED OR CHANGED."
Fin ($fail -eq 0)
