<#
  PROBE  probe_234_20261014_adapterhist.ps1
  READ-ONLY. The production adapter is NOT ours - its log files are opened for reading, nothing else.
  THE QUESTION: between 11:01 and 11:43 local the newest interaction row in the database did not
         move. Did the ADAPTER stop receiving, or did it keep receiving while the rows stopped
         arriving downstream? Those are different defects with different owners.
  THE INSTRUMENT IS A PER-MINUTE HISTOGRAM, not a search for the word "reconnect". A minute with
         zero lines, surrounded by minutes with hundreds, IS the hole. A window with no empty
         minute at all says the adapter never stopped, and then the break lies further along -
         between the engine and the database - which is not the adapter owner problem.
  ALREADY MEASURED WITHOUT READING A LINE, from the roll times: the adapter rolled a 5 MB file
         every 5-8 minutes right through the window (10:41, 10:46, 10:51, 11:00, 11:06, 11:10,
         11:15, 11:20, 11:27, 11:32, 11:38, 11:45). A silent adapter does not write 5 MB in five
         minutes. The histogram below either confirms that or contradicts it; both are useful.
  THE FILES ARE NAMED, NOT GLOBBED BY EXTENSION. Three times today an extension filter voided a
         section: the rolled files are log.txt.1 ... log.txt.100, whose extension is ".1", not
         ".txt". Here the twelve files that cover the window are listed explicitly and each one is
         checked for existence before it is read.
  THE STAMP FORM comes from the adapter own ConversionPattern, measured: dd/MM/yyyy HH:mm:ss,fff.
         The count of lines whose stamp parsed is the positive control for every number below.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$LOG_DIR = 'C:\Logs\RTM.Twilio'
$FileNames = @('log.txt.19','log.txt.18','log.txt.17','log.txt.16','log.txt.15','log.txt.14','log.txt.13','log.txt.12','log.txt.11','log.txt.10','log.txt.9','log.txt.8')
$HistogramFromText = '2026-10-14 10:30'
$HistogramToText   = '2026-10-14 11:50'

Start-Probe -Name 'adapterhist' -Title 'READING on 234: did the adapter stop? a per-minute histogram over the stall window'
Say 'READ-ONLY. The production adapter is not ours - nothing is restarted, stopped or reconfigured.'
Rule
Assert-Machine

function Stamp-OfLine([string]$line) {
  $trimmed = "$line".TrimStart()
  if ($trimmed.Length -lt 19) { return $null }
  $candidate = $trimmed.Substring(0, 19)
  try { return [datetime]::ParseExact($candidate, 'dd/MM/yyyy HH:mm:ss', $null) } catch { return $null }
}

$windowStart = [datetime]::ParseExact($HistogramFromText, 'yyyy-MM-dd HH:mm', $null)
$windowEnd   = [datetime]::ParseExact($HistogramToText,   'yyyy-MM-dd HH:mm', $null)
Say '0  WHAT IS COUNTED, WRITTEN DOWN BEFORE THE FIRST FILE IS OPENED'
Say ('  histogram from ' + $windowStart.ToString('HH:mm') + ' to ' + $windowEnd.ToString('HH:mm') + ' local, one bucket per minute')
Say  '  the stall, in local time, is 11:01:36 -> 11:43:14 (data time 13:01:36 -> 13:43:14 minus the'
Say  '  measured 2 h the feed runs ahead of db_now). So the buckets that matter are 11:01 to 11:43,'
Say  '  with 10:30-11:00 and 11:44-11:50 as the healthy shoulders to compare against.'
Say  '  EXPECTED, both shapes named in advance:'
Say  '    a run of EMPTY minutes inside 11:01-11:43 -> the adapter stopped receiving'
Say  '    no empty minute at all                    -> the adapter kept receiving, and the break'
Say  '                                                 is downstream of it, not in it'
Rule

Say '1  THE FILES, NAMED EXPLICITLY - no extension glob, because the rolled ones end in .1 .. .100'
$presentFiles = @()
foreach ($fileName in $FileNames) {
  $fullPath = Join-Path $LOG_DIR $fileName
  $exists = Test-Path -LiteralPath $fullPath
  $sizeText = 'absent'
  if ($exists) { $sizeText = ([string](Get-Item -LiteralPath $fullPath).Length + ' B') ; $presentFiles += $fullPath }
  Say ('  ' + $fileName.PadRight(12) + ' ' + $sizeText)
}
Say ('  files present : ' + $presentFiles.Count + ' of ' + $FileNames.Count + '   (POSCTL - a zero voids everything below)')
if ($presentFiles.Count -eq 0) { Say '  *** nothing to read - NOT MEASURED' ; Finish $false }
Rule

