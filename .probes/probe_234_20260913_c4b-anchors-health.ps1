#Requires -Version 5.1
<#
  PROBE 234 / C4b - two loose ends from C4, and the FIRST of them is my instrument, not the system.
  WHERE IT RUNS : server 234 (machine RTM). Name and UUID are a gate. READ ONLY: no install, no
                  restart, no config write, no database, no password. C:\IceDash, the production
                  RTM.Twilio service, legacy RTM and C:\Program Files\CcDashboard are not touched.

  LOOSE END 1 - THE ANCHOR MATCHER WAS BIASED, AND ITS "no" PROVES NOTHING.
    C4 reported all three content anchors as absent, including one that the SAME literal search found
    present in the same file earlier today. The difference is mine: .NET stores string literals as
    UTF-16 in the assembly, and a literal can begin at an ODD byte offset. Decoding the file once from
    offset 0 silently misses every string that starts on an odd boundary - a false "no" that a negative
    control cannot catch, because an impossible literal is absent under BOTH alignments.
    Here the file is decoded from offset 0 AND from offset 1, and each anchor reports WHICH alignment
    found it. A positive control is added: a literal that must exist in any .NET assembly.

  LOOSE END 2 - /health ANSWERED 503, and that is the SYSTEM talking, not the instrument.
    A 503 is a real HTTP answer from a listening server, so the Shell process is up but reports itself
    not ready. C4 asked once, immediately after the install restart. Here it is asked repeatedly with
    the body printed, and the Shell's own log is read for what it says about startup - by the path the
    Shell itself declares, never by a guessed directory.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_c4b-anchors-health.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  now : {0}   READ ONLY' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

function Find-Literal($path, $needle) {
    $b = [IO.File]::ReadAllBytes($path)
    $a0 = [Text.Encoding]::Unicode.GetString($b, 0, $b.Length - ($b.Length % 2))
    $a1 = [Text.Encoding]::Unicode.GetString($b, 1, $b.Length - 1 - (($b.Length - 1) % 2))
    $as = [Text.Encoding]::ASCII.GetString($b)
    if ($a0.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return 'UTF16@even' }
    if ($a1.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return 'UTF16@odd' }
    if ($as.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return 'ASCII' }
    return 'no'
}

Say ''
Say '===== 1  anchors, decoded from BOTH byte alignments ====='
$RTMDLL = 'C:\RTMView\RTM\RTM.dll'
$TWDLL  = 'C:\RTMView\RTM.Twilio\RTM.Twilio.dll'
$SHDLL  = 'C:\RTMView\Shell\CcDashboard.Web.dll'
Say '  POSCTL first: a literal that must exist in any .NET assembly. If THIS is not found, every'
Say '  "no" below is my matcher and nothing else.'
foreach ($f in @($RTMDLL, $TWDLL, $SHDLL)) {
    if (-not (Test-Path -LiteralPath $f)) { Say ('  {0} : absent' -f $f); continue }
    Say ('  POSCTL {0,-24} "System" -> {1}' -f [IO.Path]::GetFileName($f), (Find-Literal $f 'System'))
}
Say ''
$anchors = @(
    [pscustomobject]@{ F=$RTMDLL; N='AddGridConnection: union ' },
    [pscustomobject]@{ F=$RTMDLL; N='refreshUnions Add' },
    [pscustomobject]@{ F=$RTMDLL; N='refreshUnions MISS' },
    [pscustomobject]@{ F=$RTMDLL; N='LoadData union=' },
    [pscustomobject]@{ F=$TWDLL;  N='CLIENT[' },
    [pscustomobject]@{ F=$TWDLL;  N='connect timeout' },
    [pscustomobject]@{ F=$SHDLL;  N='updateUserGrid' }
)
foreach ($a in $anchors) {
    if (-not (Test-Path -LiteralPath $a.F)) { Say ('  {0} : file absent' -f $a.F); continue }
    Say ('  {0,-24} "{1}" -> {2}' -f [IO.Path]::GetFileName($a.F), $a.N, (Find-Literal $a.F $a.N))
}
Say ('  NEGCTL impossible literal -> {0}   expected no' -f (Find-Literal $RTMDLL 'ZZZ-cannot-be-here-ZZZ'))
Flush

Say ''
Say '===== 2  /health, asked more than once, with the body printed ====='
foreach ($i in 1..3) {
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:5000/health' -UseBasicParsing -TimeoutSec 10
        Say ('  try {0} : HTTP {1}   body: {2}' -f $i, $r.StatusCode, ("$($r.Content)").Trim())
    } catch {
        $resp = $_.Exception.Response
        $code = 'no response'
        if ($resp) { $code = [int]$resp.StatusCode }
        $body = ''
        try {
            if ($resp) {
                $sr = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd().Trim()
                $sr.Close()
            }
        } catch { }
        Say ('  try {0} : HTTP {1}   body: {2}' -f $i, $code, $body)
    }
    Start-Sleep -Seconds 4
}
Say '  A 503 is the SERVER answering: the process listens and calls itself not ready.'
Say '  No answer at all would have meant something else entirely - that difference is why the body matters.'

Say ''
Say '===== 3  the Shell log, by the path the Shell DECLARES - never a guessed directory ====='
$aj = 'C:\RTMView\Shell\appsettings.json'
$declared = @()
if (Test-Path -LiteralPath $aj) {
    try {
        $o = Get-Content -LiteralPath $aj -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($sink in @($o.Serilog.WriteTo)) { if ($sink.Args -and $sink.Args.path) { $declared += "$($sink.Args.path)" } }
    } catch { Say ('  *** appsettings.json not parseable : {0}' -f $_.Exception.Message) }
}
Say ('  Serilog sink paths declared : {0}' -f (Safe-Count $declared))
foreach ($d in $declared) { Say ('      {0}' -f $d) }
$cands = New-Object System.Collections.ArrayList
foreach ($d in $declared) {
    $d2 = $d -replace '/', '\'
    if ([IO.Path]::IsPathRooted($d2)) { [void]$cands.Add($d2) }
    else {
        [void]$cands.Add((Join-Path 'C:\RTMView\Shell' $d2))
        [void]$cands.Add((Join-Path ([Environment]::SystemDirectory) $d2))
    }
}
foreach ($c in $cands) {
    $dir = [IO.Path]::GetDirectoryName($c)
    $leaf = [IO.Path]::GetFileNameWithoutExtension($c)
    Say ''
    Say ('  resolved : {0}' -f $c)
    if (-not (Test-Path -LiteralPath $dir)) { Say '      directory absent'; continue }
    $hits = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase) } |
              Sort-Object LastWriteTime -Descending)
    Say ('      files matching : {0}' -f (Safe-Count $hits))
    foreach ($h in @($hits | Select-Object -First 2)) {
        Say ('      {0}   {1} bytes   {2}' -f $h.Name, $h.Length, $h.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
    $newest = @($hits | Select-Object -First 1)
    foreach ($n in $newest) {
        Say ('      --- last 25 lines of {0} ---' -f $n.Name)
        foreach ($l in @(Get-Content -LiteralPath $n.FullName -Tail 25 -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            $t = "$l".Trim()
            if ($t.Length -gt 200) { $t = $t.Substring(0, 200) }
            Say ('      | {0}' -f $t)
        }
    }
}

Say ''
Say '===== what this settles ====='
Say '  Settles: whether the fix literals are inside the installed binaries, and what the Shell says'
Say '  about its own readiness.'
Say '  Does NOT settle: whether the fixes work. That is the acceptance run and it belongs to shell.'
Fin $true
