#Requires -Version 5.1
<#
  PROBE 234 / after-mapping      the mapping was added and the services restarted, and the grid is
                                 still empty. This measures WHY, and it tests an ORDER, not a count.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries NO
  database, prompts for no password. C:\IceDash is never read or listed. Only write: its report.

  THE MARK IS DISCOVERED, NOT GIVEN. Earlier tonight I was handed a mark and mis-assigned events around
  it. Here the mark is the RTMService process start time, taken from the process itself, so it cannot
  be stale or mistyped, and the adapter's own start time is printed beside it.

  THE MECHANISM, re-read in the object store on v3 [not guessed]:
    UserManager.cs:665,677  refreshUnions() is called ONLY from workgroupActivation(...)
         -> it never runs on a timer, and never runs because a mapping was loaded
    UserManager.cs:570-593  foreach (wgArr in union.UserGroups.Values) { if (ContainsAllItems(...)) Add
                            else Info("refreshUnions MISS ... need=[...] have=[...]") }
    Engine.cs:549-555       union.UserGroups is filled ONLY from RTSGrid_GetAllUnionUserGroups rows,
                            each logged as "LoadData union=<N> sg=<S> needGroups=[...]"
  So a user enters a union only when the adapter reports a workgroup activation for them AFTER the
  mapping is in memory. The adapter replays activations as a snapshot on connect.

  THE SUSPICION THIS RUN EXISTS TO TEST - an ORDER, stated before the numbers:
    if the activation snapshot arrives BEFORE the engine finished loading the mapping, then at that
    moment UserGroups is still empty, the loop iterates zero times, NOTHING is logged - no Add and no
    MISS - and the user cannot enter the union until the next activation event. With no traffic there
    is no next event, so the grid stays empty for the rest of the day even though the mapping is now
    correct. That is a RACE, and a count cannot see it: only the relative TIME of
        "LoadData union=... needGroups=[...]"   versus   the first "workgroupActivation" after the mark
    can. Both are printed with times, and the probe states which came first.

  THE THREE OUTCOMES, named before the run:
    A. refreshUnions MISS lines for the new union exist -> the mapping IS in memory and the comparison
       failed. Then the answer is in need=[...] vs have=[...], and the probe prints the set difference
       and character codes, so an invisible mismatch is visible as numbers.
    B. no refreshUnions lines at all after the mark, while workgroupActivation lines ARE present ->
       the race above, or the mapping never loaded. The LoadData timing distinguishes those two.
    C. no workgroupActivation lines after the mark -> the adapter never replayed the snapshot, and the
       subject is back on the adapter side. Nothing about the mapping can be concluded.

  EXPECTATIONS:
     RTMService start time found                  : yes, or the probe stops
     LoadData union= lines after the mark         : >= 1 if the mapping loaded; the IDS are the answer
     POSCTL : "LoadData: Union User Groups" banner present after the mark - proves the load ran at all
     NEGCTL : an impossible string -> 0
  Hebrew goes to the FILE only; reads are -Encoding UTF8 so the names are the real names.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_after-mapping.txt')
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
$FORMATS = @('yyyy-MM-dd HH:mm:ss,fff','dd/MM/yyyy HH:mm:ss,fff','yyyy-MM-dd HH:mm:ss','dd/MM/yyyy HH:mm:ss')
function Get-LineTime($text) {
    $t = "$text".TrimStart()
    if ($t.Length -lt 19) { return $null }
    foreach ($len in @(23, 19)) {
        if ($t.Length -lt $len) { continue }
        $head = $t.Substring(0, $len)
        foreach ($fmt in $FORMATS) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParseExact($head, $fmt, [Globalization.CultureInfo]::InvariantCulture,
                                          [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $parsed }
        }
    }
    return $null
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
foreach ($helper in @('Get-LineTime','Show-Codes')) {
    $r = Get-Command $helper -ErrorAction SilentlyContinue
    Say ('  {0} resolves to : {1}   expected Function' -f $helper, $r.CommandType)
    if ("$($r.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
}
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say '  NO database query, NO password. Hebrew names go to the FILE only.'

Say ''
Say '===== 1  THE MARK, discovered from the processes themselves ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
$svcAdapter = Get-WmiObject Win32_Service -Filter "Name='RTMTwilio_1'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$pEngine = Get-Process -Id $svcEngine.ProcessId -ErrorAction SilentlyContinue
if (-not $pEngine) { Say '  *** RTMService has no live process - cannot take a mark'; Fin $false }
$MarkTime = $pEngine.StartTime
Say ('  RTMService  pid {0}  started {1}   <- THE MARK' -f $pEngine.Id, $MarkTime.ToString('yyyy-MM-dd HH:mm:ss'))
if ($svcAdapter) {
    $pAd = Get-Process -Id $svcAdapter.ProcessId -ErrorAction SilentlyContinue
    if ($pAd) { Say ('  RTMTwilio_1 pid {0}  started {1}' -f $pAd.Id, $pAd.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
    else { Say '  RTMTwilio_1 : no live process' }
}
$exe = "$($svcEngine.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  engine directory : {0}' -f $engineDir)

$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM', 'C:\Logs\RTM.Twilio')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log|^log\.txt$' } |
                     Where-Object { $_.LastWriteTime -gt $MarkTime.AddHours(-2) } | Sort-Object LastWriteTime)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
Say ('  files : {0}   expected >= 1' -f $files.Count)
if ($files.Count -lt 1) { Say '  *** nothing discovered - refusing to report zeros'; Fin $false }

Say ''
Say '===== 2  everything after the mark, sliced by each line own timestamp ====='
$after = New-Object System.Collections.ArrayList
$unparsed = 0
$negCtl = 0
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction SilentlyContinue)
    $fa = 0
    foreach ($line in $lines) {
        if ($line.Contains('ZZZ-cannot-occur-ZZZ')) { $negCtl++ }
        $tm = Get-LineTime $line
        if ($null -eq $tm) { $unparsed++; continue }
        if ($tm -gt $MarkTime) { $fa++; [void]$after.Add([pscustomobject]@{ Time = $tm; Text = $line }) }
    }
    Say ('  {0} : lines {1} , after the mark {2}' -f $file, $lines.Count, $fa)
}
$after = @($after | Sort-Object Time)
Say ('  total after the mark : {0} , unparsed (stack traces etc) : {1}' -f $after.Count, $unparsed)
Say ('  NEGCTL impossible string : {0}   expected 0' -f $negCtl)
$banner = @($after | Where-Object { $_.Text.Contains('LoadData: Union User Groups') })
Say ('  POSCTL "LoadData: Union User Groups" banners after the mark : {0}   expected >= 1' -f $banner.Count)
if ($after.Count -lt 1) { Say '  *** nothing at all after the mark - the engine has not written since start'; Fin $false }

