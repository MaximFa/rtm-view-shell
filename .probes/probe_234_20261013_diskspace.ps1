<#
  PROBE  probe_234_20261013_diskspace.ps1
  READ-ONLY. Nothing is deleted, moved, installed or restarted. This probe exists because the
  install of 2d75b01 failed at [ 2/5 ] with "There is not enough space on the disk" while backing
  up C:\RTMView\RTM, and because the installer's own preflight had just printed
  "[OK] disk space: 3.3GB free on C:" and walked into it. A cleanup list for 234 needs the
  operator's word and a list of PATHS WITH SIZES - so this probe produces the numbers that list
  will be made of, and deletes nothing itself.
  WHAT IT ANSWERS, each line a pair rather than a single number:
    how much is free on C: now, against how much the failed step was trying to copy;
    every backup set with its size, and WHICH ONE is the live rollback floor (never a candidate);
    every pkg_* staging left by an install, with the flight it belongs to;
    the engine's own log directory, because the file it died on was RTM.log20261011.
  WHY A PROBE AND NOT A FEW COMMANDS: the sizes have to be measured the same way for every row,
  and the floor has to be IDENTIFIED rather than assumed, or the list I hand over will name the
  one directory we must not touch.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

Start-Probe -Name 'diskspace' -Title 'DISK ON 234 after the failed install of 2d75b01'
Say 'READ-ONLY. Nothing is deleted, moved, installed or restarted by this probe.'
Rule
Assert-Machine

