<#
  _core.ps1 - the common half of every probe, in ONE file.
  WHY IT EXISTS. Until 2026-10-12 this code was carried from probe to probe by editing the previous
  one, and it is where every instrument defect of 11-12.10 lived: a helper called and never defined
  (printed "needle absent" having measured nothing), the same helper defined BELOW its first call,
  an unclosed parenthesis, a quadratic loop with no sign of life, a row counter that was wrong in
  both directions. The operator paid for three of those in run-boxes. Carried code breaks; one file
  that every probe dot-sources is fixed once and proven once.
  HOW A PROBE USES IT
      . (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')
      Start-Probe -Name 'acceptance-2d75b01'      # opens the report, prints the header
      Assert-Machine                              # the 234 gate; refuses anywhere else
      Say / Rule / ShaOf / Find-ByteRun / ...     # all available, all self-tested below
      Finish $verdict
  EVERY HELPER HERE IS SELF-TESTED BY Start-Probe BEFORE A PROBE MEASURES ANYTHING, and the test
  prints its own expected values. A helper that cannot pass its own test stops the run.
#>

$script:ReportLines = New-Object System.Collections.ArrayList
$script:ReportPath = $null
$script:SayCount = 0
$script:TrapFired = $false

function Write-Report() {
  if ($null -eq $script:ReportPath) { return }
  [IO.File]::WriteAllLines($script:ReportPath, $script:ReportLines, (New-Object System.Text.UTF8Encoding($false)))
}
function Say($text) {
  [void]$script:ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 20) -eq 0) { Write-Report }
}
function Rule() {
  # FLUSH ON EVERY RULE, added 2026-10-14. A probe that dies mid-section used to lose every line it
  # had printed since the last explicit Write-Report: the tzgate run left 20 lines and no cause.
  # Rule ends every section, so flushing here makes the report survive any crash, at the price of
  # one small write per section.
  Say ('-' * 78)
  Write-Report
}
function Finish($passed) {
  Write-Report
  Write-Host ''
  Write-Host ('REPORT: ' + $script:ReportPath)
  if ($passed) { exit 0 } else { exit 1 }
}
function Note-Trap($record) {
  $script:TrapFired = $true
  [void]$script:ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED, not failed:')
  [void]$script:ReportLines.Add('    message : ' + $record.Exception.Message)
  [void]$script:ReportLines.Add('    at line : ' + $record.InvocationInfo.ScriptLineNumber)
  Write-Report
}
function Test-TrapFired() { return $script:TrapFired }

