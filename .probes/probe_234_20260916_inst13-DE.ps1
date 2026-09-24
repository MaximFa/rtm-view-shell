#Requires -Version 5.1
<#
  PROBE 234 / inst13-DE              PR234-INST-13 acceptance on 234 - STEPS 1 (D) and 2 (E), then step 4.
  WHERE IT RUNS : server 234 (hostname "RTM"). Anything else aborts.
  SERVICES      : RTMService and RTMViewShell are STOPPED AND STARTED BY THE SUBJECT SCRIPT in E (that is the
                  test). D must not touch them. RTMTwilio_1 is never touched by hand - the engine owns it.
  DATABASE      : rtmviewdb on 5433 READ ONLY (fingerprint F vs F0). The subject is pointed at port 1 in E.
  WRITES        : C:\RTMView-Ops\inst13dry_<stamp>\ (child logs, removed at the end), C:\RTMView-Ops\output\
  ORDER         : D; E ONLY IF D is GREEN and liveness is green; any RED -> R1 by this box, then stop.
  E2            : NOT in this box (composition D/E). Unit then needs the coordinator's deferral of E2.
  Plan          : tools/plan_234_inst13_dry_ADE.md (section-4 PASS). Step 0: .measurements/234_20260916_181430_inst13-step0.txt
  Author        : devops-0916, 2026-09-16.
