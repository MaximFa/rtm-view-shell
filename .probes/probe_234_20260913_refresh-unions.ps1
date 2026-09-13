#Requires -Version 5.1
<#
  PROBE 234 / refresh-unions      the join point: DB-side group names vs call-centre workgroup names.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries no
  database. C:\IceDash is never read or listed. Its only write is its report.

  THE MECHANISM THIS MEASURES [read in the object store on v3, not guessed]:
    RTM/RTM/UserManager.cs:564-595  refreshUnions()
        foreach (List<string> wgArr in union.UserGroups.Values)
            if (ContainsAllItems(_workgroups, wgArr))   // = !wgArr.Except(_workgroups).Any()
                 union.Users.Add(this)   -> AsyncLogger.Info("refreshUnions Add User=... to Union=...")
            else AsyncLogger.Info("refreshUnions MISS user=... union=... need=[...] have=[...]")
  `union.Users.Add(this)` at line 581 is the ONLY place the collection is filled - checked with
  `git grep 'Users.Add'` across RTM/RTM and RTM/RTM.Tools. And the two sides of the comparison come
  from DIFFERENT systems:
    wgArr       <- the DATABASE : Engine.cs:377 UnionUserGroups = RealtimeData.GetAllUnionUserGroups()
                   -> RealtimeData.cs:177 stored procedure RTSGrid_GetAllUnionUserGroups
    _workgroups <- the ADAPTER : what the call centre sends
  The match is exact string equality inside Except(). So the Agent Grid can be empty with a perfectly
  healthy pipe, which is exactly what `<<ChangedUnionUsersData count=0 users=[]` said at 00:16:53.

  WHY THE ENCODING MATTERS, and why this probe reads differently from my earlier ones. The workgroup
  names are HEBREW. My previous probes used plain Get-Content, which on PS 5.1 decodes by the ANSI
  codepage - that is why every earlier report shows `x©x™x—x”` instead of Hebrew. Those reports were
  still sound, because they matched ASCII needles - but here the PAYLOAD IS the evidence: I have to
  compare two lists of Hebrew strings. A mis-decoded read would make two identical names look
  different and would manufacture exactly the defect I am looking for. So every read here is
  `-Encoding UTF8`, and the report is written UTF-8 without BOM.

  WHAT IT ANSWERS:
   1. did refreshUnions run at all, and when last - Add / MISS / Remove, each with its time
   2. for every MISS: need=[...] vs have=[...], and the SET DIFFERENCE computed by the probe
   3. for every differing name, its CHARACTER CODES - so an invisible difference (a different
      Unicode form of the same Hebrew word, a stray space, a bidi control character) is visible as
      numbers instead of looking like two identical strings that refuse to match
   4. POSCTL/NEGCTL on the reader, and a control that the UTF8 read actually produced Hebrew

  EXPECTATIONS, NAMED BEFORE THE RUN:
     refreshUnions lines found : >= 1  -> 0 would mean the function never ran, which is a different
                                          defect and must not be confused with "it ran and missed"
     UTF8 control : at least one line carries a character above U+0590 (Hebrew block), otherwise my
                    decoding is still wrong and NOTHING about the names below is evidence
     NEGCTL : an impossible string -> 0
  The name comparison is REPORTED, not gated: whether a given mismatch is THE cause is the
  coordinator's call.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_refresh-unions.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Show-Codes($name) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $name.ToCharArray()) { [void]$sb.Append(([int]$ch).ToString('X4')); [void]$sb.Append(' ') }
    return $sb.ToString().Trim()
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
$fn = Get-Command Show-Codes -ErrorAction SilentlyContinue
Say ('  Show-Codes resolves to : {0}   expected Function' -f $fn.CommandType)
if ("$($fn.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say '  NOTE: Hebrew names go into the FILE. The console here cannot render them and garbling the'
Say '  console has swallowed following commands before, so the screen gets counts, the file gets names.'

Say ''
Say '===== 1  engine log files, discovered from the SERVICE MANAGER ====='
$wmi = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $wmi) { Say '  *** RTMService not found'; Fin $false }
$exe = "$($wmi.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  engine directory : {0}' -f $engineDir)
$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log|^log\.txt$' } | Sort-Object LastWriteTime)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
Say ('  files : {0}   expected >= 1' -f $files.Count)
if ($files.Count -lt 1) { Say '  *** nothing discovered - refusing to report zeros'; Fin $false }