# READING A FILE A SERVICE HOLDS OPEN. Added 2026-10-14 after [IO.File]::ReadLines died on
# C:\Logs\RTMViewShell\log-20261014.txt: it opens with FileShare.Read, and a writer that holds the
# file with FileShare.ReadWrite refuses that. Every log on this machine is held open by its writer,
# so this is the only lawful way to read one here. Returns a StreamReader the caller disposes.
function Open-SharedReader([string]$path) {
  $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
  return (New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8))
}
function Read-SharedLines([string]$path) {
  # @() and not ,@() - same reason as the return below: the comma would make an absent file look
  # like a one-line file, measured 2026-10-14 by the self-test of this very helper.
  if (-not (Test-Path -LiteralPath $path)) { return @() }
  $reader = Open-SharedReader $path
  $lines = New-Object 'System.Collections.Generic.List[string]'
  try {
    while ($true) {
      $line = $reader.ReadLine()
      if ($null -eq $line) { break }
      $lines.Add($line)
    }
  } finally { $reader.Dispose() }
  # NO LEADING COMMA HERE. The comma is load-bearing when returning @(...) that may hold ONE item,
  # because PowerShell unrolls a one-element array on the way out. A List.ToArray() is already an
  # array, so the comma would wrap it in a one-element array instead: measured 2026-10-14, the
  # caller got 1 line for a 3-line file. Callers wrap the result in @() as usual.
  return $lines.ToArray()
}
function ShaOf($path) {
  if (Test-Path -LiteralPath $path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
  return 'ABSENT'
}
function Get-Sha256Of($path) { return (ShaOf $path) }
function StateOf($name) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name) -ErrorAction SilentlyContinue
  if ($null -eq $service) { return [pscustomobject]@{ State = 'ABSENT' ; ProcessId = 0 } }
  return [pscustomobject]@{ State = $service.State ; ProcessId = $service.ProcessId }
}
function Find-ByteRun([byte[]]$haystack, [byte[]]$needle) {
  if ($needle.Length -eq 0 -or $haystack.Length -lt $needle.Length) { return -1 }
  $last = $haystack.Length - $needle.Length
  for ($outer = 0; $outer -le $last; $outer++) {
    $matched = $true
    for ($inner = 0; $inner -lt $needle.Length; $inner++) {
      if ($haystack[$outer + $inner] -ne $needle[$inner]) { $matched = $false ; break }
    }
    if ($matched) { return $outer }
  }
  return -1
}
function Find-Text([byte[]]$haystack, [string]$text) {
  $utf8 = Find-ByteRun $haystack ([Text.Encoding]::UTF8.GetBytes($text))
  if ($utf8 -ge 0) { return $utf8 }
  return (Find-ByteRun $haystack ([Text.Encoding]::Unicode.GetBytes($text)))
}
function Stamp-Of([string]$line) {
  $stampMatch = [regex]::Match($line, '^\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2})')
  if (-not $stampMatch.Success) { return $null }
  [datetimeoffset]$parsed = [datetimeoffset]::MinValue
  if ([datetimeoffset]::TryParse($stampMatch.Groups[1].Value, [ref]$parsed)) { return $parsed }
  return $null
}
# A data row is a non-empty line that is not part of an error message. NOT "a line with a
# separator": a single-column answer has none, which made a correct result count as zero rows.
function Select-DataRows($output) {
  # THE COMMA IS LOAD-BEARING. `return @(...)` UNROLLS a one-element array on the way out, so a
  # single-row result came back as a STRING: the caller's $rows[0] was then the first CHARACTER of
  # the row, Split('|') gave one field instead of four, and the whole block that read it was
  # skipped in silence. Measured 2026-10-13 16:24 on 234, where the row 0|1|0|0 was printed by the
  # probe and then not seen by it. Same trap as the one-element loop of 2026-10-04. The comma
  # operator keeps the array an array whatever its length.
  return ,@(@($output) | Where-Object { "$_".Trim() -ne '' -and "$_" -notmatch '(?i)^ERROR|^psql:|FATAL|^LINE \d|^\s*\^\s*$' })
}
function Utc-Now() { return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z' }

function Invoke-Native([scriptblock]$Block) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $previous }
}

function Assert-Machine() {
  Say "G0  machine identity (gate)"
  $nameMatches = ($env:COMPUTERNAME -eq 'RTM')
  $machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
  $uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
  Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
  Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
  if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure' ; Finish $false }
  Say "  G0 PASS"
  Rule
}

# ============================================================================================
# THE GENERIC HALF. Everything below was re-implemented by hand in probe after probe on
# 2026-10-14, and nearly every defect of that day was born in one of those re-implementations:
# an extension filter that silently did not filter (twice), a stamp form the parser did not know,
# a psql call whose stderr went nowhere, a report that lost its last section. They live here now,
# each with a self-test that runs in Start-Probe before any probe measures anything. A probe is
# meant to be predicates; the mechanics are not its business.
# ============================================================================================

