<#
  PROBE  probe_234_20260920_diskdrain-step1.ps1
  UNIT   PR234-DISK-DRAIN-01 step 1. The question is NOT what is BIG - big and old is innocent.
         The question is WHAT GROWS. Those are different predicates and the report separates them.
  WHY    Free space on C: read 22.1 / 18.78 / 15.7 / 12.6 GB over 32 hours, then 12.63 an hour later -
         the fifth point did NOT fall on the line the first four drew. So the first question of this
         subject is whether the drain is even steady, and that is asked BEFORE any source is hunted.

  !! PREMISE REFUTED 2026-09-24, BEFORE THIS PROBE EVER RAN - read this before using it !!
         This file was written on 20.09 and never executed. On 24.09 at 11:27 the sixth point was
         taken with one command: 17.95 GB free. Space came BACK - 5.35 GB over 87 hours.
         So there is no steady consumer, and the expectation printed in section 1 below
         (about 12.1 GB or lower) is FALSE as of today. It is left in place deliberately, unedited,
         because an expectation quietly rewritten after the fact stops being an expectation.
         Read section 1 as a record of what was expected on 20.09, never as a target for today.
         Had this probe run unchanged, its own section 1 would have told the reader the drain was
         steady - the instrument would have lied about the world while measuring it correctly.
         What survives is the SHAPE: what is big and what GROWS are different questions, the recent
         -files sweep answers the second, and the foreign zones are read and marked, never touched.
         If the subject is picked up again it will be about EVENTS - something that eats gigabytes in
         bursts and releases them - and section 1 has to be rewritten for that question first.
  WHERE  SERVER 234. READ-ONLY. Nothing is deleted, moved, stopped or started. The only file written
         is the report under C:\RTMView-Ops\output\. Foreign zones are READ but never touched.
  NOTE   This run makes NO deletion proposal. The named list goes to the coordinator as step 3.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_diskdrain-step1.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function CountOf($block) { try { return @(& $block).Count } catch { return -999 } }
