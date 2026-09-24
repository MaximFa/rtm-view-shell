#Requires -Version 5.1
<#
  PROBE DEV / inst13-dry-ADE        dry acceptance of PR234-INST-13 (preflight + recovery wrapper).
  WHERE IT RUNS : the operator's DEV stand ONLY. NOT server 234 (hostname "RTM" is refused).
  WHAT IT WRITES: a temp root under $env:TEMP (removed at the end), C:\RTMView-Ops\output\ (report + child
                  logs), and - ONLY for E2, ONLY if -ScratchDb is given - one table in that scratch database.
  WHAT IT STOPS : the TWO stand-in services the operator names (-StandInRTM, -StandInShell). Nothing else.
                  No production service name is accepted.
  DATABASE      : none for A / D / E. For E2 only the scratch database named by the operator.

  Subject : v3:deploy/Update-RTMView.ps1, blob cf619dbbafaa7d3c2fc7257e37dc5f95defb6dd7 (commit 8b3da25).
  Spec    : tools/procedure_inst13_dry_ADE.md (blob a2362143, coordinator section-4 PASS 2026-09-16).
  Author  : devops-0916, 2026-09-16. Re-issue: whether the previous issuance ever ran is unknown
            (operator 2026-09-16: "I don't know") - so this run is treated as the first.

  TWO DEVIATIONS FROM THE SPEC, both measured, both declared here and not hidden in the code:
   1. D: the spec hides psql by stripping PATH. That cannot work: Find-PGTool searches the fixed
      "C:\Program Files\PostgreSQL\<14..18>\bin" folders BEFORE PATH (Update-RTMView.ps1 lines 76-92).
      On a DEV stand with PostgreSQL installed, psql stays found and D would falsely PASS preflight.
      D here fails preflight through a MIGRATION FILE THAT DOES NOT EXIST ("[FAIL] missing migrations"),
      which does not depend on what is installed.
   2. A: the file is parsed in the form it SHIPS in, not the raw blob. Build-ProdRelease.ps1 lines 453-460
      re-encode every .ps1 to UTF-8 with BOM + CRLF before zipping; the blob itself has no BOM and 19
      non-ASCII lines. The raw-blob parse is printed too, as information, not as the verdict.

  WHAT THIS DOES NOT PROVE (said before the numbers): that the real deploy works; that production services
  behave like the stand-ins; anything at all about 234.

  RUN (elevated Windows PowerShell 5.1):
    Get-ChildItem C:\RTMView-Ops\incoming\*.ps1 | Unblock-File
    powershell -ExecutionPolicy Bypass -File C:\RTMView-Ops\incoming\<this file> -StandInRTM <svc> -StandInShell <svc> [-ScratchDb <db> -DbPort <port> -DbUser <user>]
#>
[CmdletBinding()]
param(
    [string]$Clone = "D:\Claude\Projects\RTM View Shell",
    [string]$StandInRTM = "",
    [string]$StandInShell = "",
    [string]$ScratchDb = "",
    [string]$DbHost = "127.0.0.1",
    [string]$DbPort = "5432",
    [string]$DbUser = "postgres"
)

$ErrorActionPreference = 'Continue'
$SENTINEL = -999
$BLOB = 'cf619dbbafaa7d3c2fc7257e37dc5f95defb6dd7'
$STAMP = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OUT = 'C:\RTMView-Ops\output'
$WORK = Join-Path $env:TEMP ('inst13dry_' + $STAMP)
$PKG = Join-Path $WORK 'pkg'
$ROOT = Join-Path $WORK 'root'
$REPORT = Join-Path $OUT ('DEV_' + $STAMP + '_inst13-dry-ADE.txt')
$FORBID = @('RTMService','RTMViewShell','RTMTwilio_1','RTM.Twilio','RTM','RTMApplyService','Garnet','Memurai','RTM.Bot')

