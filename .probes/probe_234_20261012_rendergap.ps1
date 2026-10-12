<#
  PROBE  probe_234_20261012_rendergap.ps1
  SHAPE  FROM probe_234_20261012_daytrendfail.ps1 - same two-file reading, new question.
  UNIT   PR234-V4-DAYTREND-RENDER-FAIL-01, second reading. The same TaskCanceledException has two
         causes with different prices: the Blazor interop timeout (60 s by default - the JS call
         went out and never came back, which is a defect) or a circuit that was disconnected or a
         component disposed (the tab was closed or reloaded, which is logging noise). The gap
         between the call and the failure separates them.
  WHAT I CANNOT DO AND SAY SO INSTEAD OF FAKING IT: the ERR line carries NO chartId - measured in
         the previous reading, 0 ids on 69 lines. So "the nearest Calling JS with THE SAME chartId"
         is not available, and this probe takes the nearest preceding Calling JS with line of any
         chart, marking each row as matched by TIME ONLY. A number that looks exact but is built
         from arbitrary pairs would be worse than a number that says what it is.
  THE DISCONNECT WORDS ARE LISTED BEFORE THEY ARE COUNTED. The coordinator named four candidates;
         what the log actually writes may be none of them. Section 2 first prints every distinct
         kind of line found near the failures, then counts - counting words the log does not write
         would produce a confident zero.
  THE BACKGROUND IS THE NEGATIVE HALF: the same +-10 s search around 69 'JS render completed'
         lines. Without it, "disconnect lines near failures" has nothing to be compared against.
  SECRETS: the database password is read with -AsSecureString, never printed and never written to
         the report; only the user name and the port appear. The query is a single SELECT.
  WHERE  SERVER 234, READ ONLY. No service touched, no log level changed, no write to the database.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_rendergap.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
$script:TrapFired = $false
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 25) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  $script:TrapFired = $true
  [void]$ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED, not failed:')
  [void]$ReportLines.Add('    message : ' + $_.Exception.Message)
  [void]$ReportLines.Add('    at line : ' + $_.InvocationInfo.ScriptLineNumber)
  Write-Report
  continue
}
function Stamp-Of([string]$line) {
  $stampMatch = [regex]::Match($line, '^\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2})')
  if (-not $stampMatch.Success) { return $null }
  [datetimeoffset]$parsed = [datetimeoffset]::MinValue
  if ([datetimeoffset]::TryParse($stampMatch.Groups[1].Value, [ref]$parsed)) { return $parsed }
  return $null
}