Say ''
Say '===== 2  refreshUnions lines - read with -Encoding UTF8 so the names are the REAL names ====='
$adds = New-Object System.Collections.ArrayList
$misses = New-Object System.Collections.ArrayList
$removes = New-Object System.Collections.ArrayList
$hebrewSeen = 0
$negCtl = 0
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction SilentlyContinue)
    $hits = @($lines | Where-Object { $_.Contains('refreshUnions') })
    Say ('  {0} : lines {1} , refreshUnions lines {2}' -f $file, $lines.Count, $hits.Count)
    foreach ($h in $hits) {
        foreach ($ch in $h.ToCharArray()) { if ([int]$ch -ge 0x590 -and [int]$ch -le 0x5FF) { $hebrewSeen++; break } }
        if ($h.Contains('refreshUnions Add')) { [void]$adds.Add($h) }
        elseif ($h.Contains('refreshUnions MISS')) { [void]$misses.Add($h) }
        elseif ($h.Contains('refreshUnions Remove')) { [void]$removes.Add($h) }
    }
    $negCtl += @($lines | Where-Object { $_.Contains('ZZZ-cannot-occur-ZZZ') }).Count
}
Say ('  Add    : {0}   <- each one is a user that DID enter a union' -f $adds.Count)
Say ('  MISS   : {0}   <- each one carries need=[...] and have=[...]' -f $misses.Count)
Say ('  Remove : {0}' -f $removes.Count)
Say ('  UTF8 control: refreshUnions lines containing a Hebrew character : {0}' -f $hebrewSeen)
Say ('  NEGCTL impossible string : {0}   expected 0' -f $negCtl)
if (($adds.Count + $misses.Count + $removes.Count) -eq 0) {
    Say '  *** refreshUnions NEVER RAN in these files. That is a DIFFERENT defect from "it ran and'
    Say '      missed", and I will not report it as a name mismatch. Nothing below this line applies.'
    Fin $true
}

Say ''
Say '===== 3  every Add, verbatim (into the FILE) ====='
Say ('  count {0} - see the report file for the lines' -f $adds.Count)
foreach ($a in ($adds | Select-Object -First 60)) { SayFileOnly ('      + ' + $a.Trim()) }

Say ''
Say '===== 4  every MISS, with the SET DIFFERENCE computed here, not eyeballed ====='
Say ('  count {0} - names and code points go into the report file' -f $misses.Count)
$shown = 0
foreach ($m in $misses) {
    if ($shown -ge 40) { break }
    $shown++
    SayFileOnly ''
    SayFileOnly ('  MISS #' + $shown)
    SayFileOnly ('      ' + $m.Trim())
    $needMatch = [regex]::Match($m, 'need=\[(.*?)\]')
    $haveMatch = [regex]::Match($m, 'have=\[(.*?)\]')
    if (-not ($needMatch.Success -and $haveMatch.Success)) { SayFileOnly '      (need/have not parseable from this line)'; continue }
    $need = @($needMatch.Groups[1].Value -split ',' | Where-Object { $_ -ne '' })
    $have = @($haveMatch.Groups[1].Value -split ',' | Where-Object { $_ -ne '' })
    SayFileOnly ('      need count {0} , have count {1}' -f $need.Count, $have.Count)
    $missingItems = @($need | Where-Object { $have -notcontains $_ })
    SayFileOnly ('      names REQUIRED but not present on the user : {0}' -f $missingItems.Count)
    foreach ($mi in $missingItems) {
        SayFileOnly ('        needed : [' + $mi + ']   len ' + $mi.Length)
        SayFileOnly ('          codes : ' + (Show-Codes $mi))
        $near = @($have | Where-Object { $_.Trim() -eq $mi.Trim() })
        if ($near.Count -gt 0) {
            SayFileOnly '          *** the user HAS a name equal after trimming - the difference is WHITESPACE only'
            foreach ($n in $near) { SayFileOnly ('            have  : [' + $n + ']   len ' + $n.Length + '   codes : ' + (Show-Codes $n)) }
        }
        $sameLen = @($have | Where-Object { $_.Length -eq $mi.Length -and $_ -ne $mi })
        foreach ($s in ($sameLen | Select-Object -First 3)) {
            SayFileOnly ('          same length, different bytes : [' + $s + ']   codes : ' + (Show-Codes $s))
        }
    }
    if ($missingItems.Count -eq 0) {
        SayFileOnly '      *** need is a SUBSET of have by my comparison, yet the engine logged a MISS.'
        SayFileOnly '          That would mean the two sides differ in a way my split/compare does not see.'
    }
}

Say ''
Say '===== 5  what the user side looked like - distinct have=[...] sets ====='
$distinctHave = @($misses | ForEach-Object { $mm = [regex]::Match($_, 'have=\[(.*?)\]'); if ($mm.Success) { $mm.Groups[1].Value } } | Sort-Object -Unique)
Say ('  distinct have-sets : {0}' -f $distinctHave.Count)
foreach ($dh in ($distinctHave | Select-Object -First 10)) { SayFileOnly ('      have : [' + $dh + ']') }
$distinctNeed = @($misses | ForEach-Object { $mm = [regex]::Match($_, 'need=\[(.*?)\]'); if ($mm.Success) { $mm.Groups[1].Value } } | Sort-Object -Unique)
Say ('  distinct need-sets : {0}' -f $distinctNeed.Count)
foreach ($dn in ($distinctNeed | Select-Object -First 10)) { SayFileOnly ('      need : [' + $dn + ']') }

Say ''
Say '===== verdict - on MY instrument ====='
$instrumentOk = (($negCtl -eq 0) -and ($hebrewSeen -gt 0 -or $misses.Count -eq 0))
Say ('  NEGCTL 0 : {0} ; Hebrew decoded : {1} ; files read : {2}' -f ($negCtl -eq 0), $hebrewSeen, $files.Count)
if ($hebrewSeen -eq 0 -and $misses.Count -gt 0) {
    Say '  *** MISS lines exist but none carried a Hebrew character: my decoding is still wrong and the'
    Say '      name comparison above is NOT evidence. Do not act on it.'
}
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin $instrumentOk