#>
param([string]$Stamp = '20260916_181430')
$ErrorActionPreference = 'Continue'
$SENTINEL = -999
$SUBJ_SHA = '7EF750E83D8A6146ED39FF3C3041DC666F120BCD1CA2FBF5AABF715DB69E9CC0'
$NOW = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OPS = 'C:\RTMView-Ops'
$OUT = Join-Path $OPS 'output'
$BK = Join-Path $OPS ('backup\inst13_' + $Stamp)
$DRY = Join-Path $OPS ('inst13dry_' + $Stamp)
$PKG = Join-Path $DRY 'pkg'
$ROOT = Join-Path $DRY 'root'
$SCRIPT = Join-Path $PKG 'Update-RTMView.ps1'
$REPORT = Join-Path $OUT ('234_' + $NOW + '_inst13-DE.txt')
$PGBIN = 'C:\Program Files\PostgreSQL\18\bin'
$PIPE = 'rtmpipe_v3'
$ENG = 'http://127.0.0.1:8089/'
$SHH = 'https://localhost:8444/health'
$Lines = New-Object System.Collections.ArrayList
function Say($t) { [void]$Lines.Add([string]$t); Write-Host $t }
function Flush { try { New-Item -ItemType Directory -Path $OUT -Force | Out-Null; [IO.File]::WriteAllLines($REPORT, [string[]]$Lines, (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('report write failed: ' + $_) } }
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL }; return @($c).Count }
function Has($t, $n) { return ($t.IndexOf($n, [StringComparison]::Ordinal) -ge 0) }
function Snap($n) {
    $w = Get-CimInstance Win32_Service -Filter ("Name='" + $n + "'") -ErrorAction SilentlyContinue
    if ($null -eq $w) { return [pscustomobject]@{ Name=$n; State='ABSENT'; Pid=0; Start='-' } }
    $st = '-'; if ($w.ProcessId -gt 0) { $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if ($p) { $st = $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } }
    return [pscustomobject]@{ Name=$n; State=[string]$w.State; Pid=[int]$w.ProcessId; Start=$st }
}
function Show3($label) {
    $r = @{}
    foreach ($n in @('RTMService','RTMViewShell','RTMTwilio_1')) { $s = Snap $n; $r[$n] = $s; Say ('  {0,-6} {1,-13} state={2,-8} pid={3,-6} StartTime={4}' -f $label, $s.Name, $s.State, $s.Pid, $s.Start) }
    return $r
}
function Live {
    $pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
    $p = @($pipes | Where-Object { $_ -eq $PIPE }).Count
    $e = & curl.exe -s -o NUL -w '%{http_code}' --max-time 5 $ENG
    $h = & curl.exe -k -s -o NUL -w '%{http_code}' --max-time 5 $SHH
    $t = (Snap 'RTMTwilio_1').State
    $ok = ($pipes.Count -gt 0) -and ($p -eq 1) -and ("$e" -ne '000') -and ("$h" -eq '200') -and ($t -eq 'Running')
    return [pscustomobject]@{ Ok=$ok; Line=('pipes {0} | {1} {2} | engine 8089 http {3} (want != 000; no /health route in the engine) | shell /health {4} (want 200) | RTMTwilio_1 {5}' -f $pipes.Count, $PIPE, $p, $e, $h, $t) }
}
function WaitLive($sec) {
    $t0 = Get-Date
    while ($true) { $l = Live; if ($l.Ok) { return [pscustomobject]@{ Ok=$true; Sec=[int]((Get-Date)-$t0).TotalSeconds; Line=$l.Line } }; if (((Get-Date)-$t0).TotalSeconds -ge $sec) { return [pscustomobject]@{ Ok=$false; Sec=$sec; Line=$l.Line } }; Start-Sleep -Seconds 3 }
}
function Fp {
    $sql = Join-Path $BK 'F0.sql'
    $r = & (Join-Path $PGBIN 'psql.exe') -h 127.0.0.1 -p 5433 -U postgres -d rtmviewdb -At -F '=' -v ON_ERROR_STOP=1 -f $sql 2>&1
    return [pscustomobject]@{ Rc=$LASTEXITCODE; Text=((@($r) | ForEach-Object { "$_" }) -join '|') }
}
function R1($why) {
    Say ''; Say ('--- R1 (performed by the box): ' + $why + ' ---')
    if ((Snap 'RTMService').State -ne 'Running') { Start-Service RTMService -ErrorAction SilentlyContinue; Say '  Start-Service RTMService issued' }
    $t0 = Get-Date
    while (((Get-Date)-$t0).TotalSeconds -lt 180) { $pp = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) } | Where-Object { $_ -eq $PIPE }).Count; if ($pp -eq 1) { break }; Start-Sleep 3 }
    if ((Snap 'RTMViewShell').State -ne 'Running') { Start-Service RTMViewShell -ErrorAction SilentlyContinue; Say '  Start-Service RTMViewShell issued' }
    $w = WaitLive 180
    Say ('  after R1: live={0} in {1}s | {2}' -f $w.Ok, $w.Sec, $w.Line)
    if (-not $w.Ok) { Say '  *** R1 did not restore liveness in 180 s. RTMTwilio_1 is NOT started by hand - tell the coordinator.' }
}
function Run-Child($tag, $h) {
    $log = Join-Path $OUT ('234_' + $NOW + '_inst13-' + $tag + '-child.txt')
    $so = Join-Path $DRY ('so_' + $tag + '.txt'); $se = Join-Path $DRY ('se_' + $tag + '.txt')
    $wrap = Join-Path $DRY ('wrap_' + $tag + '.ps1'); $argFile = Join-Path $DRY ('args_' + $tag + '.json')
    $body = @'
param([string]$Script, [string]$ArgFile)
$a = @{}
(ConvertFrom-Json ([IO.File]::ReadAllText($ArgFile))).psobject.Properties | ForEach-Object { if ($_.Value -is [bool]) { $a[$_.Name] = [switch]$_.Value } else { $a[$_.Name] = [string]$_.Value } }
try { & $Script @a; Write-Host 'CHILD RETURNED NORMALLY'; exit 0 }
catch { Write-Host ('CHILD THREW: ' + $_.Exception.Message); exit 1 }
'@
    [IO.File]::WriteAllText($wrap, $body, (New-Object Text.UTF8Encoding($true)))
    [IO.File]::WriteAllText($argFile, (ConvertTo-Json $h -Compress), (New-Object Text.UTF8Encoding($false)))
    $argv = '-NoProfile -ExecutionPolicy Bypass -File "' + $wrap + '" -Script "' + $SCRIPT + '" -ArgFile "' + $argFile + '"'
    $t0 = Get-Date
    $p = Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argv -Wait -PassThru -NoNewWindow -RedirectStandardOutput $so -RedirectStandardError $se
    $sec = [int]((Get-Date)-$t0).TotalSeconds
    $t1 = ''; $t2 = ''; if (Test-Path $so) { $t1 = [IO.File]::ReadAllText($so) }; if (Test-Path $se) { $t2 = [IO.File]::ReadAllText($se) }
    $text = $t1 + "`r`n----- STDERR -----`r`n" + $t2
    [IO.File]::WriteAllText($log, $text, (New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Rc=$p.ExitCode; Log=$log; Text=$text; Sec=$sec }
}

Say '===== PROBE 234 / inst13-DE ====='
Say ('WHERE IT RUNS : ' + $env:COMPUTERNAME + ' (want RTM) | PS ' + $PSVersionTable.PSVersion + ' ' + $PSVersionTable.PSEdition + ' | now ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz') + ' | step0 stamp ' + $Stamp)
Say 'R1 (printed before any write): Start-Service RTMService ; wait pipe rtmpipe_v3 ; Start-Service RTMViewShell ; wait shell /health 200 ; RTMTwilio_1 never by hand'
Say 'EXPECT D : child throws [PREFLIGHT], log has [FAIL] missing migrations, NO "[ 1/5 ] Stopping services", StartTime RTMService+RTMViewShell UNCHANGED, live, F == F0'
Say 'EXPECT E : child throws [DB Backup] pg_dump failed, [RECOVERY] Deploy failed before DB changes, RTMService+RTMViewShell StartTime CHANGED, RTMService <= RTMViewShell, live within 180 s, F == F0'
Say ''
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('self-gate Safe-Count {0}/{1}/{2} (want {3}/0/2) | Has NEGCTL {4} POSCTL {5}' -f $gA, $gB, $gC, $SENTINEL, (Has 'abc' 'zz'), (Has 'abc' 'b'))
$V = @{ D='NOT RUN'; E='NOT RUN' }
function Stop-Box($why) { Say ''; Say ('*** STOP: ' + $why); Say ('RESULT : D={0} | E={1} | E2=NOT IN THIS BOX' -f $V.D, $V.E); Say 'LAST LINE: FAIL'; Say '===== END ====='; Flush; Write-Host ('report : ' + $REPORT); exit 2 }
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2)) -or (Has 'abc' 'zz') -or -not (Has 'abc' 'b')) { Stop-Box 'self-gate broken' }
if ($env:COMPUTERNAME -ne 'RTM') { Stop-Box 'not 234' }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Stop-Box 'not elevated' }
if ($PSVersionTable.PSEdition -ne 'Desktop') { Stop-Box 'not Windows PowerShell 5.1' }