Say '2  STREAMING THEM - one pass, counting per minute'
$buckets = @{}
$errorBuckets = @{}
$reconnectBuckets = @{}
$totalLines = 0
$parsedLines = 0
$inWindow = 0
$errorSamples = @()
$reconnectSamples = @()
foreach ($fullPath in $presentFiles) {
  $fileLines = 0
  $fileParsed = 0
  foreach ($line in [IO.File]::ReadLines($fullPath)) {
    $fileLines++
    $stamp = Stamp-OfLine $line
    if ($null -eq $stamp) { continue }
    $fileParsed++
    if (($stamp -lt $windowStart) -or ($stamp -gt $windowEnd)) { continue }
    $inWindow++
    $key = $stamp.ToString('HH:mm')
    if (-not $buckets.ContainsKey($key)) { $buckets[$key] = 0 ; $errorBuckets[$key] = 0 ; $reconnectBuckets[$key] = 0 }
    $buckets[$key] = $buckets[$key] + 1
    if ("$line" -match '(?i)\bERROR\b|\bFATAL\b|\bexception\b') {
      $errorBuckets[$key] = $errorBuckets[$key] + 1
      if ($errorSamples.Count -lt 20) { $errorSamples += "$line" }
    }
    if ("$line" -match '(?i)reconnect|connection lost|disconnect|unauthor|retry|resubscrib|socket') {
      $reconnectBuckets[$key] = $reconnectBuckets[$key] + 1
      if ($reconnectSamples.Count -lt 20) { $reconnectSamples += "$line" }
    }
  }
  $totalLines = $totalLines + $fileLines
  $parsedLines = $parsedLines + $fileParsed
  Say ('  ' + (Split-Path -Leaf $fullPath).PadRight(12) + ' lines ' + ([string]$fileLines).PadLeft(8) + '   stamped ' + ([string]$fileParsed).PadLeft(8))
  Write-Report
}
Say ('  TOTAL lines read : ' + $totalLines)
Say ('  of them stamped  : ' + $parsedLines + '   (POSCTL - a zero means MY PARSE is wrong, not that the adapter was silent)')
Say ('  inside the histogram window : ' + $inWindow)
Rule

Say '3  THE HISTOGRAM, ONE LINE PER MINUTE - the hole, if there is one, is visible as a zero'
$emptyMinutes = @()
$minuteCursor = $windowStart
while ($minuteCursor -le $windowEnd) {
  $key = $minuteCursor.ToString('HH:mm')
  $count = 0
  $errors = 0
  $reconnects = 0
  if ($buckets.ContainsKey($key)) { $count = $buckets[$key] ; $errors = $errorBuckets[$key] ; $reconnects = $reconnectBuckets[$key] }
  $barLength = [math]::Min(60, [int]($count / 20))
  $bar = ''
  if ($barLength -gt 0) { $bar = '#' * $barLength }
  $marker = '   '
  if (($minuteCursor -ge ([datetime]::ParseExact('2026-10-14 11:01','yyyy-MM-dd HH:mm',$null))) -and ($minuteCursor -le ([datetime]::ParseExact('2026-10-14 11:43','yyyy-MM-dd HH:mm',$null)))) { $marker = ' * ' }
  if ($count -eq 0) { $emptyMinutes += $key }
  Say ('  ' + $key + $marker + ([string]$count).PadLeft(6) + '  err ' + ([string]$errors).PadLeft(4) + '  rec ' + ([string]$reconnects).PadLeft(4) + '  ' + $bar)
  $minuteCursor = $minuteCursor.AddMinutes(1)
}
Say ('  minutes marked * are inside the stall; minutes with zero lines : ' + $emptyMinutes.Count)
if ($emptyMinutes.Count -gt 0) { Say ('    they are : ' + ($emptyMinutes -join ' ')) }
Write-Report
Rule

Say '4  THE ERROR AND RECONNECT LINES THEMSELVES, up to twenty of each'
Say ('  error-ish lines sampled    : ' + $errorSamples.Count)
foreach ($sample in $errorSamples) { Say ('    | ' + $sample) }
Say ('  reconnect-ish lines sampled : ' + $reconnectSamples.Count)
foreach ($sample in $reconnectSamples) { Say ('    | ' + $sample) }
$negNeedle = 0
foreach ($sample in @($errorSamples + $reconnectSamples)) { if ("$sample".Contains('ZzzNoSuchLogLineCouldEverExist')) { $negNeedle++ } }
Say ('  NEGCTL a needle that cannot be there : ' + $negNeedle + '   (must be 0)')
Rule

Say 'WHAT THIS READING SAYS'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  lines read / stamped / in window : ' + $totalLines + ' / ' + $parsedLines + ' / ' + $inWindow)
Say ('  empty minutes in 10:30-11:50 : ' + $emptyMinutes.Count)
Say  '  If that count is zero, the adapter received traffic through the whole stall, and the place'
Say  '  where the rows stopped arriving is downstream of it. Naming the owner is the coordinator'
Say  '  call. Nothing was restarted, stopped or reconfigured by this run.'
Say '===== END-OF-RUN MARKER: ADAPTERHIST-COMPLETE ====='
Finish ($parsedLines -gt 0)
