<#
  PROBE  probe_234_20261014_adapterlog.ps1
  READ-ONLY. The production adapter is NOT ours: nothing is restarted, stopped or reconfigured.
         Its log is opened for reading and nothing else.
  WHY THIS PROBE EXISTS: the adapter half of probe_234_20261014_feedstall.ps1 was NOT MEASURED,
         and the fault was mine. I filtered with Get-ChildItem -LiteralPath -Recurse -Include
         *.log,*.txt, and that combination silently does not filter: the newest file it returned
         was web.config, which has no timestamps, so the section printed NOT MEASURED. The probe
         was right to refuse; the instrument was wrong. Here the extension is filtered with
         Where-Object, and the log path is read out of the machine own log4net.config instead of
         being guessed.
  THE SEARCH WINDOW is the same union as before and is printed before the log is opened: the feed
         stall seen in DATA time 13:01:36 -> 13:43:14 reads either as local 13:01-13:43 (stamps at
         face value) or as local 11:01-11:43 (corrected by the 2 h the feed runs ahead of db_now).
         Searching one hour only would manufacture a false "no trace" from the other.
  EVERY "NO" CARRIES ITS CONTROL: the count of lines whose stamp PARSED is its own positive
         control - a zero there means my parse is wrong, not that the adapter was silent, and
         those are different findings.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$ADAPTER_DIR = 'C:\RTMView\RTM.Twilio'
# MEASURED from the config above, 2026-10-14: the adapter writes OUTSIDE C:\RTMView altogether,
# which is why the first run found zero candidate files under its program folder.
$ADAPTER_LOG_DIR = 'C:\Logs\RTM.Twilio'
$StallFromData = '2026-10-14 13:01:36'
$StallToData   = '2026-10-14 13:43:14'
$MeasuredAheadHours = 2

Start-Probe -Name 'adapterlog' -Title 'READING on 234: the adapter log over the feed-stall window (PR234-FEED-STALL-01)'
Say 'READ-ONLY. The production adapter is not ours - nothing is restarted, stopped or reconfigured.'
Rule
Assert-Machine