function Size-Of([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  $measured = Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  if ($null -eq $measured.Sum) { return 0 }
  return [int64]$measured.Sum
}
function Format-Megabytes([int64]$bytes) {
  if ($bytes -lt 0) { return 'ABSENT' }
  return ([string][math]::Round($bytes / 1MB, 1)) + ' MB'
}

Say '1  FREE SPACE, AGAINST WHAT THE FAILED STEP WAS TRYING TO COPY'
$driveC = Get-PSDrive -Name C
Say ('  C: free ' + [math]::Round($driveC.Free/1GB,2) + ' GB of ' + [math]::Round(($driveC.Free+$driveC.Used)/1GB,1) + ' GB')
$shellSize  = Size-Of 'C:\RTMView\Shell'
$engineSize = Size-Of 'C:\RTMView\RTM'
Say ('  the backup step copies BOTH of these, whatever the package holds (Update-RTMView.ps1:278 has no mode condition):')
Say ('    C:\RTMView\Shell : ' + (Format-Megabytes $shellSize))
Say ('    C:\RTMView\RTM   : ' + (Format-Megabytes $engineSize) + '   <- this is the one it died on')
$needed = $shellSize + $engineSize
Say ('  so one backup set needs about ' + (Format-Megabytes $needed) + ' , and free space is ' + [math]::Round($driveC.Free/1MB,1) + ' MB')
Say ('  EXPECTED, printed before the judgement: free < needed is what explains the failure;')
Say ('  free > needed would mean the cause is NOT a shortage and I must look elsewhere.')
Say ('  measured : free > needed ? ' + ($driveC.Free -gt $needed))
Rule

Say '2  BACKUP SETS - AND WHICH ONE IS THE LIVE FLOOR'
Say  '  The floor is the set matching the package the machine RUNS, and it is never a cleanup'
Say  '  candidate. The set written today at 14:19 is INCOMPLETE: the installer copied Shell and'
Say  '  then died inside RTM, so it looks like a floor and is not one.'
$backupRoot = 'C:\RTMView\Backup'
$backupTotal = [int64]0
foreach ($backupSet in @(Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
  $setSize = Size-Of $backupSet.FullName
  $backupTotal += $setSize
  $hasShell  = Test-Path -LiteralPath (Join-Path $backupSet.FullName 'Shell')
  $hasEngine = Test-Path -LiteralPath (Join-Path $backupSet.FullName 'RTM')
  $shellDll  = Join-Path $backupSet.FullName 'Shell\CcDashboard.Web.dll'
  $dllSha    = ShaOf $shellDll
  $isRunning = ($dllSha -eq '0C71E9434A89D50FDA968C0B63EE5F4EB4D37A05710E16BF84C22CB753C17F16')
  $note = ''
  if ($isRunning) { $note = '<- carries the web.dll THIS MACHINE RUNS: the live floor, do not touch' }
  elseif ($hasShell -and -not $hasEngine) { $note = '<- INCOMPLETE: Shell only, no RTM' }
  Say ('  ' + $backupSet.Name.PadRight(18) + (Format-Megabytes $setSize).PadLeft(10) + '   Shell ' + $hasShell + '  RTM ' + $hasEngine + '   ' + $note)
  if ($dllSha -ne 'ABSENT') { Say ('  ' + ' '.PadRight(18) + '   web.dll ' + $dllSha.Substring(0,16) + '...') }
}
Say ('  sets : ' + @(Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue).Count + '   total ' + (Format-Megabytes $backupTotal) + '   (a zero count would mean the listing is wrong, not that there are no backups)')
$negBackup = Size-Of (Join-Path $backupRoot 'zzz_no_such_set')
Say ('  NEGCTL a set that cannot exist : ' + (Format-Megabytes $negBackup) + '   (must read ABSENT)')
Rule

Say '3  STAGING DIRECTORIES LEFT BY INSTALLS - each named with the flight it belongs to'
$stagingTotal = [int64]0
foreach ($staging in @(Get-ChildItem -LiteralPath 'C:\RTMView-Ops\incoming' -Directory -Filter 'pkg_*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
  $stagingSize = Size-Of $staging.FullName
  $stagingTotal += $stagingSize
  Say ('  ' + $staging.Name.PadRight(34) + (Format-Megabytes $stagingSize).PadLeft(10) + '   written ' + $staging.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ' local')
}
Say ('  staging total : ' + (Format-Megabytes $stagingTotal))
Say  '  The staging of the CURRENT flight is read by the acceptance step, so it is not a candidate'
Say  '  until that step has run. Older ones belong to flights already accepted.'
Rule

Say '4  PACKAGES IN incoming - the rollback floor among them must stay'
$zipTotal = [int64]0
foreach ($zipFile in @(Get-ChildItem -LiteralPath 'C:\RTMView-Ops\incoming' -Filter *.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)) {
  $zipTotal += $zipFile.Length
  $zipSha = ShaOf $zipFile.FullName
  $label = ''
  if ($zipSha.StartsWith('07263B55')) { $label = '<- ROLLBACK FLOOR f333db5, never a candidate' }
  if ($zipSha -eq '8E2652AE40C3F8B53635FCA8D9F480218D04DECF8573DC56D24FAE783D2ED0D6') { $label = '<- the package of the flight still to be installed' }
  Say ('  ' + $zipFile.Name.PadRight(30) + (Format-Megabytes $zipFile.Length).PadLeft(10) + '   ' + $zipSha.Substring(0,16) + '...  ' + $label)
}
Say ('  packages total : ' + (Format-Megabytes $zipTotal))
Rule

Say '5  THE ENGINE LOG DIRECTORY - the file the copy died on was RTM.log20261011'
foreach ($logDir in @('C:\RTMView\RTM', 'C:\Logs\RTMViewShell')) {
  if (-not (Test-Path -LiteralPath $logDir)) { Say ('  ' + $logDir + ' ABSENT') ; continue }
  $logs = @(Get-ChildItem -LiteralPath $logDir -Filter '*.log*' -File -Recurse -ErrorAction SilentlyContinue)
  $logBytes = [int64]0
  foreach ($log in $logs) { $logBytes += $log.Length }
  Say ('  ' + $logDir.PadRight(26) + ' log files ' + ([string]$logs.Count).PadLeft(5) + '   ' + (Format-Megabytes $logBytes))
  foreach ($log in @($logs | Sort-Object Length -Descending | Select-Object -First 5)) {
    Say ('      ' + $log.Name.PadRight(34) + (Format-Megabytes $log.Length).PadLeft(10) + '   last written ' + $log.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + ' local')
  }
}
Say  '  Logs are named here as numbers only. Nothing is rotated, truncated or deleted by this probe,'
Say  '  and a log the engine still has open is not a candidate in any case.'
Rule

Say 'VERDICT OF THE DISK READING'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  section 1 explains the failure by a shortage : ' + ($driveC.Free -le $needed))
Say  '  Sections 2 to 5 are an inventory, not a judgement: the cleanup list goes to the coordinator'
Say  '  and needs the operator word with the paths named. NOTHING WAS DELETED BY THIS RUN.'
Say '===== END-OF-RUN MARKER: DISKSPACE-COMPLETE ====='
Finish (-not (Test-TrapFired))
