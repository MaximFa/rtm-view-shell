# deploy-b7ac9dd / ENGLOG.ps1 -- devops-1106, 2026-11-06: deploy-prep-1104/ENGLOG.ps1 (devops-1014) with words for variable names, method unchanged. READ ONLY on 234. After the b7ac9dd install.
# Why: the install probe's 2j read 0 engine log lines since the start (blind: its POSCTL is 0), and its "before" number was
# 32423 exception lines in 32668 stamped lines of the last 60 min. This reads the engine log by 10-min buckets, before and after
# the engine start, with the exception kinds counted - names of exception types only, no message text (lines carry logins).
$rtmConfig = [IO.File]::ReadAllText('C:\RTMView\RTM\appsettings.json') | ConvertFrom-Json; $logDir = [string]$rtmConfig.RTM.LogConfig
$eng = Get-CimInstance Win32_Service -Filter "Name='RTMService'"; $start = (Get-Process -Id $eng.ProcessId).StartTime
'log dir: ' + $logDir + ' ; engine pid ' + $eng.ProcessId + ' started ' + $start.ToString('s')
$files = @(Get-ChildItem -LiteralPath $logDir -File | Where-Object { $_.Name -like 'RTM*' } | Sort-Object LastWriteTime)
'files in the log dir named RTM*: ' + $files.Count
foreach ($logFile in ($files | Select-Object -Last 6)) { '  ' + $logFile.Name.PadRight(40) + ' ' + $logFile.Length + ' B  written ' + $logFile.LastWriteTime.ToString('s') }
$from = $start.AddHours(-2); $buckets = @{}; $kinds = @{}; $all = 0; $stamped = 0
foreach ($logFile in @($files | Where-Object { $_.LastWriteTime -ge $from })) {
  $fileStream = [IO.File]::Open($logFile.FullName, 'Open', 'Read', 'ReadWrite'); $reader = New-Object IO.StreamReader($fileStream)
  try { while ($null -ne ($logLine = $reader.ReadLine())) { $all++
    $stampMatch = [regex]::Match($logLine, '^\s*(\d{4}-\d\d-\d\d \d\d:\d\d):\d\d'); if (-not $stampMatch.Success) { continue }; $lineTime = [datetime]::ParseExact($stampMatch.Groups[1].Value, 'yyyy-MM-dd HH:mm', $null)
    if ($lineTime -lt $from) { continue }; $stamped++
    $key = $lineTime.AddMinutes(-($lineTime.Minute % 10)).ToString('HH:mm'); if (-not $buckets[$key]) { $buckets[$key] = @(0,0) }; $buckets[$key][0]++
    if ($logLine -match '(?i)exception') { $buckets[$key][1]++; $side = $(if ($lineTime -ge $start.AddSeconds(-$start.Second)) { 'after' } else { 'before' })
      foreach ($entry in [regex]::Matches($logLine, '\b(\w+Exception)\b')) { $kindKey = $side + ' ' + $entry.Groups[1].Value; $kinds[$kindKey] = 1 + [int]$kinds[$kindKey] } } } }
  finally { $reader.Dispose(); $fileStream.Dispose() } }
'lines read ' + $all + ' ; stamped since ' + $from.ToString('HH:mm') + ' : ' + $stamped + '   (POSCTL: > 0 means the reader sees the log)'
'10-min buckets (local): stamped lines / lines with "exception"   (engine start ' + $start.ToString('HH:mm:ss') + ')'
foreach ($entry in ($buckets.Keys | Sort-Object)) { '  ' + $entry + '  ' + ([string]$buckets[$entry][0]).PadLeft(7) + ' / ' + ([string]$buckets[$entry][1]).PadLeft(7) }
'exception type names, before / after the start:'
foreach ($entry in ($kinds.Keys | Sort-Object { -$kinds[$_] } | Select-Object -First 12)) { '  ' + $entry.PadRight(60) + ' ' + $kinds[$entry] }
'END'