# --- files ----------------------------------------------------------------------------------
# NEVER use Get-ChildItem -LiteralPath -Recurse -Include: with -LiteralPath the -Include is
# silently ignored and the list comes back unfiltered. Measured cost, 2026-10-14: "the newest .log
# file" came back as web.config and voided a whole section, twice.
# Rolled logs are log.txt.1 ... log.txt.100, whose extension is ".1", not ".txt" - so a filter by
# extension cannot see them either. Pass -IncludeRolled to get those as well.
function Get-FilesByExtension([string]$root, [string[]]$extensions, [switch]$IncludeRolled) {
  if (-not (Test-Path -LiteralPath $root)) { return @() }
  $found = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $keep = ($extensions -contains $_.Extension)
      if ((-not $keep) -and $IncludeRolled) {
        foreach ($ext in $extensions) { if ($_.Name -match ([regex]::Escape($ext) + '\.\d+$')) { $keep = $true } }
      }
      $keep
    })
  return @($found | Sort-Object LastWriteTime -Descending)
}

# --- log stamps -----------------------------------------------------------------------------
# Three forms live on this machine and a probe must not care which: the shell Serilog default
# (yyyy-MM-dd HH:mm:ss.fff zzz), the adapter log4net pattern (dd/MM/yyyy HH:mm:ss,fff - slashes,
# day first, measured from its own ConversionPattern), and the dotted form some tools emit.
# A parser that knows only one of them reports "the component was silent" when it was not.
function Parse-LogStamp([string]$line) {
  $text = "$line".TrimStart()
  $iso = [regex]::Match($text, '^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})')
  if ($iso.Success) {
    try { return [datetime]::ParseExact(($iso.Groups[1].Value + ' ' + $iso.Groups[2].Value), 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
  }
  $slashed = [regex]::Match($text, '^(\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2})')
  if ($slashed.Success) {
    try { return [datetime]::ParseExact($slashed.Groups[1].Value, 'dd/MM/yyyy HH:mm:ss', $null) } catch { return $null }
  }
  $dotted = [regex]::Match($text, '^(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2})')
  if ($dotted.Success) {
    try { return [datetime]::ParseExact($dotted.Groups[1].Value, 'dd.MM.yyyy HH:mm:ss', $null) } catch { return $null }
  }
  return $null
}

# --- a bounded window of a live log ----------------------------------------------------------
# Records the length, waits, then reads ONLY what was appended. That is what makes a count a count
# of lines born inside the window rather than lines present at some point. Freshness is judged by
# the stamp INSIDE the newest line and by growth, NEVER by the file time: a file a service holds
# open does not get its directory time written on every append, and judging by it produced a false
# red on a healthy log at 10:04 on 2026-10-14.
function Measure-LogWindow([string]$path, [int]$seconds) {
  $result = @{ Path = $path ; Grew = -1 ; Lines = @() ; NewestStamp = $null ; Alive = $false }
  if (-not (Test-Path -LiteralPath $path)) { return $result }
  $before = (Get-Item -LiteralPath $path).Length
  Say ('    window opens on ' + $path + ' at ' + $before + ' B, waiting ' + $seconds + ' s')
  Start-Sleep -Seconds $seconds
  $after = (Get-Item -LiteralPath $path).Length
  $result.Grew = $after - $before
  Say ('    length ' + $before + ' -> ' + $after + ' B, grew by ' + $result.Grew)
  if ($result.Grew -gt 0) {
    $stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      [void]$stream.Seek($before, [IO.SeekOrigin]::Begin)
      $buffer = New-Object byte[] $result.Grew
      [void]$stream.Read($buffer, 0, $result.Grew)
      $result.Lines = @([Text.Encoding]::UTF8.GetString($buffer) -split "`r?`n" | Where-Object { "$_".Trim() -ne '' })
    } finally { $stream.Dispose() }
  }
  foreach ($line in $result.Lines) {
    $stamp = Parse-LogStamp $line
    if ($null -ne $stamp) { $result.NewestStamp = $stamp }
  }
  $result.Alive = (($result.Grew -gt 0) -and ($result.Lines.Count -gt 0) -and ($null -ne $result.NewestStamp))
  Say ('    lines born inside the window : ' + $result.Lines.Count + '    newest stamp from the LINE : ' + $(if ($null -ne $result.NewestStamp) { $result.NewestStamp.ToString('yyyy-MM-dd HH:mm:ss') } else { 'none' }))
  return $result
}

# --- needles in bytes -------------------------------------------------------------------------
# Both encodings, always. A managed assembly carries most strings as UTF-16 and some as UTF-8, so
# a single-encoding count of zero means only that one encoding was searched.
function Count-ByteNeedle($haystack, [string]$text, [string]$encoding) {
  if ($null -eq $haystack) { return -1 }
  $needle = $(if ($encoding -eq 'utf16') { [Text.Encoding]::Unicode.GetBytes($text) } else { [Text.Encoding]::UTF8.GetBytes($text) })
  $count = 0
  $from = 0
  while ($from -le ($haystack.Length - $needle.Length)) {
    $slice = New-Object byte[] ($haystack.Length - $from)
    [Array]::Copy($haystack, $from, $slice, 0, $slice.Length)
    $foundAt = Find-ByteRun $slice $needle
    if ($foundAt -lt 0) { break }
    $count++
    $from = $from + $foundAt + $needle.Length
  }
  return $count
}
function Needle-Pair($bytes, [string]$text) {
  if ($null -eq $bytes) { return @(-1, -1) }
  return @((Count-ByteNeedle $bytes $text 'utf16'), (Count-ByteNeedle $bytes $text 'utf8'))
}
function Read-Bytes([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return ,[IO.File]::ReadAllBytes($path)
}

# --- secrets ----------------------------------------------------------------------------------
# A password reached two measurement files on 2026-10-13 because a section grepped appsettings for
# a word that names both a log level and a connection string. Every line that goes into a report
# from an external source passes through this.
function Test-Credentialish([string]$text) { return ($text -match '(?i)password\s*=|pwd\s*=|secret|token=|apikey|authtoken|accountsid') }
function Say-Guarded([string]$text) {
  if (Test-Credentialish $text) { Say '    [a line was WITHHELD here: its text could carry a credential]' ; return }
  Say $text
}

# --- the database -----------------------------------------------------------------------------
# The connection is read from the machine's own config as an OBJECT. I once typed a role name that
# does not exist and read PostgreSQL's answer as a wrong password; the machine knows its own user,
# port and database and I do not. The password travels as length and sha256 prefix only.
function Get-MachineConnection([string]$appSettingsPath) {
  if (-not (Test-Path -LiteralPath $appSettingsPath)) { Say ('  appsettings not found: ' + $appSettingsPath) ; return $null }
  $settingsJson = $null
  try { $settingsJson = ([IO.File]::ReadAllText($appSettingsPath) | ConvertFrom-Json) } catch { Say ('  appsettings does not parse: ' + $_.Exception.Message) ; return $null }
  if (($null -eq $settingsJson) -or ($null -eq $settingsJson.ConnectionStrings)) { Say '  no ConnectionStrings section' ; return $null }
  foreach ($property in $settingsJson.ConnectionStrings.PSObject.Properties) {
    $raw = [string]$property.Value
    $hostValue = ''
    $portValue = ''
    $databaseValue = ''
    $userValue = ''
    $secretValue = ''
    $hostMatch = [regex]::Match($raw, '(?i)(?:Host|Server)\s*=\s*([^;]+)')
    if ($hostMatch.Success) { $hostValue = $hostMatch.Groups[1].Value.Trim() }
    $portMatch = [regex]::Match($raw, '(?i)Port\s*=\s*([^;]+)')
    if ($portMatch.Success) { $portValue = $portMatch.Groups[1].Value.Trim() }
    $databaseMatch = [regex]::Match($raw, '(?i)Database\s*=\s*([^;]+)')
    if ($databaseMatch.Success) { $databaseValue = $databaseMatch.Groups[1].Value.Trim() }
    $userMatch = [regex]::Match($raw, '(?i)(?:Username|User ID|UserId|User)\s*=\s*([^;]+)')
    if ($userMatch.Success) { $userValue = $userMatch.Groups[1].Value.Trim() }
    $secretMatch = [regex]::Match($raw, '(?i)Password\s*=\s*([^;]+)')
    if ($secretMatch.Success) { $secretValue = $secretMatch.Groups[1].Value.Trim() }
    if ([string]::IsNullOrEmpty($hostValue) -or [string]::IsNullOrEmpty($databaseValue)) { continue }
    if ([string]::IsNullOrEmpty($portValue)) { $portValue = '5432' }
    $secretNote = 'absent'
    if (-not [string]::IsNullOrEmpty($secretValue)) {
      $secretSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($secretValue))).Replace('-','')
      $secretNote = 'length ' + $secretValue.Length + ' sha256 ' + $secretSha.Substring(0,16) + '...'
    }
    Say ('  connection "' + $property.Name + '" : host ' + $hostValue + ' port ' + $portValue + ' database ' + $databaseValue + ' user ' + $userValue)
    Say ('      password : ' + $secretNote)
    return @{ Name = $property.Name ; DbHost = $hostValue ; Port = $portValue ; Database = $databaseValue ; User = $userValue ; Secret = $secretValue }
  }
  Say '  no usable connection string found'
  return $null
}
function Find-Psql() {
  foreach ($pgVersion in @('18','17','16','15','14')) {
    $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  return $null
}
# DATA THROUGH -o, ERRORS THROUGH THEIR OWN FILE. Measured 2026-10-14: `*>&1 | Out-File` captured
# no stderr at all and mangled Hebrew on the way, so that report could not prove the absence of
# errors - and I only noticed because the deliberately broken query was LAST and its error was
# missing. PGCLIENTENCODING is set so names come back as themselves.
function Invoke-Psql($connection, [string]$label, [string]$sqlText, [string]$workDir, [bool]$withNegativeControl) {
  $empty = @()
  if ($null -eq $connection) { Say ('    ' + $label + ' : NO CONNECTION - NOT MEASURED') ; return $empty }
  $psql = Find-Psql
  if ($null -eq $psql) { Say ('    ' + $label + ' : psql NOT FOUND - NOT MEASURED') ; return $empty }
  if ([string]::IsNullOrWhiteSpace($sqlText)) { Say ('    ' + $label + ' : THE QUERY TEXT IS EMPTY - not run, states nothing') ; return $empty }
  if (-not (Test-Path -LiteralPath $workDir)) { New-Item -ItemType Directory -Force -Path $workDir | Out-Null }
  $sqlPath = Join-Path $workDir ($label + '.sql')
  $outPath = Join-Path $workDir ($label + '.out')
  $errPath = Join-Path $workDir ($label + '.err')
  [IO.File]::WriteAllText($sqlPath, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  Say  '    the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in @(Read-SharedLines $sqlPath)) { Say-Guarded ('    | ' + $sqlLine) }
  $env:PGCLIENTENCODING = 'UTF8'
  $env:PGPASSWORD = $connection.Secret
  if ($withNegativeControl) {
    $badSql = Join-Path $workDir ($label + '_negctl.sql')
    $badErr = Join-Path $workDir ($label + '_negctl.err')
    [IO.File]::WriteAllText($badSql, 'SELECT * FROM zzz_no_such_table;', (New-Object System.Text.UTF8Encoding($false)))
    Start-Process -FilePath $psql -NoNewWindow -Wait -RedirectStandardError $badErr -ArgumentList @('-h',$connection.DbHost,'-p',$connection.Port,'-U',$connection.User,'-d',$connection.Database,'-v','ON_ERROR_STOP=1','-f',$badSql,'-o','NUL')
    $badLines = @(Read-SharedLines $badErr)
    Say ('    NEGCTL a deliberately broken query : ' + $badLines.Count + ' error lines   (must be 1 or more, else an empty error file below proves nothing)')
    foreach ($badLine in $badLines) { Say-Guarded ('      ' + $badLine) }
  }
  Start-Process -FilePath $psql -NoNewWindow -Wait -RedirectStandardError $errPath -ArgumentList @('-h',$connection.DbHost,'-p',$connection.Port,'-U',$connection.User,'-d',$connection.Database,'-v','ON_ERROR_STOP=0','-t','-A','-F','|','-f',$sqlPath,'-o',$outPath)
  $env:PGPASSWORD = $null
  $errLines = @(Read-SharedLines $errPath)
  Say ('    error lines from psql : ' + $errLines.Count + '   (this file is where they land; a count of 0 is meaningful only because the NEGCTL above lands here too)')
  foreach ($errLine in $errLines) { Say-Guarded ('      ' + $errLine) }
  $output = @(Read-SharedLines $outPath)
  foreach ($outputLine in $output) { Say-Guarded ('    ' + $outputLine) }
  if ($errLines.Count -gt 0) { Say '    THIS QUERY REPORTED ERRORS - read them before believing any row above.' }
  return (Select-DataRows $output)
}

function Start-Probe([string]$Name, [string]$Title, [string]$OutputDir) {
  $stamp = Get-Date -Format yyyyMMdd_HHmmss
  $outputDir = $OutputDir
  if ([string]::IsNullOrEmpty($outputDir)) { $outputDir = 'C:\RTMView-Ops\output' }
  if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
  $hostTag = if ($env:COMPUTERNAME -eq 'RTM') { '234' } else { 'WS' }
  $script:ReportPath = Join-Path $outputDir ("{0}_{1}_{2}.txt" -f $hostTag, $stamp, $Name)
  if ([string]::IsNullOrEmpty($Title)) { $Title = $Name }
  Say ($Title + '  ' + (Utc-Now) + '   (machine local: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' local)   host=' + $env:COMPUTERNAME)
  Say ('core sha256  : ' + (ShaOf (Join-Path (Split-Path -Parent $PSCommandPath) '_core.ps1')))
  Rule
  Say 'SELF-TEST OF THE CORE, before any probe measures anything'
  $hay = [Text.Encoding]::UTF8.GetBytes('aaaHELLObbb')
  $hit = Find-ByteRun $hay ([Text.Encoding]::UTF8.GetBytes('HELLO'))
  $miss = Find-ByteRun $hay ([Text.Encoding]::UTF8.GetBytes('WORLD'))
  Say ('  Find-ByteRun : present needle @' + $hit + ' (expected 3)   absent needle @' + $miss + ' (expected -1)')
  $wide = [Text.Encoding]::Unicode.GetBytes('WIDE')
  $hitWide = Find-Text $wide 'WIDE'
  Say ('  Find-Text    : utf16 needle @' + $hitWide + ' (expected 0, proving both encodings are tried)')
  $shaKnown = ShaOf 'C:\Windows\System32\cmd.exe'
  Say ('  ShaOf        : a file that exists -> ' + $shaKnown.Substring(0, 12) + '...   a file that does not -> ' + (ShaOf 'C:\zzz-no-such-file'))
  $rowsOk = (Select-DataRows @('509', '', 'ERROR:  nope', 'LINE 1: x')).Count
  Say ('  Select-DataRows : 1 data row out of 4 output lines -> ' + $rowsOk + ' (expected 1)')
  # The row above is also the control for the unroll: a ONE-row result must come back as an array
  # whose first element is the whole row, not as a string whose first element is a character.
  $oneRow = Select-DataRows @('0|1|0|0')
  $firstField = ([string]$oneRow[0]).Split('|')[0]
  $fieldCount = ([string]$oneRow[0]).Split('|').Count
  Say ('  one-row result  : element 0 splits into ' + $fieldCount + ' fields (expected 4), first field "' + $firstField + '" (expected "0" from a FOUR-field row, not a single character of it)')
  $stampOk = Stamp-Of '2026-10-13 10:18:59.123 +03:00 [INF] x'
  $stampBad = Stamp-Of 'no timestamp here'
  Say ('  Stamp-Of     : a stamped line -> ' + $(if ($null -ne $stampOk) { $stampOk.ToUniversalTime().ToString('HH:mm:ssZ') } else { 'NULL' }) + '   an unstamped one -> ' + $(if ($null -eq $stampBad) { 'NULL as it must be' } else { 'NOT NULL - WRONG' }))
  # --- the generic half, self-tested here so no probe has to trust it blind -------------------
  $tempRoot = Join-Path $env:TEMP ('coretest_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $sharedOk = $false
  $filesOk = $false
  $stampsOk = $false
  $needleOk = $false
  $guardOk = $false
  try {
    # Read-SharedLines: three lines, ONE line, absent file, and a file held open by a writer.
    [IO.File]::WriteAllLines((Join-Path $tempRoot 'three.log'), @('a','b','c'))
    [IO.File]::WriteAllLines((Join-Path $tempRoot 'one.log'), @('only'))
    $three = @(Read-SharedLines (Join-Path $tempRoot 'three.log')).Count
    $one   = @(Read-SharedLines (Join-Path $tempRoot 'one.log')).Count
    $none  = @(Read-SharedLines (Join-Path $tempRoot 'zzz-absent.log')).Count
    $held = [IO.File]::Open((Join-Path $tempRoot 'three.log'), [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $whileHeld = 0
    try { $whileHeld = @(Read-SharedLines (Join-Path $tempRoot 'three.log')).Count } finally { $held.Dispose() }
    Say ('  Read-SharedLines : 3-line ' + $three + ' (3) , ONE-line ' + $one + ' (1, the unroll trap) , absent ' + $none + ' (0) , held open ' + $whileHeld + ' (3)')
    $sharedOk = (($three -eq 3) -and ($one -eq 1) -and ($none -eq 0) -and ($whileHeld -eq 3))

    # Get-FilesByExtension: must filter, and must see a rolled name only when asked.
    # ITS OWN SUBDIRECTORY, because the first version of this self-test counted the .log files the
    # Read-SharedLines test had just written into the same folder and came out 3 instead of 1 -
    # which would have printed CORE : NOT TRUSTED in every probe on the server. The expectation of
    # a test must be derived from what that test itself set up, not from what I meant to set up.
    $extRoot = Join-Path $tempRoot 'ext'
    New-Item -ItemType Directory -Force -Path $extRoot | Out-Null
    [IO.File]::WriteAllText((Join-Path $extRoot 'keep.log'), 'x')
    [IO.File]::WriteAllText((Join-Path $extRoot 'skip.config'), 'x')
    [IO.File]::WriteAllText((Join-Path $extRoot 'keep.log.7'), 'x')
    $plain = @(Get-FilesByExtension $extRoot @('.log')).Count
    $rolled = @(Get-FilesByExtension $extRoot @('.log') -IncludeRolled).Count
    Say ('  Get-FilesByExtension : .log only -> ' + $plain + ' (expected 1, and the .config must NOT be in it) , with -IncludeRolled -> ' + $rolled + ' (expected 2)')
    $filesOk = (($plain -eq 1) -and ($rolled -eq 2))

    # Parse-LogStamp: all three forms this machine writes, and a line with no stamp at all.
    $isoStamp = Parse-LogStamp '2026-10-14 15:04:40.123 +03:00 [INF] x'
    $slashStamp = Parse-LogStamp ' 14/10/2026 12:24:54,392 INFO  RTData entry'
    $dotStamp = Parse-LogStamp '14.10.2026 12:24:54 something'
    $noStamp = Parse-LogStamp 'no stamp here at all'
    Say ('  Parse-LogStamp : iso ' + $(if ($null -ne $isoStamp) { $isoStamp.ToString('HH:mm:ss') } else { 'NULL' }) + ' (15:04:40) , slashed ' + $(if ($null -ne $slashStamp) { $slashStamp.ToString('HH:mm:ss') } else { 'NULL' }) + ' (12:24:54) , dotted ' + $(if ($null -ne $dotStamp) { $dotStamp.ToString('HH:mm:ss') } else { 'NULL' }) + ' (12:24:54) , unstamped ' + $(if ($null -eq $noStamp) { 'NULL as it must be' } else { 'NOT NULL - WRONG' }))
    $stampsOk = (($null -ne $isoStamp) -and ($null -ne $slashStamp) -and ($null -ne $dotStamp) -and ($null -eq $noStamp) -and ($isoStamp.ToString('HH:mm:ss') -eq '15:04:40') -and ($slashStamp.ToString('HH:mm:ss') -eq '12:24:54'))

    # Count-ByteNeedle / Needle-Pair: present in each encoding, and absent.
    $utf8Hay = [Text.Encoding]::UTF8.GetBytes('aa NEEDLE bb NEEDLE cc')
    $utf16Hay = [Text.Encoding]::Unicode.GetBytes('aa NEEDLE bb')
    $twice = Count-ByteNeedle $utf8Hay 'NEEDLE' 'utf8'
    $wide = Count-ByteNeedle $utf16Hay 'NEEDLE' 'utf16'
    $absent = Count-ByteNeedle $utf8Hay 'ZZZNOPE' 'utf8'
    $pair = Needle-Pair $utf8Hay 'NEEDLE'
    $nullPair = Needle-Pair $null 'NEEDLE'
    Say ('  Count-ByteNeedle : utf8 twice -> ' + $twice + ' (2) , utf16 once -> ' + $wide + ' (1) , absent -> ' + $absent + ' (0) , pair on null bytes -> ' + $nullPair[0] + '/' + $nullPair[1] + ' (-1/-1, so a missing file never reads as a zero count)')
    $needleOk = (($twice -eq 2) -and ($wide -eq 1) -and ($absent -eq 0) -and ($pair[1] -eq 2) -and ($nullPair[0] -eq -1))

    # Test-Credentialish: the shapes that leaked once, and a line that must pass through.
    $catches = @('Password=hunter2', 'AuthToken: abc', 'accountsid=AC123')
    $caught = 0
    foreach ($candidate in $catches) { if (Test-Credentialish $candidate) { $caught++ } }
    $innocent = Test-Credentialish 'rows : 41531'
    Say ('  Test-Credentialish : caught ' + $caught + ' of 3 credential shapes , flagged an innocent line : ' + $innocent + ' (must be False)')
    $guardOk = (($caught -eq 3) -and (-not $innocent))
  } finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
  Say  '  Invoke-Psql is NOT self-tested here: it needs a live server, and its negative half is the'
  Say  '  deliberately broken query it runs in place - the error file must be non-empty, or a zero'
  Say  '  error count later proves nothing.'
  $coreOk = (($hit -eq 3) -and ($miss -eq -1) -and ($hitWide -eq 0) -and ($shaKnown -ne 'ABSENT') -and ((ShaOf 'C:\zzz-no-such-file') -eq 'ABSENT') -and ($rowsOk -eq 1) -and ($fieldCount -eq 4) -and ($null -ne $stampOk) -and ($null -eq $stampBad) -and $sharedOk -and $filesOk -and $stampsOk -and $needleOk -and $guardOk)
  Say ('  CORE : ' + $(if ($coreOk) { 'TRUSTED' } else { 'NOT TRUSTED - nothing this probe prints can be believed' }))
  if (-not $coreOk) { Finish $false }
  Rule
}