# ---- entry checks ----
Say '--- entry ---'
foreach ($p in @($SCRIPT, (Join-Path $BK 'F0.txt'), (Join-Path $BK 'F0.sql'), (Join-Path $BK 'cfg_manifest.txt'), (Join-Path $BK 'rtmviewdb.dump'))) { $e = Test-Path -LiteralPath $p; Say ('  exists {0} : {1}' -f $p, $e); if (-not $e) { Stop-Box ('missing ' + $p) } }
$ss = (Get-FileHash -LiteralPath $SCRIPT -Algorithm SHA256).Hash
Say ('  staged subject sha256 == reviewed : ' + ($ss -eq $SUBJ_SHA)); if ($ss -ne $SUBJ_SHA) { Stop-Box 'staged subject changed' }
$pk = @(Get-ChildItem -LiteralPath $PKG -Force).Count; $rt = @(Get-ChildItem -LiteralPath $ROOT -Force).Count
Say ('  pkg entries {0} (want 1) | root entries {1} (want 0)' -f $pk, $rt); if ($pk -ne 1 -or $rt -ne 0) { Stop-Box 'staging not bare' }
$F0 = ((Get-Content -LiteralPath (Join-Path $BK 'F0.txt') -Encoding UTF8) -join '|')
Say ('  F0 : ' + $F0)
$sec = Read-Host -AsSecureString 'postgres password for 127.0.0.1:5433 (fingerprint only)'
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
Say ('  password length : ' + $pw.Length); if ($pw.Length -eq 0) { Stop-Box 'empty password' }
$env:PGPASSWORD = $pw; $pw = $null
$f = Fp; Say ('  F now rc={0} == F0 : {1}' -f $f.Rc, ($f.Text -eq $F0)); if ($f.Rc -ne 0 -or $f.Text -ne $F0) { Stop-Box 'fingerprint differs before start' }
$l = Live; Say ('  live on entry : ' + $l.Ok + ' | ' + $l.Line); if (-not $l.Ok) { Stop-Box 'not live on entry' }

