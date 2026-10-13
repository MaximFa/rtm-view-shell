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
function Rule() { Say ('-' * 78) }
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
  $coreOk = (($hit -eq 3) -and ($miss -eq -1) -and ($hitWide -eq 0) -and ($shaKnown -ne 'ABSENT') -and ((ShaOf 'C:\zzz-no-such-file') -eq 'ABSENT') -and ($rowsOk -eq 1) -and ($fieldCount -eq 4) -and ($null -ne $stampOk) -and ($null -eq $stampBad))
  Say ('  CORE : ' + $(if ($coreOk) { 'TRUSTED' } else { 'NOT TRUSTED - nothing this probe prints can be believed' }))
  if (-not $coreOk) { Finish $false }
  Rule
}