$Lines = New-Object System.Collections.ArrayList
function Say($t) { [void]$Lines.Add([string]$t); Write-Host $t }
function Flush { try { if (-not (Test-Path $OUT)) { New-Item -ItemType Directory -Path $OUT -Force | Out-Null }; [IO.File]::WriteAllLines($REPORT, [string[]]$Lines, (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('  *** report write failed: ' + $_) } }
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL }; return @($c).Count }
function Abort($why) { Say ''; Say ('*** ABORT: ' + $why); Say 'LAST LINE: FAIL (box did not complete - nothing below was measured)'; Say '===== END ====='; Flush; Write-Host ('report: ' + $REPORT); exit 2 }

function Svc-Snap($name) {
    $w = Get-CimInstance Win32_Service -Filter ("Name='" + $name + "'") -ErrorAction SilentlyContinue
    if ($null -eq $w) { return [pscustomobject]@{ Name=$name; State='ABSENT'; Pid=0; Start='-' } }
    $st = '-'
    if ($w.ProcessId -gt 0) { $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if ($p) { $st = $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } }
    return [pscustomobject]@{ Name=$name; State=[string]$w.State; Pid=[int]$w.ProcessId; Start=$st }
}
function Show($label, $s) { Say ('  {0,-7} {1,-28} state={2,-8} pid={3,-6} StartTime={4}' -f $label, $s.Name, $s.State, $s.Pid, $s.Start) }

