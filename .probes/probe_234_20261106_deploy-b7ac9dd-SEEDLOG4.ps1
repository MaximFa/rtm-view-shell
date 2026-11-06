# deploy-b7ac9dd / SEEDLOG4.ps1 -- devops-1106, 2026-11-06. SEEDLOG3 (timers-1105, devops-1014) unchanged in method; the times are no longer
# typed in: T1 = the start of the running RTMService process (must be the pid the install reported), STOP = the last stamped line of
# RTM.log before T1 (the old engine's last write), SEEDEND = T1 + 128 s (as SEEDLOG3: 21:11:22 -> 21:13:30). READ ONLY.
# Question (coordinator 2026-11-06T17:32:26Z, rollback sign 'timers reset'): in the seed burst after the engine start, does each agent get its REAL status moment?
# EXPECT: many different StatusChanged values; for an agent whose status did not change, seed StatusChanged = its last pre-stop
# StatusChanged within seconds; none later than the log line. FAILURE SIGN: (almost) all seed StatusChanged ~ T1.
param([string]$Detail, [int]$ExpectedPid)
$svcs = @(Get-CimInstance Win32_Service -Filter "Name='RTMService'")
if ($svcs.Count -ne 1) { 'STOP: service count is not exactly 1'; return }
$exe = ($svcs[0].PathName -replace '^\s*"([^"]+)".*$','$1' -replace '^\s*(\S+\.exe).*$','$1')
$EngineDir = Split-Path $exe -Parent
if ($EngineDir -notlike 'C:\RTMView\*') { 'STOP: engine dir not under C:\RTMView\'; return }
$cfg = [IO.File]::ReadAllText((Join-Path $EngineDir 'appsettings.json')) | ConvertFrom-Json
$LogDir = [string]$cfg.RTM.LogConfig
$proc = Get-Process -Id $svcs[0].ProcessId -ErrorAction SilentlyContinue
if (-not $proc) { 'STOP: engine process not found'; return }
'engine pid ' + $svcs[0].ProcessId + ' (expected ' + $ExpectedPid + ') started ' + $proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss')
if ($ExpectedPid -and ($svcs[0].ProcessId -ne $ExpectedPid)) { 'STOP: the engine restarted since the install - this probe measures the install restart only'; return }
$startStamp = $proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss'); $DAY = $proc.StartTime.ToString('yyyy-MM-dd'); $SEEDEND = $proc.StartTime.AddSeconds(128).ToString('yyyy-MM-dd HH:mm:ss')
$files = @(Get-Item -LiteralPath (Join-Path $LogDir 'RTM.log'))   # today's file, read by NAME, never by LastWriteTime
'files: ' + ($files.Name -join ',')
$STOP = $null
$fs0 = [IO.File]::Open($files[0].FullName, 'Open', 'Read', 'ReadWrite'); $sr0 = New-Object IO.StreamReader($fs0)
try { while ($null -ne ($logLine = $sr0.ReadLine())) { if ($logLine -match ('^(' + $DAY + ' \d\d:\d\d:\d\d),')) { if ($Matches[1] -lt $startStamp) { $STOP = $Matches[1] } } } } finally { $sr0.Dispose(); $fs0.Dispose() }
if (-not $STOP) { 'STOP: no stamped line before the engine start - the reader is blind'; return }
'T1 (engine start) ' + $startStamp + ' ; STOP (last line of the old engine) ' + $STOP + ' ; SEEDEND ' + $SEEDEND
$pre = @{}; $seed = @{}; $lines = 0
$fmt = 'dd/MM/yyyy HH:mm:ss'; $culture = [Globalization.CultureInfo]::InvariantCulture
foreach ($logFile in $files) {
  $fileStream = [IO.File]::Open($logFile.FullName, 'Open', 'Read', 'ReadWrite'); $reader = New-Object IO.StreamReader($fileStream)
  try { while ($null -ne ($logLine = $reader.ReadLine())) {
    if ($logLine -notmatch ('^(' + $DAY + ' \d\d:\d\d:\d\d),\d+ .*userStatusChanged: userId=(\S+) .*statusId=(.*?) statusName=.*StatusChanged=(\d\d/\d\d/\d{4} \d\d:\d\d:\d\d)')) { continue }
    $lines++; $lineStamp = $Matches[1]; $userId = $Matches[2]; $statusText = $Matches[3]; $changedText = $Matches[4]
    if ($lineStamp -lt $STOP) { $pre[$userId] = @($changedText, $statusText) }
    elseif ($lineStamp -ge $startStamp -and $lineStamp -le $SEEDEND) { if (-not $seed.ContainsKey($userId)) { $seed[$userId] = @($changedText, $statusText, $lineStamp) } }
  } } finally { $reader.Dispose(); $fileStream.Dispose() }
}
$t1d = [datetime]::ParseExact($startStamp, 'yyyy-MM-dd HH:mm:ss', $culture)
$distinct = @($seed.Values | ForEach-Object { $_[0] } | Sort-Object -Unique).Count
$atRestart = 0; $later = 0; $same = 0; $sameWithin5 = 0; $sameStatusPairs = 0
foreach ($userId in $seed.Keys) {
  $seedTime = [datetime]::ParseExact($seed[$userId][0], $fmt, $culture); $lineTime = [datetime]::ParseExact($seed[$userId][2], 'yyyy-MM-dd HH:mm:ss', $culture)
  if ($seedTime -ge [datetime]::ParseExact($STOP, 'yyyy-MM-dd HH:mm:ss', $culture) -and $seedTime -le [datetime]::ParseExact($SEEDEND, 'yyyy-MM-dd HH:mm:ss', $culture)) { $atRestart++ }
  if ($seedTime -gt $lineTime.AddSeconds(1)) { $later++ }
  if ($pre.ContainsKey($userId) -and $pre[$userId][1] -eq $seed[$userId][1]) { $sameStatusPairs++; $preTime = [datetime]::ParseExact($pre[$userId][0], $fmt, $culture); if ([math]::Abs(($seedTime - $preTime).TotalSeconds) -le 5) { $sameWithin5++ } }
}
'userStatusChanged lines today : ' + $lines + '   (POSCTL, must be > 0)'
'users with an event before the stop ' + $STOP + ' : ' + $pre.Count
'users in the seed burst ' + $startStamp + '..' + $SEEDEND + ' : ' + $seed.Count + '   (expected about the logged-in agents)'
'distinct seed StatusChanged values : ' + $distinct + '   (expected many; 1-2 = everyone stamped at the restart)'
'seed StatusChanged inside the outage+seed window [STOP, SEEDEND] : ' + $atRestart + '   (FAILURE SIGN if about all; expected only agents whose status really changed then)'
'seed StatusChanged later than its own log line : ' + $later + '   (expected 0)'
'same status before and in the seed : ' + $sameStatusPairs + ' ; of them seed StatusChanged = last pre-stop StatusChanged within 5 s : ' + $sameWithin5 + '   (expected about all)'
if ($Detail) {
  $rows = @('user;pre_StatusChanged;pre_status;seed_StatusChanged;seed_status;seed_line')
  foreach ($userId in ($seed.Keys + $pre.Keys | Sort-Object -Unique)) { $preField = $(if ($pre.ContainsKey($userId)) { $pre[$userId] -join ';' } else { ';' }); $seedField = $(if ($seed.ContainsKey($userId)) { $seed[$userId] -join ';' } else { ';;' }); $rows += "$userId;$preField;$seedField" }
  [IO.File]::WriteAllLines($Detail, $rows, (New-Object System.Text.UTF8Encoding($false)))
  'detail (with logins) written to the measurement file only: ' + $Detail
}
'END'