Say ''
Say '===== 3  THE NEW MAPPING, as the engine actually loaded it ====='
$loads = @($after | Where-Object { $_.Text.Contains('LoadData union=') })
Say ('  LoadData union= lines after the mark : {0}' -f $loads.Count)
$ids = New-Object System.Collections.ArrayList
foreach ($l in $loads) {
    $m = [regex]::Match($l.Text, 'LoadData union=(\d+)\s+sg=(\d+)')
    if ($m.Success) { $uid = [int]$m.Groups[1].Value; if (-not $ids.Contains($uid)) { [void]$ids.Add($uid) } }
    SayFileOnly ('      | ' + $l.Text.Trim())
}
Say ('  unions now in the mapping : ' + (@($ids | Sort-Object) -join ', '))
$firstLoad = $null
if ($loads.Count -gt 0) { $firstLoad = $loads[0].Time; Say ('  first mapping row logged at : {0}' -f $firstLoad.ToString('HH:mm:ss.fff')) }
else { Say '  *** no mapping row logged after the mark: either the load has not run yet, or the rows were' ; Say '      already in memory (impossible on a fresh start), or the mapping is still empty' }

Say ''
Say '===== 4  THE ORDER - the race this run exists to test ====='
$acts = @($after | Where-Object { $_.Text.Contains('workgroupActivation') })
Say ('  workgroupActivation lines after the mark : {0}' -f $acts.Count)
if ($acts.Count -eq 0) {
    Say '  -> OUTCOME C: the adapter never replayed the activation snapshot after this start.'
    Say '     Then nothing can be concluded about the mapping, and the subject is on the adapter side.'
} else {
    $firstAct = $acts[0].Time
    $lastAct = $acts[$acts.Count - 1].Time
    Say ('  first activation {0} , last activation {1}' -f $firstAct.ToString('HH:mm:ss.fff'), $lastAct.ToString('HH:mm:ss.fff'))
    if ($firstLoad) {
        if ($firstLoad -lt $firstAct) {
            Say ('  -> the mapping was in memory {0:N3} s BEFORE the first activation. NO RACE.' -f ($firstAct - $firstLoad).TotalSeconds)
            Say '     So activations were evaluated against a loaded mapping, and the answer must be in'
            Say '     the MISS lines below (or in their absence).'
        } else {
            Say ('  -> *** RACE: the first activation arrived {0:N3} s BEFORE the first mapping row.' -f ($firstLoad - $firstAct).TotalSeconds)
            Say '     At that moment UserGroups was still empty, the loop iterated zero times, and neither'
            Say '     Add nor MISS was logged. Users cannot enter the union until the NEXT activation'
            Say '     event - and on a day with no traffic there is none. The mapping is correct and the'
            Say '     grid stays empty anyway. The fix is an ORDER or a re-trigger, not more data.'
        }
    }
}

