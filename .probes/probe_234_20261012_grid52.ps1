<#
  PROBE  probe_234_20261012_grid52.ps1
  SHAPE  the database half of probe_234_20261012_rendergap.ps1, rebuilt after two defects of mine.
  UNIT   grid 52 cell types. The widget loaded 12 cells; the shell expects Data 6 / Text 6.
  DEFECT ONE, FIXED HERE: the query went through psql -c from PowerShell and the double quotes
         around the identifiers were eaten on the way, so Postgres saw RTSGrid_Cell unquoted,
         folded it to lower case and answered 'relation "rtsgrid_cell" does not exist'. The query
         now travels in a FILE, written as UTF-8 without BOM, and psql reads it with -f. The file
         is printed back from disk before it runs, so what Postgres gets is what the report shows.
  DEFECT TWO, FIXED HERE: my row counter counted any non-empty output line, so three lines of an
         ERROR message counted as three rows - and the negative control printed 3 where it had to
         print 0, which made a broken reader look like a working one. Rows are now only lines that
         carry the field separator, and an ERROR anywhere in the output invalidates the section
         explicitly instead of being counted.
  SECRETS: the password is read with -AsSecureString, never printed, never written to the report;
         only the user name, the port and the password's length appear.
  WHERE  SERVER 234, READ ONLY. Three SELECTs, no write, no service touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_grid52.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
$script:TrapFired = $false
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 20) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  $script:TrapFired = $true
  [void]$ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED: ' + $_.Exception.Message)
  Write-Report
  continue
}

Say ("GRID 52 CELL TYPES  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Three SELECTs. No write, no service touched."
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

$psql = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
Say ("psql : " + $psql + "   present : " + (Test-Path -LiteralPath $psql))
if (-not (Test-Path -LiteralPath $psql)) { Say "  *** psql not at that path - nothing measured, no other path guessed" ; Finish $false }
$dbUser = 'ccdashboard_user'
$dbPort = 5433
$dbName = 'rtmviewdb'
Say ("host 127.0.0.1   port " + $dbPort + "   database " + $dbName + "   user " + $dbUser)
$securePassword = Read-Host -Prompt ('Password for ' + $dbUser + '@127.0.0.1:' + $dbPort + '/' + $dbName) -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
Say ("password supplied, " + $plainPassword.Length + " characters (NOT printed, NOT in this report)")
Rule

# Every query travels as a FILE, and the file is read back from disk into the report before it runs.
function Invoke-Select([string]$label, [string]$sql) {
  $sqlPath = Join-Path $env:TEMP ('grid52_' + [Guid]::NewGuid().ToString('N') + '.sql')
  [IO.File]::WriteAllText($sqlPath, $sql, (New-Object System.Text.UTF8Encoding($false)))
  Say ("  " + $label)
  Say ("  the file psql will read, printed back from disk:")
  foreach ($line in @(Get-Content -LiteralPath $sqlPath)) { Say ("    > " + $line) }
  $output = @(& $psql -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -A -F '|' -t -v ON_ERROR_STOP=1 -f $sqlPath 2>&1)
  Remove-Item -LiteralPath $sqlPath -Force -ErrorAction SilentlyContinue
  $hadError = @($output | Where-Object { "$_" -match '(?i)^ERROR|^psql:|FATAL' }).Count -gt 0
  # A data row is a non-empty line that is not part of an error message. NOT "a line containing
  # the separator": a single-column result has no separator at all, which made my own POSCTL count
  # zero rows for the answer 509 and declare the reader untrusted. Measured 2026-10-12 18:39.
  $dataRows = @($output | Where-Object { "$_".Trim() -ne '' -and "$_" -notmatch '(?i)^ERROR|^psql:|FATAL|^LINE \d|^\s*\^\s*$' })
  foreach ($line in $output) { if ("$line".Trim() -ne '') { Say ("    | " + $line) } }
  Say ("    error in output : " + $hadError + "   data rows (non-empty, not part of an error) : " + $dataRows.Count)
  return [pscustomobject]@{ HadError = $hadError ; Rows = $dataRows }
}

$env:PGPASSWORD = $plainPassword

Say "1  POSCTL - does the connection work and does the table exist at all"
Say  "  A failure here invalidates everything below, and says so rather than producing a zero."
$posctl = Invoke-Select 'bare count over the cell table' 'SELECT count(*) AS cells FROM "RTSGrid_Cell";'
Rule

Say "2  THE QUESTION - cell types of grid 52"
Say  "  EXPECTED BEFORE THE MEASUREMENT, from the shell: Data 6 / Text 6, accounting for the 12"
Say  "  cells the widget loaded this morning. Any other split is the finding, printed as it is."
$answer = Invoke-Select 'cell types for GridId 52' 'SELECT c."CellType", count(*) FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId" WHERE r."GridId" = 52 GROUP BY 1 ORDER BY 1;'
Rule

Say "3  NEGCTL - the same query for a grid that cannot exist"
Say  "  It must return NO data row. Two defects of mine were corrected to make this control real:"
Say  "  first the counter took three lines of an ERROR message for three rows, then it took only"
Say  "  lines with a separator, which missed single-column answers. A row is now any non-empty line"
Say  "  that is not part of an error message."
$negctl = Invoke-Select 'cell types for GridId -1' 'SELECT c."CellType", count(*) FROM "RTSGrid_Cell" c JOIN "RTSGrid_Row" r ON r."RowId" = c."RowId" WHERE r."GridId" = -1 GROUP BY 1 ORDER BY 1;'
$env:PGPASSWORD = ''
$plainPassword = $null
Rule

Say "VERDICT OF THE READING"
$readerOk = ((-not $posctl.HadError) -and ($posctl.Rows.Count -ge 1) -and (-not $negctl.HadError) -and ($negctl.Rows.Count -eq 0))
Say ("  POSCTL answered without error      : " + (-not $posctl.HadError))
Say ("  NEGCTL returned no data row        : " + ($negctl.Rows.Count -eq 0))
Say ("  the question answered without error: " + (-not $answer.HadError))
Say ("  READER : " + $(if ($readerOk) { 'TRUSTED - the rows in section 2 are the answer' } else { 'NOT TRUSTED - section 2 is not an answer, whatever it printed' }))
Say ("  a section was skipped by an error  : " + $script:TrapFired)
Say  "  No verdict on the widget is offered here. This run hands over what the table says."
Say "===== END-OF-RUN MARKER: GRID52-COMPLETE ====="
Finish ($readerOk -and (-not $script:TrapFired))