function Run-Child($tag, [string[]]$argList, $pw) {
    # Child runs in its OWN process with PROCESS-level redirection. No PowerShell-level *>&1 / 2>&1:
    # under a PS redirection, native stderr (pg_dump/psql) becomes an ErrorRecord and the subject's
    # $ErrorActionPreference = "Stop" would throw BEFORE its own $LASTEXITCODE check - the harness would
    # change the behaviour it measures (role-devops B 2026-08-29).
    $log = Join-Path $OUT ('DEV_' + $STAMP + '_inst13-' + $tag + '-child.txt')
    $so = Join-Path $WORK ('so_' + $tag + '.txt'); $se = Join-Path $WORK ('se_' + $tag + '.txt')
    $wrap = Join-Path $WORK ('wrap_' + $tag + '.ps1')
    $body = @'
param([string]$Script, [string]$ArgFile)
$a = @{}
(ConvertFrom-Json ([IO.File]::ReadAllText($ArgFile))).psobject.Properties | ForEach-Object { if ($_.Value -is [bool]) { $a[$_.Name] = [switch]$_.Value } else { $a[$_.Name] = [string]$_.Value } }
if ($env:INST13_PW) { $a['DBPassword'] = $env:INST13_PW }
try { & $Script @a; Write-Host 'CHILD RETURNED NORMALLY'; exit 0 }
catch { Write-Host ('CHILD THREW: ' + $_.Exception.Message); exit 1 }
'@
    [IO.File]::WriteAllText($wrap, $body, (New-Object Text.UTF8Encoding($true)))
    $h = @{}
    for ($i = 0; $i -lt $argList.Count; $i += 2) { $h[$argList[$i]] = $argList[$i+1] }
    $argFile = Join-Path $WORK ('args_' + $tag + '.json')
    [IO.File]::WriteAllText($argFile, (ConvertTo-Json $h -Compress), (New-Object Text.UTF8Encoding($false)))
    if ($pw) { $env:INST13_PW = $pw } else { Remove-Item Env:\INST13_PW -ErrorAction SilentlyContinue }
    $argv = '-NoProfile -ExecutionPolicy Bypass -File "' + $wrap + '" -Script "' + $scriptPath + '" -ArgFile "' + $argFile + '"'
    $p = Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argv -Wait -PassThru -NoNewWindow -RedirectStandardOutput $so -RedirectStandardError $se
    Remove-Item Env:\INST13_PW -ErrorAction SilentlyContinue
    $t1 = ''; $t2 = ''
    if (Test-Path $so) { $t1 = [IO.File]::ReadAllText($so) }
    if (Test-Path $se) { $t2 = [IO.File]::ReadAllText($se) }
    $text = $t1 + "`r`n----- STDERR -----`r`n" + $t2
    [IO.File]::WriteAllText($log, $text, (New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Rc = $p.ExitCode; Log = $log; Text = $text }
}
function Has($text, $needle) { return ($text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }

Say '===== PROBE DEV / inst13-dry-ADE ====='
Say ('WHERE IT RUNS : ' + $env:COMPUTERNAME + '  (must NOT be 234 "RTM")  | PS ' + $PSVersionTable.PSVersion + ' | now ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('WRITES        : ' + $WORK + ' (temp, removed) ; ' + $OUT + ' ; E2 only: scratch db "' + $ScratchDb + '"')
Say ('STOPS/STARTS  : stand-ins RTM="' + $StandInRTM + '" Shell="' + $StandInShell + '" - nothing else')
Say ''
Say 'EXPECTATIONS (named before any number):'
Say '  A  parse errors of the SHIPPED form (BOM+CRLF) = 0'
Say '  D  child throws "[PREFLIGHT]", log has "[FAIL] missing migrations", StartTime of BOTH stand-ins UNCHANGED (to the second), no "Stopping services" line'
Say '  E  child throws "[DB Backup] pg_dump failed", "[RECOVERY] Deploy failed before DB changes" printed, BOTH Running again, StartTime of BOTH CHANGED, RTM stand-in StartTime <= Shell stand-in'
Say '  E2 child throws "[DB Apply] Migration 20990101_002_inst13dry_bad failed", "MANUAL RECOVERY REQUIRED", backup dir + dump path + pg_restore line printed, BOTH stand-ins STOPPED, no "[RECOVERY]" line'
Say '  E2 may be NOT RUN (no -ScratchDb / no psql / db unreachable) - NOT RUN is never GREEN'
Say ''

# ---- self gates ----
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('self-gate Safe-Count : unassigned {0} (want {1}), empty {2} (want 0), two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Abort 'Safe-Count gate broken' }
Say ('self-gate Has        : NEGCTL {0} (want False), POSCTL {1} (want True)' -f (Has 'abc' 'zzz'), (Has 'abc' 'b'))
if ((Has 'abc' 'zzz') -or -not (Has 'abc' 'b')) { Abort 'Has() matcher broken' }

# ---- P0..P2 ----
Say ''
Say '--- PRECONDITIONS ---'
if ($env:COMPUTERNAME -eq 'RTM') { Abort 'this is server 234' }
Say ('P0 host ' + $env:COMPUTERNAME + ' is not "RTM" : OK')
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say ('P0b elevated : ' + $admin)
if (-not $admin) { Abort 'not elevated - Update-RTMView.ps1 requires Administrator' }
Say ('P0c edition : ' + $PSVersionTable.PSEdition + ' (want Desktop = Windows PowerShell 5.1, the edition 234 runs)')
if ($PSVersionTable.PSEdition -ne 'Desktop') { Abort 'run under Windows PowerShell 5.1, not pwsh' }
if (-not (Test-Path $OUT)) { New-Item -ItemType Directory -Path $OUT -Force | Out-Null }
if (-not $StandInRTM -or -not $StandInShell) { Abort 'give -StandInRTM and -StandInShell: two harmless OWN-PROCESS services on this stand that may be stopped and started' }
if ($StandInRTM -eq $StandInShell) { Abort 'the two stand-ins must be different services' }
foreach ($n in @($StandInRTM, $StandInShell)) {
    if ($FORBID -contains $n -or $n -like 'postgresql*') { Abort ('"' + $n + '" is a real/protected service name - refused') }
    $w = Get-CimInstance Win32_Service -Filter ("Name='" + $n + "'") -ErrorAction SilentlyContinue
    if ($null -eq $w) { Abort ('service "' + $n + '" not found') }
    $shared = @(Get-CimInstance Win32_Service | Where-Object { $_.ProcessId -eq $w.ProcessId -and $_.ProcessId -ne 0 })
    Say ('P1 {0}: state={1} type={2} startMode={3} acceptStop={4} pid={5} servicesOnPid={6}' -f $n, $w.State, $w.ServiceType, $w.StartMode, $w.AcceptStop, $w.ProcessId, $shared.Count)
    if ($w.State -ne 'Running') { Abort ('"' + $n + '" is not Running') }
    if (-not $w.AcceptStop) { Abort ('"' + $n + '" does not accept stop') }
    if ($w.StartMode -eq 'Disabled') { Abort ('"' + $n + '" is Disabled') }
    if ($shared.Count -ne 1) { Abort ('"' + $n + '" shares its process with other services - StartTime would not measure it') }
}
if (Test-Path $WORK) { Abort ('work dir already exists: ' + $WORK) }
New-Item -ItemType Directory -Path $PKG -Force | Out-Null
Set-Content -LiteralPath (Join-Path $WORK '.origin') -Value ('inst13-dry-ADE ' + $STAMP + ' ' + $env:COMPUTERNAME + ' blob ' + $BLOB) -Encoding ASCII
Say ('P2 temp root ' + $ROOT + ' exists=' + (Test-Path $ROOT) + ' (want False)')

# ---- extract the blob byte-exact and verify its object id ----
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) { Abort 'git not found' }
$psi = New-Object Diagnostics.ProcessStartInfo
$psi.FileName = $git.Source; $psi.Arguments = 'cat-file blob ' + $BLOB; $psi.WorkingDirectory = $Clone
$psi.RedirectStandardOutput = $true; $psi.UseShellExecute = $false
$gp = [Diagnostics.Process]::Start($psi); $ms = New-Object IO.MemoryStream
$gp.StandardOutput.BaseStream.CopyTo($ms); $gp.WaitForExit()
$raw = $ms.ToArray()
$hdr = [Text.Encoding]::ASCII.GetBytes('blob ' + $raw.Length + [char]0)
$sha = [Security.Cryptography.SHA1]::Create()
$oid = (($sha.ComputeHash([byte[]]([byte[]]$hdr + [byte[]]$raw)) | ForEach-Object { $_.ToString('x2') }) -join '')
Say ('P3 blob bytes={0} oid={1} want {2} -> {3}' -f $raw.Length, $oid, $BLOB, ($oid -eq $BLOB))
if ($oid -ne $BLOB) { Abort 'extracted script is not the subject blob' }
$txt = [Text.Encoding]::UTF8.GetString($raw)
$crlf = $txt -replace "`r`n", "`n" -replace "`n", "`r`n"
$shipped = [byte[]]([byte[]](0xEF,0xBB,0xBF) + [byte[]][Text.Encoding]::UTF8.GetBytes($crlf))
$scriptPath = Join-Path $PKG 'Update-RTMView.ps1'
[IO.File]::WriteAllBytes($scriptPath, $shipped)
$back = [IO.File]::ReadAllBytes($scriptPath)
Say ('P3b shipped form written: bytes={0} BOM={1} (want True)' -f $back.Length, (($back[0] -eq 0xEF) -and ($back[1] -eq 0xBB) -and ($back[2] -eq 0xBF)))

$pgDump = $null; $psql = $null; $pgRestore = $null
foreach ($v in @('18','17','16','15','14')) { $b = "C:\Program Files\PostgreSQL\$v\bin"; if (-not $pgDump -and (Test-Path "$b\pg_dump.exe")) { $pgDump = "$b\pg_dump.exe" }; if (-not $psql -and (Test-Path "$b\psql.exe")) { $psql = "$b\psql.exe" }; if (-not $pgRestore -and (Test-Path "$b\pg_restore.exe")) { $pgRestore = "$b\pg_restore.exe" } }
Say ('P4 pg_dump={0} psql={1} pg_restore={2}' -f $pgDump, $psql, $pgRestore)

$V = @{ A='NOT RUN (not reached)'; D='NOT RUN (not reached)'; E='NOT RUN (not reached)'; E2='NOT RUN (not reached)' }

# ---- A ----
& {
    Say ''; Say '--- A : parse ---'
    $e1 = $null; $t1 = $null
    [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$t1, [ref]$e1) | Out-Null
    $n1 = Safe-Count $e1
    $rawPath = Join-Path $WORK 'raw_blob_form.ps1'; [IO.File]::WriteAllBytes($rawPath, $raw)
    $e2 = $null; $t2 = $null
    [Management.Automation.Language.Parser]::ParseFile($rawPath, [ref]$t2, [ref]$e2) | Out-Null
    Say ('  shipped form (BOM+CRLF) parse errors : {0}   (expect 0)  <- VERDICT' -f $n1)
    Say ('  raw blob form (no BOM)  parse errors : {0}   (information only)' -f (Safe-Count $e2))
    if ($n1 -gt 0) { @($e1) | Select-Object -First 5 | ForEach-Object { Say ('    ' + $_.Extent.StartLineNumber + ': ' + $_.Message) } }
    $script:V.A = $(if ($n1 -eq 0) { 'GREEN' } else { 'RED (' + $n1 + ' parse errors)' })
}
Say ('A : ' + $V.A)
if ($V.A -ne 'GREEN') { Abort 'A red - an unparsable script cannot be dry-run' }

# ---- D ----
& {
    Say ''; Say '--- D : preflight failure must not touch services ---'
    $b1 = Svc-Snap $StandInRTM; $b2 = Svc-Snap $StandInShell
    Say '  BEFORE'; Show 'rtm' $b1; Show 'shell' $b2
    $r = Run-Child 'D' @('InstallRoot',$ROOT,'RTMSvcName',$StandInRTM,'ShellSvcName',$StandInShell,'SkipDrift',$true,'MigrationList','20260101_001_nonexistent','DBHost',$DbHost,'DBPort','1','Database','inst13dry_none') $null
    Start-Sleep -Seconds 2
    $a1 = Svc-Snap $StandInRTM; $a2 = Svc-Snap $StandInShell
    Say '  AFTER'; Show 'rtm' $a1; Show 'shell' $a2
    $posctl = Has $r.Text 'RTM View Shell - UPDATE'; $negctl = Has $r.Text 'ThisMarkerMustNotExist_inst13'
    Say ('  child rc={0} log={1} bytes={2}' -f $r.Rc, $r.Log, $r.Text.Length)
    Say ('  log POSCTL banner captured : {0} (want True) | NEGCTL : {1} (want False)' -f $posctl, $negctl)
    if (-not $posctl -or $negctl) { $script:V.D = 'NOT RUN (child log not captured - matchers cannot answer)'; return }
    $c1 = Has $r.Text '[PREFLIGHT] One or more prerequisites failed'; $c2 = Has $r.Text '[FAIL] missing migrations'; $c3 = -not (Has $r.Text '[ 1/5 ] Stopping services')
    $c4 = ($b1.Start -eq $a1.Start) -and ($b2.Start -eq $a2.Start) -and ($a1.State -eq 'Running') -and ($a2.State -eq 'Running')
    Say ('  throw [PREFLIGHT] {0} | [FAIL] missing migrations {1} | no stop line {2} | StartTime both unchanged {3}' -f $c1, $c2, $c3, $c4)
    $script:V.D = $(if ($c1 -and $c2 -and $c3 -and $c4) { 'GREEN' } else { 'RED' })
}
Say ('D : ' + $V.D)

# ---- E ----
& {
    Say ''; Say '--- E : throw after stop, before DB change -> recovery ---'
    if (-not $pgDump) { $script:V.E = 'NOT RUN (pg_dump not installed - preflight would fail before the stop)'; return }
    $b1 = Svc-Snap $StandInRTM; $b2 = Svc-Snap $StandInShell
    Say '  BEFORE'; Show 'rtm' $b1; Show 'shell' $b2
    if ($b1.State -ne 'Running' -or $b2.State -ne 'Running') { $script:V.E = 'NOT RUN (stand-ins not both Running on entry)'; return }
    $r = Run-Child 'E' @('InstallRoot',$ROOT,'RTMSvcName',$StandInRTM,'ShellSvcName',$StandInShell,'SkipDrift',$true,'MigrationList','','DBHost',$DbHost,'DBPort','1','Database','inst13dry_none') $null
    Start-Sleep -Seconds 5
    $a1 = Svc-Snap $StandInRTM; $a2 = Svc-Snap $StandInShell
    Say '  AFTER'; Show 'rtm' $a1; Show 'shell' $a2
    $posctl = Has $r.Text 'RTM View Shell - UPDATE'
    Say ('  child rc={0} log={1} | log POSCTL {2}' -f $r.Rc, $r.Log, $posctl)
    if (-not $posctl) { $script:V.E = 'NOT RUN (child log not captured)'; return }
    $c1 = Has $r.Text '[DB Backup] pg_dump failed'; $c2 = Has $r.Text '[RECOVERY] Deploy failed before DB changes'
    $c3 = ($a1.State -eq 'Running') -and ($a2.State -eq 'Running')
    $c4 = ($a1.Start -ne $b1.Start) -and ($a2.Start -ne $b2.Start) -and ($a1.Start -ne '-') -and ($a2.Start -ne '-')
    $c5 = ($a1.Start -ne '-') -and ($a2.Start -ne '-') -and ($a1.Start -le $a2.Start)
    Say ('  throw pg_dump {0} | [RECOVERY] {1} | both Running {2} | StartTime both changed {3} | rtm<=shell {4} ({5} vs {6})' -f $c1, $c2, $c3, $c4, $c5, $a1.Start, $a2.Start)
    $script:V.E = $(if ($c1 -and $c2 -and $c3 -and $c4 -and $c5) { 'GREEN' } else { 'RED' })
}
Say ('E : ' + $V.E)

# ---- E2 ----
& {
    Say ''; Say '--- E2 : throw after a migration began -> services stay stopped ---'
    if (-not $ScratchDb) { $script:V.E2 = 'NOT RUN (no -ScratchDb given)'; return }
    if ($ScratchDb -match 'rtm|^postgres$|^template') { $script:V.E2 = 'NOT RUN (scratch db name "' + $ScratchDb + '" refused)'; return }
    if (-not $psql -or -not $pgDump) { $script:V.E2 = 'NOT RUN (psql or pg_dump not installed)'; return }
    $b1 = Svc-Snap $StandInRTM; $b2 = Svc-Snap $StandInShell
    if ($b1.State -ne 'Running' -or $b2.State -ne 'Running') { $script:V.E2 = 'NOT RUN (stand-ins not both Running on entry)'; return }
    $sec = Read-Host -AsSecureString ('password for ' + $DbUser + '@' + $DbHost + ':' + $DbPort)
    $pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    Say ('  password length : ' + $pw.Length)
    $env:PGPASSWORD = $pw
    & $psql -h $DbHost -p $DbPort -U $DbUser -d $ScratchDb -v ON_ERROR_STOP=1 -c 'SELECT * FROM inst13dry_table_that_cannot_exist' *> $null; $neg = $LASTEXITCODE
    & $psql -h $DbHost -p $DbPort -U $DbUser -d $ScratchDb -v ON_ERROR_STOP=1 -c 'SELECT 1' *> $null; $pos = $LASTEXITCODE
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    Say ('  psql NEGCTL rc={0} (want non-zero) | POSCTL rc={1} (want 0)' -f $neg, $pos)
    if ($neg -eq 0) { $script:V.E2 = 'NOT RUN (psql rc is not a gate here - NEGCTL returned 0)'; return }
    if ($pos -ne 0) { $script:V.E2 = 'NOT RUN (scratch db unreachable)'; return }
    $env:PGPASSWORD = $pw
    & $pgDump -h $DbHost -p $DbPort -U $DbUser --schema-only -f (Join-Path $WORK 'dumpcheck.sql') $ScratchDb *> $null; $dumpRc = $LASTEXITCODE
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    Say ('  pg_dump pre-check rc={0} (want 0; else the run would fail at backup and measure E, not E2)' -f $dumpRc)
    if ($dumpRc -ne 0) { $script:V.E2 = 'NOT RUN (pg_dump cannot dump the scratch db - version or auth)'; return }
    $mig = Join-Path $PKG 'db\migrations'; New-Item -ItemType Directory -Path $mig -Force | Out-Null
    $noBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $mig '20990101_001_inst13dry_ok.sql'), "CREATE TABLE IF NOT EXISTS inst13dry_marker (id int);`r`n", $noBom)
    [IO.File]::WriteAllText((Join-Path $mig '20990101_002_inst13dry_bad.sql'), "THIS IS DELIBERATELY NOT SQL;`r`n", $noBom)
    Say '  BEFORE'; Show 'rtm' $b1; Show 'shell' $b2
    $r = Run-Child 'E2' @('InstallRoot',$ROOT,'RTMSvcName',$StandInRTM,'ShellSvcName',$StandInShell,'SkipDrift',$true,'MigrationList','20990101_001_inst13dry_ok,20990101_002_inst13dry_bad','DBHost',$DbHost,'DBPort',$DbPort,'Database',$ScratchDb,'DBUser',$DbUser) $pw
    $pw = $null
    Start-Sleep -Seconds 3
    $a1 = Svc-Snap $StandInRTM; $a2 = Svc-Snap $StandInShell
    Say '  AFTER'; Show 'rtm' $a1; Show 'shell' $a2
    $posctl = Has $r.Text 'RTM View Shell - UPDATE'
    Say ('  child rc={0} log={1} | log POSCTL {2}' -f $r.Rc, $r.Log, $posctl)
    if (-not $posctl) { $script:V.E2 = 'NOT RUN (child log not captured)'; return }
    $c1 = Has $r.Text '[DB Apply] Migration 20990101_002_inst13dry_bad failed'
    $c2 = Has $r.Text 'MANUAL RECOVERY REQUIRED'
    $c3 = (Has $r.Text 'Backup directory :') -and (Has $r.Text 'DB dump file     :')
    $c4 = Has $r.Text 'pg_restore'
    $c5 = -not (Has $r.Text '[RECOVERY] Deploy failed before DB changes')
    $c6 = ($a1.State -eq 'Stopped') -and ($a2.State -eq 'Stopped')
    $c7 = Has $r.Text '[OK] 20990101_001_inst13dry_ok'
    Say ('  first migration applied {0} | throw on 002 {1} | MANUAL RECOVERY {2} | backup+dump printed {3} | pg_restore printed {4} (pg_restore installed: {5}) | no auto-recovery {6} | both STOPPED {7}' -f $c7, $c1, $c2, $c3, $c4, [bool]$pgRestore, $c5, $c6)
    $script:V.E2 = $(if ($c7 -and $c1 -and $c2 -and $c3 -and $c4 -and $c5 -and $c6) { 'GREEN' } else { 'RED' })
    Say '  LEFT FOR THE OPERATOR (the box does not tidy this - the stopped state is the evidence):'
    Say ('    Start-Service ' + $StandInRTM + ' ; Start-Service ' + $StandInShell)
    Say ('    scratch db "' + $ScratchDb + '" holds table inst13dry_marker - drop the table or the db yourself')
}
Say ('E2 : ' + $V.E2)

# ---- cleanup + verdict ----
Say ''
try { [IO.Directory]::Delete($WORK, $true); Say ('temp root removed : ' + (-not (Test-Path $WORK))) } catch { Say ('temp root NOT removed: ' + $_) }
$fin1 = Svc-Snap $StandInRTM; $fin2 = Svc-Snap $StandInShell
Say 'stand-ins on exit:'; Show 'rtm' $fin1; Show 'shell' $fin2
Say ''
Say ('RESULT : A={0} | D={1} | E={2} | E2={3}' -f $V.A, $V.D, $V.E, $V.E2)
$core = ($V.A -eq 'GREEN') -and ($V.D -eq 'GREEN') -and ($V.E -eq 'GREEN')
$unit = if ($core -and $V.E2 -eq 'GREEN') { 'CLOSABLE' } elseif ($core -and $V.E2 -like 'NOT RUN*') { 'NEEDS COORDINATOR DEFERRAL OF E2' } else { 'NOT CLOSABLE' }
Say ('UNIT   : ' + $unit)
Say ('LAST LINE: ' + $(if ($core -and $V.E2 -notlike 'RED*') { 'PASS' } else { 'FAIL' }))
Say '===== END ====='
Flush
Write-Host ''
Write-Host ('report : ' + $REPORT)
Write-Host ('child logs : ' + $OUT + '\DEV_' + $STAMP + '_inst13-*-child.txt')