Say ''
Say '===== 5  refreshUnions after the mark ====='
$adds = @($after | Where-Object { $_.Text.Contains('refreshUnions Add') })
$misses = @($after | Where-Object { $_.Text.Contains('refreshUnions MISS') })
$removes = @($after | Where-Object { $_.Text.Contains('refreshUnions Remove') })
Say ('  Add {0} , MISS {1} , Remove {2}' -f $adds.Count, $misses.Count, $removes.Count)
foreach ($a in @($adds | Select-Object -First 40)) { SayFileOnly ('      + ' + $a.Text.Trim()) }
if ($adds.Count -eq 0 -and $misses.Count -eq 0) {
    Say '  -> OUTCOME B: refreshUnions produced NOTHING after the mark. Either the race in section 4,'
    Say '     or the mapping is not in memory. Section 3 and 4 together say which.'
} elseif ($misses.Count -gt 0) {
    Say '  -> OUTCOME A: the mapping IS in memory and the comparison failed. Details below.'
}
$shown = 0
$distinctNeed = New-Object System.Collections.ArrayList
foreach ($m in $misses) {
    $needMatch = [regex]::Match($m.Text, 'need=\[(.*?)\]')
    $haveMatch = [regex]::Match($m.Text, 'have=\[(.*?)\]')
    if (-not ($needMatch.Success -and $haveMatch.Success)) { continue }
    $needRaw = $needMatch.Groups[1].Value
    if (-not $distinctNeed.Contains($needRaw)) { [void]$distinctNeed.Add($needRaw) }
    if ($shown -ge 25) { continue }
    $shown++
    $need = @($needRaw -split ',' | Where-Object { $_ -ne '' })
    $have = @($haveMatch.Groups[1].Value -split ',' | Where-Object { $_ -ne '' })
    SayFileOnly ''
    SayFileOnly ('  MISS #' + $shown + '  ' + $m.Time.ToString('HH:mm:ss.fff'))
    SayFileOnly ('      ' + $m.Text.Trim())
    $missing = @($need | Where-Object { $have -notcontains $_ })
    SayFileOnly ('      need {0} , have {1} , required-but-absent {2}' -f $need.Count, $have.Count, $missing.Count)
    foreach ($mi in $missing) {
        SayFileOnly ('        needed [' + $mi + ']  len ' + $mi.Length + '  codes ' + (Show-Codes $mi))
        $trimEq = @($have | Where-Object { $_.Trim() -eq $mi.Trim() })
        if ($trimEq.Count -gt 0) {
            SayFileOnly '          *** present after trimming - the difference is WHITESPACE only'
            foreach ($t in $trimEq) { SayFileOnly ('            have [' + $t + ']  len ' + $t.Length + '  codes ' + (Show-Codes $t)) }
        }
        $sameLen = @($have | Where-Object { $_.Length -eq $mi.Length -and $_ -ne $mi })
        foreach ($s in ($sameLen | Select-Object -First 3)) {
            SayFileOnly ('          same length, different bytes [' + $s + ']  codes ' + (Show-Codes $s))
        }
    }
}
Say ('  distinct need-sets among the misses : {0} - see the file' -f $distinctNeed.Count)
foreach ($dn in ($distinctNeed | Select-Object -First 10)) { SayFileOnly ('      need : [' + $dn + ']') }

Say ''
Say '===== 6  did the grid get anything: getUsers / count / PUSH after the mark ====='
foreach ($pair in @(@('RECV userWorkgroupActivation','engine RECEIVED'),
                    @('RECV userConfigurationChanged','engine RECEIVED'),
                    @('getUsers unionId=','grid asked'), @('ChangedUnionUsersData count=','engine answered'),
                    @('PUSH updateUserGrid','engine pushed'), @('not found; returning null','union missing'),
                    @('!union.InUse','union not InUse'), @('A client connected','pipe up'),
                    @('client disconnected','pipe down'))) {
    $hits = @($after | Where-Object { $_.Text.Contains($pair[0]) })
    Say ('  {0,-30} ({1,-16}) : {2}' -f $pair[0], $pair[1], $hits.Count)
    foreach ($h in @($hits | Select-Object -First 12)) {
        Say ('      {0}  | {1}' -f $h.Time.ToString('HH:mm:ss.fff'), $h.Text.Trim().Substring(0, [Math]::Min(150, $h.Text.Trim().Length)))
    }
}

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  banners after mark {0} ; lines after mark {1} ; NEGCTL {2}' -f $banner.Count, $after.Count, $negCtl)
Fin (($negCtl -eq 0) -and ($after.Count -gt 0))