# ---- D ----
& {
    Say ''; Say '--- STEP 1 : D (preflight failure must not touch services) ---'
    $b = Show3 'BEFORE'
    $r = Run-Child 'D' @{ InstallRoot=$ROOT; SkipDrift=$true; SkipCacheMigration=$true; DBHost='127.0.0.1'; DBPort='5433'; Database='rtmviewdb'; KeepBackups='50'; MigrationList='20260101_001_nonexistent' }
    $a = Show3 'AFTER'
    $pos = Has $r.Text 'RTM View Shell - UPDATE'
    Say ('  child rc={0} in {1}s log={2} | log POSCTL banner {3} | NEGCTL {4}' -f $r.Rc, $r.Sec, $r.Log, $pos, (Has $r.Text 'ThisMarkerMustNotExist_inst13'))
    $c1 = Has $r.Text '[PREFLIGHT] One or more prerequisites failed'
    $c2 = Has $r.Text '[FAIL] missing migrations'
    $c3 = -not (Has $r.Text '[ 1/5 ] Stopping services')
    $c4 = ($b['RTMService'].Start -eq $a['RTMService'].Start) -and ($b['RTMViewShell'].Start -eq $a['RTMViewShell'].Start)
    $lv = Live; $fp = Fp
    Say ('  [PREFLIGHT] {0} | [FAIL] missing migrations {1} | no stop line {2} | StartTime unchanged {3} | live {4} | F==F0 {5}' -f $c1, $c2, $c3, $c4, $lv.Ok, ($fp.Text -eq $F0))
    Say ('  live : ' + $lv.Line)
    if (-not $pos) { $script:V.D = 'NOT RUN (child log not captured)' }
    elseif ($c1 -and $c2 -and $c3 -and $c4 -and $lv.Ok -and ($fp.Text -eq $F0)) { $script:V.D = 'GREEN' } else { $script:V.D = 'RED' }
}
Say ('D : ' + $V.D)
if ($V.D -ne 'GREEN') { if (-not (Live).Ok) { R1 'D not green and not live' }; Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue; Stop-Box 'D is not GREEN - E not run' }

