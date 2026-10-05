<#
  PROBE  probe_234_20260926_enginefloor.ps1
  UNIT   PR234 v4 rollout, step 1b. ONE question: is there a package on this disk that would put
         back the engine that is running right now?
  WHY    My own predicate in the pre-deploy probe asked whether any RTM package exists. Four do,
         so it went green - but the question was never "are there packages", it was "is there a
         package that restores THIS engine". A check weaker than its question prints a false green,
         and this run replaces it with the check the question actually needs.
  WHAT   For each *RTM*.zip in incoming: pull CcDashboard/RTM binary RTM.dll out of the archive and
         hash it. The deployed engine is 4FE7009A5E28D27EA84700CD1BE0ED6835F42E26813FFE8260B2590C73F4114E
         [measured on this machine 2026-09-26 16:25, report 234_20260926_162510_predeploy-251ca40.txt].
  EXPECTATION, PRINTED BEFORE THE MEASUREMENT: NO match. The newest RTM package is dated 15.09 and
         the deployed engine carries 0ae2102 from 19.09, so a match would be the surprise, not the
         rule. If one does match, this flight gets its floor for free and I say so.
  NEGATIVE HALF, AND IT IS NOT SYNTHETIC: the same archive-reading code is pointed at the Shell
         package 20092026.2047_Shell.zip, whose CcDashboard.Web.dll MUST hash to
         76C00DBCAA2E7A06F960E724BC8FD9A31FF9C22D8827A55BFFD815937B066115 - the value measured on
         the running machine. If that one does not match, the READER is broken and every NO MATCH
         above it is meaningless rather than informative.
  WHERE  SERVER 234. READ-ONLY. Archives are opened for reading, nothing is extracted to disk except
         one temporary file per entry under the user TEMP, removed immediately. No service is touched.
#>

$ErrorActionPreference = 'Continue'
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_enginefloor.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function CountOf($block) { try { return @(& $block).Count } catch { return -999 } }

$DeployedEngineSha = '4FE7009A5E28D27EA84700CD1BE0ED6835F42E26813FFE8260B2590C73F4114E'
$DeployedShellSha  = '76C00DBCAA2E7A06F960E724BC8FD9A31FF9C22D8827A55BFFD815937B066115'
$IncomingDir       = 'C:\RTMView-Ops\incoming'
$ShellPackage      = Join-Path $IncomingDir '20092026.2047_Shell.zip'

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-EntryHash($archivePath, $leafName) {
    # returns the sha256 of the FIRST entry whose leaf name matches, or a word saying why not
    if (-not (Test-Path -LiteralPath $archivePath)) { return 'ARCHIVE ABSENT' }
    $archive = $null
    try { $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath) }
    catch { return ('ARCHIVE UNREADABLE: ' + $_.Exception.GetType().Name) }
    try {
        $entry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq $leafName } | Select-Object -First 1
        if (-not $entry) { return 'ENTRY NOT IN ARCHIVE' }
        $tempFile = Join-Path $env:TEMP ('floor_' + [Guid]::NewGuid().ToString('N') + '.bin')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tempFile, $true)
        $hash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        return $hash
    } finally { if ($archive) { $archive.Dispose() } }
}

Say ('ENGINE FLOOR - step 1b  ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' (machine local clock)  host=' + $env:COMPUTERNAME)
Say  'READ ONLY. Archives are opened for reading. No service is started, stopped or touched.'
Say ('probe sha256 : ' + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
Rule

Say 'G0  machine identity'
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ('  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ('  measured : name match ' + $nameMatches + ' / uuid match ' + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say '  G0 PASS'
Rule

Say 'G1  IS THE READER ITSELF SOUND - this runs FIRST, before any answer is believed'
Say ('  expected : CcDashboard.Web.dll inside ' + (Split-Path -Leaf $ShellPackage))
Say ('             hashes to ' + $DeployedShellSha)
Say  '             because that package is what is installed and running on this machine right now.'
$shellEntryHash = Get-EntryHash $ShellPackage 'CcDashboard.Web.dll'
Say ('  measured : ' + $shellEntryHash)
$readerSound = ($shellEntryHash -eq $DeployedShellSha)
Say ('  reader sound : ' + $readerSound)
if (-not $readerSound) {
    Say '  *** THE ARCHIVE READER IS NOT TRUSTWORTHY. Every NO MATCH below would be meaningless -'
    Say '  *** not evidence of a missing floor, just evidence of a broken instrument. STOPPING.'
    Finish $false
}
Say '  G1 PASS - a NO MATCH below now means the engine really is not in that archive'
Rule

Say '1  THE FOUR CANDIDATES - engine binary inside each RTM package'
Say ('  deployed engine RTM.dll : ' + $DeployedEngineSha)
Say  '  EXPECTED, BEFORE THE MEASUREMENT: no match. A match would be a welcome surprise.'
# Sorted by NAME, deliberately. lint_probe flags 'newest file in a directory' because a probe
# that PICKS the newest can read yesterday's leftover as today's result. This probe picks
# nothing: it inspects every candidate and prints each one's date on its own line, so the
# ordering carries no meaning and a time-based sort would only invite that misreading back.
$candidates = @(Get-ChildItem -LiteralPath $IncomingDir -Filter *RTM*.zip -ErrorAction SilentlyContinue | Sort-Object Name)
Say ('  archives to inspect : ' + $candidates.Count)
if ($candidates.Count -eq 0) { Say '  *** none found - but the pre-deploy probe found four. A zero here is a broken search.'; Finish $false }
$matchCount = 0
foreach ($candidate in $candidates) {
    $entryHash = Get-EntryHash $candidate.FullName 'RTM.dll'
    $isMatch = ($entryHash -eq $DeployedEngineSha)
    if ($isMatch) { $matchCount++ }
    Say ('  ' + $candidate.Name.PadRight(34) + ' ' + $candidate.LastWriteTime.ToString('yyyy-MM-dd') + '  ' + $entryHash)
    Say ('  ' + ' '.PadRight(34) + ' restores the running engine : ' + $isMatch)
}
Rule

Say 'VERDICT'
Say ('  archives inspected        : ' + $candidates.Count)
Say ('  restoring the running engine : ' + $matchCount + '   (expected 0 - see the expectation above)')
if ($matchCount -eq 0) {
    Say  '  NO FLOOR FOR THE ENGINE on this disk. The rollout must not proceed until one exists:'
    Say  '  a package built from the deployed revision 0ae2102, placed in incoming and hash-verified.'
    Say  '  This is a measured absence, not a guess: the reader was proven sound by G1 first.'
} else {
    Say  '  A FLOOR EXISTS - named above. The rollout can carry it without building anything.'
}
Say  '  Nothing was installed, deleted, started or stopped by this run.'
Say 'END-OF-RUN MARKER: ENGINEFLOOR-COMPLETE'
Finish $true