Say ("RENDER GAP AND CIRCUIT LINES  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY. No service touched, no log level changed, no write to the database."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say "  G0 PASS"
Rule

Say  "EVERY SECTION BELOW PRINTS ITS PROGRESS. A probe that only prints when it finishes cannot be"
Say  "told apart from one that has hung, and on 2026-10-12 mine could not be - the operator waited."
Rule
Say "1  LOADING THE TWO FILES, with their line counts named"
$logDir = 'C:\Logs\RTMViewShell'
$records = New-Object System.Collections.ArrayList
foreach ($day in @('20261011','20261012')) {
  $path = Join-Path $logDir ('log-' + $day + '.txt')
  if (-not (Test-Path -LiteralPath $path)) { Say ("  log-" + $day + ".txt : ABSENT") ; continue }
  $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
  Say ("  log-" + $day + ".txt : " + $lines.Count + " lines")
  for ($index = 0; $index -lt $lines.Count; $index++) {
    [void]$records.Add([pscustomobject]@{ Day = $day ; Index = $index ; Line = ("" + $lines[$index]) })
  }
}
Say ("  lines held for this reading : " + $records.Count)
if ($records.Count -eq 0) { Say "  *** nothing to read" ; Finish $false }
$FromUtc = [datetimeoffset]::Parse('2026-10-11T09:30:00Z')
$ToUtc   = [datetimeoffset]::UtcNow
$stamped = New-Object System.Collections.ArrayList
foreach ($record in $records) {
  $stamp = Stamp-Of $record.Line
  if ($null -eq $stamp) { continue }
  [void]$stamped.Add([pscustomobject]@{ Day = $record.Day ; Index = $record.Index ; Line = $record.Line ; Stamp = $stamp })
}
Say ("  of those, lines with a parsable stamp : " + $stamped.Count)
$failures = @($stamped | Where-Object { $_.Line -like '*JS render failed*' -and $_.Stamp -ge $FromUtc -and $_.Stamp -le $ToUtc })
$calls    = @($stamped | Where-Object { $_.Line -like '*Calling JS with*' })
$completed = @($stamped | Where-Object { $_.Line -like '*JS render completed*' })
Say ("  failures in the window : " + $failures.Count + "   'Calling JS with' lines : " + $calls.Count + "   'JS render completed' : " + $completed.Count)
if ($failures.Count -eq 0) { Say "  *** no failure in the window - that contradicts the previous reading, so this run is not trusted" ; Finish $false }
Rule

Say "2  THE GAP BETWEEN THE CALL AND THE FAILURE"
Say  "  EXPECTED BEFORE THE MEASUREMENT: if this is the interop timeout, the gaps cluster near 60 s"
Say  "  (the Blazor default). If it is a disconnected circuit, they are scattered and mostly short."
Say  "  MATCHED BY TIME ONLY: the ERR line carries no chartId, so the pair is 'the nearest preceding"
Say  "  Calling JS with line', whatever chart it belonged to. Each row says so."
$buckets = [ordered]@{ 'under 5 s' = 0 ; '5 - 55 s' = 0 ; '55 - 65 s' = 0 ; 'over 65 s' = 0 ; 'no preceding call' = 0 }
$gapList = New-Object System.Collections.ArrayList
$callsSorted = @($calls | Sort-Object Stamp)
$progress = 0
foreach ($failure in $failures) {
  $progress++
  if (($progress % 20) -eq 0) { Write-Host ("    ... " + $progress + " of " + $failures.Count + " gaps measured") }
  $previous = @($callsSorted | Where-Object { $_.Stamp -le $failure.Stamp } | Select-Object -Last 1)
  if ($previous.Count -eq 0) { $buckets['no preceding call'] = $buckets['no preceding call'] + 1 ; continue }
  $gapMs = ($failure.Stamp - $previous[0].Stamp).TotalMilliseconds
  [void]$gapList.Add($gapMs)
  if ($gapMs -lt 5000) { $buckets['under 5 s'] = $buckets['under 5 s'] + 1 }
  elseif ($gapMs -lt 55000) { $buckets['5 - 55 s'] = $buckets['5 - 55 s'] + 1 }
  elseif ($gapMs -le 65000) { $buckets['55 - 65 s'] = $buckets['55 - 65 s'] + 1 }
  else { $buckets['over 65 s'] = $buckets['over 65 s'] + 1 }
}
foreach ($key in $buckets.Keys) { Say ("    " + ([string]$key).PadRight(20) + $buckets[$key]) }
if ($gapList.Count -gt 0) {
  $sorted = @($gapList | Sort-Object)
  Say ("  gaps measured : " + $sorted.Count + "   min " + [math]::Round($sorted[0]) + " ms   median " + [math]::Round($sorted[[int]([math]::Floor($sorted.Count / 2))]) + " ms   max " + [math]::Round($sorted[$sorted.Count - 1]) + " ms")
}
Say  "  NEGCTL of this pairing: the same search for a call AFTER each failure must also find"
Say  "  something, or the reader is only ever seeing one side of the log."
$forwardFound = 0
foreach ($failure in $failures) {
  $next = @($callsSorted | Where-Object { $_.Stamp -gt $failure.Stamp } | Select-Object -First 1)
  if ($next.Count -gt 0) { $forwardFound++ }
}
Say ("  failures with a call after them : " + $forwardFound + "   (a control on the reader, not a finding)")
Rule

Say "3  CIRCUIT AND DISPOSAL LINES NEAR THE FAILURES - the kinds FIRST, the counts after"
Say  "  The coordinator named Circuit / disconnect / Dispose / Terminated as candidates. What the"
Say  "  log actually writes may be none of them, so every distinct kind found within +-10 s of a"
Say  "  failure is printed before anything is counted. Counting words the log never writes would"
Say  "  produce a confident zero and send everyone the wrong way."
$pattern = '(?i)circuit|disconnect|dispose|terminated|OnConnectionDown|client closed'
Say  "  HOW THIS IS COUNTED, and it is a correction of my own first attempt: the candidate lines are"
Say  "  selected ONCE by the pattern, and only that short list is compared against the failures."
Say  "  My first version walked all 157k lines for each of the 69 failures - twenty million string"
Say  "  comparisons, tens of minutes, with no sign of life printed. The operator had to interrupt it."
$candidates = @($stamped | Where-Object { $_.Line -match $pattern })
Say ("  candidate lines in the whole window : " + $candidates.Count + "   (a zero here is itself the answer to section 3)")
$kinds = @{}
$withNearby = 0
$progress = 0
foreach ($failure in $failures) {
  $progress++
  if (($progress % 10) -eq 0) { Write-Host ("    ... " + $progress + " of " + $failures.Count + " failures examined") }
  $near = @($candidates | Where-Object { [math]::Abs(($_.Stamp - $failure.Stamp).TotalSeconds) -le 10 })
  if ($near.Count -gt 0) { $withNearby++ }
  foreach ($nearLine in $near) {
    $shape = [regex]::Replace($nearLine.Line, '^\s*\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2}\s*', '')
    $shape = [regex]::Replace($shape, '[0-9a-f]{8,}', '<id>')
    $shape = [regex]::Replace($shape, '\d+', '<n>')
    if ($shape.Length -gt 110) { $shape = $shape.Substring(0, 110) }
    if (-not $kinds.ContainsKey($shape)) { $kinds[$shape] = 0 }
    $kinds[$shape] = $kinds[$shape] + 1
  }
}
Say ("  distinct kinds of such line found near failures : " + $kinds.Count)
foreach ($key in ($kinds.Keys | Sort-Object)) { Say ("    [" + $kinds[$key] + "] " + $key) }
if ($kinds.Count -eq 0) { Say "  NONE. The log writes no circuit, disconnect, dispose or termination line near any failure." }
Say ("  failures WITH such a line within 10 s : " + $withNearby)
Say ("  failures WITHOUT one                  : " + ($failures.Count - $withNearby))
Say ""
Say  "  THE BACKGROUND, which is what makes the two numbers above mean anything: the same search"
Say  "  around the same number of SUCCESSFUL renders. If the rate is the same, proximity says"
Say  "  nothing about the failures."
$sampleCompleted = @($completed | Get-Random -Count ([math]::Min($failures.Count, $completed.Count)) -ErrorAction SilentlyContinue)
$backgroundWith = 0
$progress = 0
foreach ($sample in $sampleCompleted) {
  $progress++
  if (($progress % 20) -eq 0) { Write-Host ("    ... " + $progress + " of " + $sampleCompleted.Count + " successful renders examined") }
  $near = @($candidates | Where-Object { [math]::Abs(($_.Stamp - $sample.Stamp).TotalSeconds) -le 10 })
  if ($near.Count -gt 0) { $backgroundWith++ }
}
Say ("  successful renders sampled : " + $sampleCompleted.Count + "   of them with such a line within 10 s : " + $backgroundWith)
Rule

Say "4  THE GRID 52 CELL TYPES - a single SELECT, read only"
Say  "  EXPECTED BEFORE THE MEASUREMENT, from the shell: Data 6 / Text 6. The widget loaded 12"
Say  "  cells this morning, so 6+6 would account for all twelve."
Say  "  The password is read with -AsSecureString and never printed; only the user and the port are."
$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
Say ("  psql : " + $psql + "   present : " + (Test-Path -LiteralPath $psql))
if (-not (Test-Path -LiteralPath $psql)) { Say "  *** psql not at that path - section not measured, and no other path is guessed" }
else {
  $dbUser = 'ccdashboard_user'
  $dbPort = 5433
  $dbName = 'rtmviewdb'
  Say ("  host 127.0.0.1   port " + $dbPort + "   database " + $dbName + "   user " + $dbUser)
  $securePassword = Read-Host -Prompt ('Password for ' + $dbUser + '@127.0.0.1:' + $dbPort + '/' + $dbName) -AsSecureString
  $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
  Say ("  password supplied, " + $plainPassword.Length + " characters (NOT printed, NOT in this report)")
  $query = 'SELECT c."CellType", count(*) FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."GridId"=52 GROUP BY 1 ORDER BY 1'
  Say ("  query : " + $query)
  $env:PGPASSWORD = $plainPassword
  $output = & $psql -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -A -F '|' -t -c $query 2>&1
  foreach ($line in @($output)) { Say ("  | " + $line) }
  $rowsReturned = @(@($output) | Where-Object { "$_".Trim() -ne '' }).Count
  Say ("  rows returned : " + $rowsReturned)
  Say  "  NEGCTL, run here and now with the same credentials: a grid id that cannot exist."
  $negQuery = 'SELECT c."CellType", count(*) FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId"=c."RowId" WHERE r."GridId"=-1 GROUP BY 1'
  $negOutput = & $psql -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -A -F '|' -t -c $negQuery 2>&1
  $negRows = @(@($negOutput) | Where-Object { "$_".Trim() -ne '' }).Count
  Say ("  rows for GridId -1 : " + $negRows + "   must be 0; anything else means this reader answers the same for any grid")
  foreach ($line in @($negOutput)) { if ("$line".Trim() -ne '') { Say ("  | " + $line) } }
  Say  "  POSCTL that the connection itself works and the table is the one we think: a bare count."
  $posOutput = & $psql -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -A -F '|' -t -c 'SELECT count(*) FROM "RTSGrid_Cell"' 2>&1
  foreach ($line in @($posOutput)) { if ("$line".Trim() -ne '') { Say ("  cells in RTSGrid_Cell altogether : " + "$line".Trim() + "   a zero or an error here invalidates section 4") } }
  $env:PGPASSWORD = ''
  $plainPassword = $null
}
Rule

Say "VERDICT OF THE READING"
Say  "  the gap histogram      : see section 2"
Say  "  circuit lines and their background : see section 3"
Say  "  grid 52 cell types     : see section 4"
Say ("  a section was skipped by an error  : " + $script:TrapFired)
Say  "  No verdict on the cause is offered here. This run hands over what the log and the table say."
Say "===== END-OF-RUN MARKER: RENDERGAP-COMPLETE ====="
Finish (-not $script:TrapFired)