function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey|authtoken|accountsid') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}
function Parse-Stamp([string]$line) {
  $match = [regex]::Match("$line", '(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})')
  if ($match.Success) {
    $candidate = $match.Groups[1].Value.Replace('T',' ')
    try { return [datetime]::ParseExact($candidate, 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
  }
  $dotted = [regex]::Match("$line", '(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2})')
  if ($dotted.Success) {
    try { return [datetime]::ParseExact($dotted.Groups[1].Value, 'dd.MM.yyyy HH:mm:ss', $null) } catch { return $null }
  }
  # MEASURED 2026-10-14 from the adapter own log4net ConversionPattern, not guessed:
  # %date{dd/MM/yyyy HH:mm:ss,fff} - slashes, day first. The previous version of this probe knew
  # only the two forms above, so every adapter line would have failed to parse and the section
  # would have said NOT MEASURED a second time, for a second wrong reason.
  $slashed = [regex]::Match("$line", '(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2})')
  if ($slashed.Success) {
    try { return [datetime]::ParseExact($slashed.Groups[1].Value, 'dd/MM/yyyy HH:mm:ss', $null) } catch { return $null }
  }
  return $null
}
function Count-Regex([string[]]$lines, [string]$pattern) {
  $hits = 0
  foreach ($line in $lines) { if ("$line" -match $pattern) { $hits++ } }
  return $hits
}

$stallFrom = [datetime]::ParseExact($StallFromData, 'yyyy-MM-dd HH:mm:ss', $null)
$stallTo   = [datetime]::ParseExact($StallToData,   'yyyy-MM-dd HH:mm:ss', $null)
$searchFrom = $stallFrom.AddHours(-1*$MeasuredAheadHours).AddMinutes(-20)
$searchTo   = $stallTo.AddMinutes(20)
Say '0  THE SEARCH WINDOW, printed before the log is opened'
Say ('  stall in DATA time : ' + $stallFrom.ToString('HH:mm:ss') + ' -> ' + $stallTo.ToString('HH:mm:ss'))
Say ('  reading at face value : local ' + $stallFrom.ToString('HH:mm:ss') + ' -> ' + $stallTo.ToString('HH:mm:ss') + '  = UTC ' + $stallFrom.AddHours(-3).ToString('HH:mm:ss') + 'Z -> ' + $stallTo.AddHours(-3).ToString('HH:mm:ss') + 'Z')
Say ('  reading corrected by ' + $MeasuredAheadHours + ' h : local ' + $stallFrom.AddHours(-1*$MeasuredAheadHours).ToString('HH:mm:ss') + ' -> ' + $stallTo.AddHours(-1*$MeasuredAheadHours).ToString('HH:mm:ss') + '  = UTC ' + $stallFrom.AddHours(-1*$MeasuredAheadHours-3).ToString('HH:mm:ss') + 'Z -> ' + $stallTo.AddHours(-1*$MeasuredAheadHours-3).ToString('HH:mm:ss') + 'Z')
Say ('  SEARCHED (local, the union, widened 20 min each end) : ' + $searchFrom.ToString('yyyy-MM-dd HH:mm:ss') + ' -> ' + $searchTo.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  the same in UTC : ' + $searchFrom.AddHours(-3).ToString('HH:mm:ss') + 'Z -> ' + $searchTo.AddHours(-3).ToString('HH:mm:ss') + 'Z')
Rule

Say '1  WHERE THE ADAPTER WRITES - read out of its own log4net.config, not guessed'
$configPath = Join-Path $ADAPTER_DIR 'log4net.config'
$declaredFiles = @()
if (-not (Test-Path -LiteralPath $configPath)) { Say ('  ' + $configPath + ' NOT FOUND') }
else {
  Say ('  config : ' + $configPath + '    sha256 ' + (ShaOf $configPath))
  $configText = [IO.File]::ReadAllText($configPath)
  # TWO SPELLINGS, because the first run found 0 paths in a config holding 2 appenders - and the
  # positive control said that meant MY READER was wrong, not that the config was empty. It was:
  # log4net writes <param name="File" value="..."/> here, measured 2026-10-14.
  foreach ($fileMatch in [regex]::Matches($configText, '(?i)<file\s+value\s*=\s*"([^"]+)"')) {
    $declaredFiles += $fileMatch.Groups[1].Value
  }
  foreach ($paramMatch in [regex]::Matches($configText, '(?i)<param\s+name\s*=\s*"File"\s+value\s*=\s*"([^"]+)"')) {
    $declaredFiles += $paramMatch.Groups[1].Value
  }
  Say ('  <file value=...> entries declared : ' + $declaredFiles.Count + '   (POSCTL - a zero means my reader is wrong, not that the config is empty)')
  foreach ($declared in $declaredFiles) { Say ('    declared : ' + $declared) }
  $appenderCount = ([regex]::Matches($configText, '(?i)<appender\b')).Count
  Say ('  appenders in the config : ' + $appenderCount)
}
Rule

Say '2  THE CANDIDATE FILES - extension filtered with Where-Object, which actually filters'
Say  '  (-Include together with -Recurse and -LiteralPath silently does not, and that is what'
Say  '   voided the adapter half of the 11:53 run.)'
$candidates = @()
foreach ($searchRoot in @($ADAPTER_LOG_DIR, $ADAPTER_DIR)) {
  if (-not (Test-Path -LiteralPath $searchRoot)) { Say ('  ' + $searchRoot + ' does not exist') ; continue }
  $found = @(Get-ChildItem -LiteralPath $searchRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { ($_.Extension -eq '.log') -or ($_.Extension -eq '.txt') })
  Say ('  .log/.txt files under ' + $searchRoot + ' : ' + $found.Count)
  $candidates += $found
}
$candidates = @($candidates | Sort-Object LastWriteTime -Descending)
Say ('  candidate files in all : ' + $candidates.Count)
$listed = [math]::Min(10, $candidates.Count)
for ($fileIndex = 0; $fileIndex -lt $listed; $fileIndex++) {
  Say ('    ' + $candidates[$fileIndex].FullName + '   ' + $candidates[$fileIndex].Length + ' B   ' + $candidates[$fileIndex].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}
foreach ($declared in $declaredFiles) {
  $resolved = $declared
  if (-not [IO.Path]::IsPathRooted($resolved)) { $resolved = Join-Path $ADAPTER_DIR $resolved }
  $exists = Test-Path -LiteralPath $resolved
  Say ('  declared path on disk : ' + $resolved + '   exists : ' + $exists + $(if ($exists) { '   ' + (Get-Item -LiteralPath $resolved).Length + ' B' } else { '' }))
  if ($exists) {
    $alreadyThere = $false
    foreach ($candidate in $candidates) { if ($candidate.FullName -eq (Get-Item -LiteralPath $resolved).FullName) { $alreadyThere = $true } }
    if (-not $alreadyThere) { $candidates = @(@(Get-Item -LiteralPath $resolved) + $candidates) }
  }
}
Say  '  A declared path that does not exist is itself a finding: the adapter would be writing'
Say  '  nowhere, and no amount of searching would show its lines.'
Rule

Say '3  THE WINDOW, IN EVERY CANDIDATE FILE'
$anyMeasured = $false
$fileLimit = [math]::Min(4, $candidates.Count)
if ($fileLimit -eq 0) { Say '  *** no candidate file at all - the adapter half stays NOT MEASURED, and that is a finding' }
for ($fileIndex = 0; $fileIndex -lt $fileLimit; $fileIndex++) {
  $logFile = $candidates[$fileIndex].FullName
  Say ('  --- ' + $logFile + '   ' + $candidates[$fileIndex].Length + ' B')
  $allLines = @(Get-Content -LiteralPath $logFile -ErrorAction SilentlyContinue -Tail 60000)
  Say ('      lines read (tail 60000) : ' + $allLines.Count)
  $sampleCount = [math]::Min(3, $allLines.Count)
  Say  '      first lines as they are, so the stamp shape my counters rely on is visible:'
  for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) { Say-Guarded ('        | ' + $allLines[$sampleIndex]) }
  $parsed = 0
  $stamps = @()
  $windowLines = @()
  foreach ($line in $allLines) {
    $stamp = Parse-Stamp $line
    if ($null -eq $stamp) { continue }
    $parsed++
    if (($stamp -ge $searchFrom) -and ($stamp -le $searchTo)) { $stamps += $stamp ; $windowLines += "$line" }
  }
  Say ('      lines whose stamp PARSED : ' + $parsed + '   (POSCTL - zero means MY PARSE is wrong, not that the adapter was silent)')
  Say ('      lines inside the window  : ' + $windowLines.Count)
  if ($parsed -eq 0) { Say '      this file states nothing: NOT MEASURED' ; continue }
  $anyMeasured = $true
  if ($windowLines.Count -eq 0) {
    Say ('      NO LINE inside ' + $searchFrom.ToString('HH:mm:ss') + ' -> ' + $searchTo.ToString('HH:mm:ss') + ' local, while ' + $parsed + ' lines elsewhere parsed fine.')
    $sortedAll = @()
    foreach ($line in $allLines) { $stamp = Parse-Stamp $line ; if ($null -ne $stamp) { $sortedAll += $stamp } }
    $sortedAll = @($sortedAll | Sort-Object)
    if ($sortedAll.Count -gt 0) { Say ('      the file spans ' + $sortedAll[0].ToString('yyyy-MM-dd HH:mm:ss') + ' -> ' + $sortedAll[$sortedAll.Count-1].ToString('yyyy-MM-dd HH:mm:ss') + ' - so the window is outside what this file covers') }
    continue
  }
  $sorted = @($stamps | Sort-Object)
  Say ('      first in window : ' + $sorted[0].ToString('yyyy-MM-dd HH:mm:ss') + '    last in window : ' + $sorted[$sorted.Count-1].ToString('yyyy-MM-dd HH:mm:ss'))
  $gaps = @()
  for ($gapIndex = 1; $gapIndex -lt $sorted.Count; $gapIndex++) {
    $seconds = [int](New-TimeSpan -Start $sorted[$gapIndex-1] -End $sorted[$gapIndex]).TotalSeconds
    if ($seconds -gt 0) { $gaps += ,@($seconds, $sorted[$gapIndex-1], $sorted[$gapIndex]) }
  }
  $ranked = @($gaps | Sort-Object { -1 * $_[0] })
  $topCount = [math]::Min(5, $ranked.Count)
  Say  '      the largest gaps between consecutive stamps - a silent adapter leaves one:'
  if ($topCount -eq 0) { Say '        no measurable gap' }
  for ($rankIndex = 0; $rankIndex -lt $topCount; $rankIndex++) {
    Say ('        gap ' + ([string]$ranked[$rankIndex][0]).PadLeft(6) + ' s   from ' + $ranked[$rankIndex][1].ToString('HH:mm:ss') + ' to ' + $ranked[$rankIndex][2].ToString('HH:mm:ss'))
  }
  Say ('      lines naming an error     : ' + (Count-Regex $windowLines '(?i)\bERROR\b|\[ERR\]|\bFATAL\b|\bexception\b'))
  Say ('      lines naming a reconnect  : ' + (Count-Regex $windowLines '(?i)reconnect|re-connect|connection lost|disconnect|closed|retry|resubscrib|unauthor'))
  Say ('      lines naming the source   : ' + (Count-Regex $windowLines '(?i)twilio|signalr|websocket|subscri|stream'))
  $negNeedle = Count-Regex $windowLines 'ZzzNoSuchLogLineCouldEverExist'
  Say ('      NEGCTL a needle that cannot be there : ' + $negNeedle + '   (must be 0)')
  $interesting = @()
  foreach ($line in $windowLines) { if ("$line" -match '(?i)\bERROR\b|\[ERR\]|\bFATAL\b|\bexception\b|reconnect|connection lost|disconnect|retry|unauthor') { $interesting += "$line" } }
  $showCount = [math]::Min(20, $interesting.Count)
  if ($showCount -gt 0) { Say '      the lines themselves, up to twenty:' }
  for ($showIndex = 0; $showIndex -lt $showCount; $showIndex++) { Say-Guarded ('        | ' + $interesting[$showIndex]) }
  if ($interesting.Count -gt $showCount) { Say ('        ... and ' + ($interesting.Count - $showCount) + ' more') }
  Write-Report
}
Rule

Say 'WHAT THIS READING SAYS'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  at least one adapter file measured : ' + $anyMeasured)
Say ('  window searched (local) : ' + $searchFrom.ToString('HH:mm:ss') + ' -> ' + $searchTo.ToString('HH:mm:ss') + '   - any "no trace" above means ONLY inside this window and ONLY in these files')
Say  '  Nothing was restarted, stopped or reconfigured. Naming the cause of the stall is the'
Say  '  coordinator call, not mine.'
Say '===== END-OF-RUN MARKER: ADAPTERLOG-COMPLETE ====='
Finish $anyMeasured