# ---- E ----
& {
    Say ''; Say '--- STEP 2 : E (throw after stop, before DB change -> automatic recovery) ---'
    $b = Show3 'BEFORE'
    $r = Run-Child 'E' @{ InstallRoot=$ROOT; SkipDrift=$true; SkipCacheMigration=$true; DBHost='127.0.0.1'; DBPort='1'; Database='rtmviewdb'; KeepBackups='50'; MigrationList='' }
    $w = WaitLive 180
    $a = Show3 'AFTER'
    $pos = Has $r.Text 'RTM View Shell - UPDATE'
    Say ('  child rc={0} in {1}s log={2} | log POSCTL banner {3}' -f $r.Rc, $r.Sec, $r.Log, $pos)
    $c1 = Has $r.Text '[DB Backup] pg_dump failed'
    $c2 = Has $r.Text '[RECOVERY] Deploy failed before DB changes'
    $c5 = Has $r.Text '[ 1/5 ] Stopping services'
    $c3 = ($a['RTMService'].Start -ne $b['RTMService'].Start) -and ($a['RTMViewShell'].Start -ne $b['RTMViewShell'].Start) -and ($a['RTMService'].Start -ne '-') -and ($a['RTMViewShell'].Start -ne '-')
    $c4 = ($a['RTMService'].Start -ne '-') -and ($a['RTMViewShell'].Start -ne '-') -and ($a['RTMService'].Start -le $a['RTMViewShell'].Start)
    $fp = Fp
    Say ('  stop line {0} | pg_dump failed {1} | [RECOVERY] {2} | StartTime both changed {3} | RTMService<=Shell {4} ({5} vs {6}) | live {7} after {8}s | F==F0 {9}' -f $c5, $c1, $c2, $c3, $c4, $a['RTMService'].Start, $a['RTMViewShell'].Start, $w.Ok, $w.Sec, ($fp.Text -eq $F0))
    Say ('  live : ' + $w.Line)
    if (-not $pos) { $script:V.E = 'NOT RUN (child log not captured)' }
    elseif ($c5 -and $c1 -and $c2 -and $c3 -and $c4 -and $w.Ok -and ($fp.Text -eq $F0)) { $script:V.E = 'GREEN' } else { $script:V.E = 'RED' }
    if (-not $w.Ok) { R1 'E: liveness not back in 180 s' }
}
Say ('E : ' + $V.E)
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue

# ---- step 4 ----
Say ''; Say '--- STEP 4 : after ---'
$man = Get-Content -LiteralPath (Join-Path $BK 'cfg_manifest.txt') -Encoding UTF8
$cfgOk = $true
foreach ($m in $man) { if ($m -like 'ABSENT *') { continue }; $h = $m.Substring(0,64); $p = $m.Substring(65); $n = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash; if ($n -ne $h) { $cfgOk = $false }; Say ('  cfg {0} unchanged {1}' -f $p, ($n -eq $h)) }
foreach ($pair in @(@('C:\RTMView\RTM\RTM.dll','621a797'), @('C:\RTMView\Shell\CcDashboard.Web.dll','621a797'), @('C:\RTMView\RTM.Twilio\RTM.Twilio.dll','8d28531'))) { $pv = (Get-Item -LiteralPath $pair[0]).VersionInfo.ProductVersion; Say ('  {0} +{1} : {2}' -f $pair[0], $pair[1], ($pv -like ('*+' + $pair[1] + '*'))) }
$bk = @(Get-ChildItem -LiteralPath (Join-Path $ROOT 'Backup') -Directory -ErrorAction SilentlyContinue).Count
Say ('  scratch root Backup dirs created by the subject : ' + $bk + ' (E creates 1; C:\RTMView\Backup is not its target)')
$final = WaitLive 60; Say ('  final live {0} | {1}' -f $final.Ok, $final.Line)
try { [IO.Directory]::Delete($DRY, $true); Say ('  staging removed : ' + (-not (Test-Path -LiteralPath $DRY)) + ' (' + $DRY + ')') } catch { Say ('  staging NOT removed: ' + $_) }
Say ('  backups KEPT : ' + $BK)
Say ''
Say ('RESULT : D={0} | E={1} | E2=NOT IN THIS BOX (composition D/E) | configs unchanged {2}' -f $V.D, $V.E, $cfgOk)
Say ('UNIT   : ' + $(if ($V.D -eq 'GREEN' -and $V.E -eq 'GREEN' -and $cfgOk) { 'NEEDS COORDINATOR DEFERRAL OF E2 (A, D, E green)' } else { 'NOT CLOSABLE' }))
Say ('LAST LINE: ' + $(if ($V.D -eq 'GREEN' -and $V.E -eq 'GREEN' -and $cfgOk -and $final.Ok) { 'PASS' } else { 'FAIL' }))
Say '===== END ====='
Flush
Write-Host ''; Write-Host ('report : ' + $REPORT)