function SizeGbOf($dirPath) {
  try {
    $sum = (Get-ChildItem -LiteralPath $dirPath -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($null -eq $sum) { return 0.0 }
    return [math]::Round($sum / 1GB, 3)
  } catch { return -999 }
}

Say ('DISK DRAIN STEP 1  ' + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + ' (machine local clock)  host=' + $env:COMPUTERNAME)
Say  'READ ONLY. Nothing is deleted, moved, stopped or started.'
Say ('probe sha256 : ' + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
Rule

Say 'G-1  the measuring helper self-tests on a known answer, before any live size'
$selfDir = Join-Path $env:TEMP ('drain_selftest_{0}' -f $RunStamp)
New-Item -ItemType Directory -Force -Path $selfDir | Out-Null
$selfEmpty = CountOf { Get-ChildItem $selfDir -ErrorAction SilentlyContinue }
$selfSizeEmpty = SizeGbOf $selfDir
New-Item -ItemType File -Force -Path (Join-Path $selfDir 'a.bin') | Out-Null
[IO.File]::WriteAllBytes((Join-Path $selfDir 'a.bin'), (New-Object byte[] 1048576))
$selfSizeOne = SizeGbOf $selfDir
$selfThrow = CountOf { throw 'deliberate' }
Say ('  expected : empty folder count 0 / empty folder size 0 / 1 MB folder size 0.001 / throwing -999')
Say ('  measured : ' + $selfEmpty + ' / ' + $selfSizeEmpty + ' / ' + $selfSizeOne + ' / ' + $selfThrow)
Remove-Item $selfDir -Recurse -Force -ErrorAction SilentlyContinue
if (($selfEmpty -ne 0) -or ($selfSizeEmpty -ne 0.0) -or ($selfSizeOne -ne 0.001) -or ($selfThrow -ne -999)) {
  Say '  *** the measuring helper cannot tell empty from failed, or mis-sizes a known megabyte. Every number below would be void.'
  Finish $false
}
Say '  G-1 PASS'
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

Say '1  FREE SPACE - the sixth point of the series'
Say  '  the five before, all measured by probe: 22.1 (19.09 12:20) / 18.78 (19.09 17:14) /'
Say  '  15.7 (20.09 11:26) / 12.6 (20.09 20:32) / 12.63 (20.09 21:0x, after the package landed)'
Say  '  EXPECTATION, printed before the measurement: if the drain is steady at 0.3 GB/h this reads'
Say  '  about 12.1 or lower. If it reads near 12.5 the line is NOT steady and the subject changes shape.'
$drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if ($null -eq $drive) { Say '  free space : NOT MEASURED (-999)'; Finish $false }
$freeNow = [math]::Round($drive.Free/1GB, 2)
Say ('  measured   : ' + $freeNow + ' GB free of ' + [math]::Round(($drive.Free+$drive.Used)/1GB,1) + ' GB')
Rule

Say '2  WHAT IS BIG - top-level directories of C:, by size. Big is not guilty; this is the map only.'
Say  '  Foreign zones are READ here and marked. They are never written, moved or deleted by us.'
$foreign = @('C:\IceDash', 'C:\Program Files\CcDashboard')
foreach ($top in (Get-ChildItem -LiteralPath 'C:\' -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
  $topSizeGb = SizeGbOf $top.FullName
  $mark = ''
  foreach ($zone in $foreign) { if ($top.FullName -eq $zone) { $mark = '   [FOREIGN - read only]' } }
  Say ('  {0,-34} {1,10} GB{2}' -f $top.FullName, $topSizeGb, $mark)
}
Rule

Say '3  OUR OWN DIRECTORIES, broken out - so our share of the disk is a number, not a feeling'
foreach ($ours in @('C:\RTMView', 'C:\RTMView\Shell', 'C:\RTMView\RTM', 'C:\RTMView\RTM.Twilio',
                    'C:\RTMView\Backup', 'C:\RTMView-Ops', 'C:\RTMView-Ops\incoming',
                    'C:\RTMView-Ops\output', 'C:\RTMView-Ops\backup', 'C:\RTMView-Ops\applied', 'C:\Logs')) {
  if (Test-Path -LiteralPath $ours) {
    Say ('  {0,-34} {1,10} GB   entries {2}' -f $ours, (SizeGbOf $ours), (CountOf { Get-ChildItem -LiteralPath $ours -Force -ErrorAction SilentlyContinue }))
  } else { Say ('  {0,-34} ABSENT' -f $ours) }
}
Rule

Say '4  WHAT GROWS - files written in the last 6 hours, anywhere on C:, largest first'
Say  '  THIS is the predicate of this subject. A 40 GB directory untouched since May explains nothing;'
Say  '  a 2 GB file written twenty minutes ago explains everything.'
Say  '  Expectation: our own install of 21:38 accounts for one backup directory and the package.'
Say  '  Anything else large and recent is the finding.'
$cutoff = (Get-Date).AddHours(-6)
$recent = @(Get-ChildItem -LiteralPath 'C:\' -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $cutoff } |
            Sort-Object Length -Descending | Select-Object -First 40)
Say ('  files written since ' + $cutoff.ToString('yyyy-MM-dd HH:mm') + ' : ' + $recent.Count + ' shown (largest 40)')
if ($recent.Count -eq 0) { Say '  *** ZERO recent files found - that is a broken search, not a quiet disk. Report it as NOT MEASURED.' }
foreach ($item in $recent) {
  Say ('  {0,10} MB  {1}  {2}' -f [math]::Round($item.Length/1MB,1), $item.LastWriteTime.ToString('MM-dd HH:mm'), $item.FullName)
}
Say  '  POSCTL for this search: the report file of this very run is being written now and must appear'
Say  '  in a re-run of this list. A search that cannot see a file we know exists is blind.'
Rule

Say '5  THE USUAL SUSPECTS, named and measured rather than assumed'
foreach ($suspect in @('C:\Windows\Temp', 'C:\Windows\SoftwareDistribution\Download', 'C:\Windows\Minidump',
                       'C:\ProgramData\Microsoft\Windows\WER', 'C:\Users\Administrator\AppData\Local\Temp')) {
  if (Test-Path -LiteralPath $suspect) { Say ('  {0,-52} {1,9} GB' -f $suspect, (SizeGbOf $suspect)) }
  else { Say ('  {0,-52} ABSENT' -f $suspect) }
}
$pgDataDirs = @(Get-ChildItem -LiteralPath 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue)
foreach ($pgDir in $pgDataDirs) {
  $dataPath = Join-Path $pgDir.FullName 'data'
  if (Test-Path -LiteralPath $dataPath) { Say ('  {0,-52} {1,9} GB' -f $dataPath, (SizeGbOf $dataPath)) }
}
Say  '  PostgreSQL 15 on 5432 is NOT ours. It is measured here and nothing more: a number about'
Say  '  someone else is evidence, not a licence to touch it.'
$shadow = & vssadmin list shadowstorage 2>&1
foreach ($shadowLine in @($shadow | ForEach-Object { "$_" })) { if ("$shadowLine".Trim()) { Say ('  | ' + $shadowLine) } }
Rule

Say 'SUMMARY - readings only. NO deletion is proposed by this run and none was performed.'
Say ('  free space now : ' + $freeNow + ' GB')
Say ('  report         : ' + $ReportPath)
Say  '  Step 2 asks whether the top suspect is growing RIGHT NOW, with a same-kind directory that is'
Say  '  not growing as its negative half. Step 3 is a named list for the coordinator. Only step 4 deletes.'
Say 'END-OF-RUN MARKER: DISKDRAIN-STEP1-COMPLETE'
Finish $true
