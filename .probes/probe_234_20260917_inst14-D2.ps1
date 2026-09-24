#Requires -Version 5.1
<#
  PROBE 234 / inst14-D2               PR234-INST-14 behaviour + A on Windows PowerShell 5.1. RE-RUN of inst14-D.
  PRINT FIX     : 2026-09-17, no re-run. The version that ran on 234 at 12:05:28 (sha256 8BA11E2D...75EA) printed
                  each run line with UNSUBSTITUTED fields ({0,-18} rc={1} POSCTL {2} ... {3}): a '+' concatenation
                  in front of -f bound -f to the last string fragment only. The verdict was computed from variables
                  and is valid; only the printed key/rc/POSCTL/count were lost. Fixed by parenthesising the format
                  string and passing PreCount as {9}.
  WHY A RE-RUN  : inst14-D (2026-09-17 11:56) printed D=RED because MY matcher -like '*Drift gate SKIPPED*' is
                  case-insensitive and also caught the preflight line '[--] drift tool: not checked (drift gate skipped)'.
                  Coordinator: accepting on raw lines by eye would close this subject the way it fixes. Needles are now
                  ORDINAL, CASE-SENSITIVE substring matches (String.Contains) - NOT -clike: in a -like pattern '[E1]'
                  is a character class, not literal text. Both needles must count exactly 1, so the probe proves it
                  tells them apart, not merely that it stopped confusing them.
  WHERE IT RUNS : server 234 (hostname "RTM"). Anything else aborts.
  SERVICES      : NONE touched. The subject is given NON-EXISTENT service names, so step [1/5] prints
                  "Not installed" and stops nothing; recovery finds nothing to start. The real RTMService,
                  RTMViewShell and RTMTwilio_1 are only READ (pid + StartTime before == after = proof).
  DATABASE      : none. -DBPort 1 makes pg_dump fail before any write.
  WRITES        : C:\RTMView-Ops\inst14dry_<stamp>\ (removed at the end), C:\RTMView-Ops\output\
  WHY THE NO-SUCH-SERVICE TRICK IS VALID HERE AND NOT FOR INST-13 E/E2: the line under test ([E1] ... SKIPPED)
                  is printed BEFORE the stop. Where the subject IS the stop and the restart, the trick proves nothing.
  Subjects      : NEW  9ae966f blob 1feb1d91 (shipped form: BOM+CRLF)  -> inst14_Update-RTMView_1feb1d91_shipped.ps1
                  OLD  8b3da25 blob cf619dbb (shipped form)            -> inst13_Update-RTMView_cf619dbb_shipped.ps1
  binding       : .coord/cc/devops.md, block dated 2026-09-17T08:4xZ (devops <-> operator, PowerShell, no CC session) - pins BEFORE are there,
                  the RESULT with every verdict is appended there afterwards, including a broken-off run.
                  commit.lock / cc_prompt_sync_block: NOT APPLICABLE, with the reason - no commit, no clone touched.
  Author        : devops-0916, 2026-09-17.
#>
$ErrorActionPreference = 'Continue'
$SENTINEL = -999
$NEW_SHA = 'EB1142FA2A6D204855A5F70E84307DF04B6A15981DE7998ABB9D5444A1B74A0D'
$OLD_SHA = '7EF750E83D8A6146ED39FF3C3041DC666F120BCD1CA2FBF5AABF715DB69E9CC0'
$STAMP = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OPS = 'C:\RTMView-Ops'; $IN = Join-Path $OPS 'incoming'; $OUT = Join-Path $OPS 'output'
$DRY = Join-Path $OPS ('inst14dry_' + $STAMP)
$REPORT = Join-Path $OUT ('234_' + $STAMP + '_inst14-D2.txt')
$FAKE_RTM = 'INST14_NOSUCH_RTM'; $FAKE_SHELL = 'INST14_NOSUCH_SHELL'
$Lines = New-Object System.Collections.ArrayList
function Say($t) { [void]$Lines.Add([string]$t); Write-Host $t }
function Flush { try { New-Item -ItemType Directory -Path $OUT -Force | Out-Null; [IO.File]::WriteAllLines($REPORT, [string[]]$Lines, (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('report write failed: ' + $_) } }
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL }; return @($c).Count }
function Has($t, $n) { return ($t.IndexOf($n, [StringComparison]::Ordinal) -ge 0) }
function Stop-Box($why) { Say ''; Say ('*** STOP: ' + $why); Say 'LAST LINE: FAIL'; Say '===== END ====='; Flush; Write-Host ('report : ' + $REPORT); exit 2 }
function Snap($n) {
    $w = Get-CimInstance Win32_Service -Filter ("Name='" + $n + "'") -ErrorAction SilentlyContinue
    if ($null -eq $w) { return 'ABSENT' }
    $st = '-'; if ($w.ProcessId -gt 0) { $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if ($p) { $st = $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } }
    return ('{0} pid={1} StartTime={2}' -f $w.State, $w.ProcessId, $st)
}
function Run-Child($tag, $scriptPath, $flag) {
    $d = Join-Path $DRY $tag; New-Item -ItemType Directory -Path (Join-Path $d 'root') -Force | Out-Null
    $log = Join-Path $OUT ('234_' + $STAMP + '_inst14D2-' + $tag + '-child.txt')
    $so = Join-Path $d 'so.txt'; $se = Join-Path $d 'se.txt'; $wrap = Join-Path $d 'wrap.ps1'
    $body = @'
param([string]$Script, [string]$Root, [string]$Flag, [string]$FakeRtm, [string]$FakeShell)
$a = @{ InstallRoot=$Root; RTMSvcName=$FakeRtm; ShellSvcName=$FakeShell; SkipCacheMigration=$true; DBHost='127.0.0.1'; DBPort='1'; Database='inst14_none'; MigrationList='' }
$a[$Flag] = $true
try { & $Script @a; Write-Host 'CHILD RETURNED NORMALLY'; exit 0 }
catch { Write-Host ('CHILD THREW: ' + $_.Exception.Message); exit 1 }
'@
    [IO.File]::WriteAllText($wrap, $body, (New-Object Text.UTF8Encoding($true)))
    $argv = '-NoProfile -ExecutionPolicy Bypass -File "' + $wrap + '" -Script "' + $scriptPath + '" -Root "' + (Join-Path $d 'root') + '" -Flag ' + $flag + ' -FakeRtm ' + $FAKE_RTM + ' -FakeShell ' + $FAKE_SHELL
    $p = Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $argv -Wait -PassThru -NoNewWindow -RedirectStandardOutput $so -RedirectStandardError $se
    $t = ''; if (Test-Path $so) { $t = [IO.File]::ReadAllText($so) }; if (Test-Path $se) { $t += "`r`n----- STDERR -----`r`n" + [IO.File]::ReadAllText($se) }
    [IO.File]::WriteAllText($log, $t, (New-Object Text.UTF8Encoding($false)))
    $all = @($t -split "`r?`n")
    $skip = @($all | Where-Object { $_.Contains('[E1] Drift gate SKIPPED') })
    $pre = @($all | Where-Object { $_.Contains('[--] drift tool: not checked (drift gate skipped)') })
    return [pscustomobject]@{ Rc=$p.ExitCode; Text=$t; Skip=($skip -join ' || '); SkipCount=$skip.Count; PreCount=$pre.Count }
}

Say '===== PROBE 234 / inst14-D2 ====='
Say ('WHERE IT RUNS : ' + $env:COMPUTERNAME + ' (want RTM) | PS ' + $PSVersionTable.PSVersion + ' ' + $PSVersionTable.PSEdition + ' | now ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say 'EXPECT A    : Windows PowerShell 5.1 parse errors 0 for NEW and OLD shipped forms; NEGCTL ParseInput("if (") > 0'
Say 'EXPECT NEW  : -SkipDrift -> "SKIPPED (-SkipDrift)." | -ForceDeploy -> "SKIPPED (-ForceDeploy)." | -SkipDriftGate -> "SKIPPED (-SkipDrift)."'
Say 'EXPECT OLD  : all three -> "SKIPPED (-ForceDeploy/-SkipDrift)."   <- the predicate discriminates only if OLD is identical and NEW differs'
Say 'EXPECT ALL  : exactly 1 line containing "[E1] Drift gate SKIPPED" AND exactly 1 line containing "[--] drift tool: not checked (drift gate skipped)" per run, "Not installed" for both fake names, NO "Stopped:" line, real services pid+StartTime before == after'
Say ''
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('self-gate {0}/{1}/{2} (want {3}/0/2) | Has NEGCTL {4} POSCTL {5}' -f $gA, $gB, $gC, $SENTINEL, (Has 'abc' 'zz'), (Has 'abc' 'b'))
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2)) -or (Has 'abc' 'zz') -or -not (Has 'abc' 'b')) { Stop-Box 'self-gate broken' }
$st = @('  [--] drift tool: not checked (drift gate skipped)', '[E1] Drift gate SKIPPED (-SkipDrift).', '[e1] drift gate skipped (x)', 'E1 Drift gate SKIPPED')
$n1 = @($st | Where-Object { $_.Contains('[E1] Drift gate SKIPPED') }).Count; $n2 = @($st | Where-Object { $_.Contains('[--] drift tool: not checked (drift gate skipped)') }).Count
Say ('needle self-test on 4 synthetic lines : [E1] needle {0} (want 1) | preflight needle {1} (want 1)' -f $n1, $n2)
if ($n1 -ne 1 -or $n2 -ne 1) { Stop-Box 'needle self-test failed' }
if ($env:COMPUTERNAME -ne 'RTM') { Stop-Box 'not 234' }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Stop-Box 'not elevated' }
if ($PSVersionTable.PSEdition -ne 'Desktop') { Stop-Box 'not Windows PowerShell 5.1' }
foreach ($f in @($FAKE_RTM, $FAKE_SHELL)) { if (Get-Service -Name $f -ErrorAction SilentlyContinue) { Stop-Box ('a service named ' + $f + ' EXISTS - trick invalid') } }
Say ('fake service names absent : ' + $FAKE_RTM + ', ' + $FAKE_SHELL)
if (Test-Path $DRY) { Stop-Box ('exists: ' + $DRY) }

# ---- subjects ----
New-Item -ItemType Directory -Path $DRY -Force | Out-Null
$subj = @{}
foreach ($pair in @(@('NEW', 'inst14_Update-RTMView_1feb1d91_shipped.ps1', $NEW_SHA), @('OLD', 'inst13_Update-RTMView_cf619dbb_shipped.ps1', $OLD_SHA))) {
    $src = Join-Path $IN $pair[1]
    if (-not (Test-Path -LiteralPath $src)) { Stop-Box ('missing ' + $src) }
    $h = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    Say ('{0} {1} sha256 == reviewed : {2}' -f $pair[0], $pair[1], ($h -eq $pair[2]))
    if ($h -ne $pair[2]) { Stop-Box ($pair[0] + ' subject changed') }
    $pk = Join-Path $DRY ('pkg_' + $pair[0]); New-Item -ItemType Directory -Path $pk -Force | Out-Null
    $dst = Join-Path $pk 'Update-RTMView.ps1'; Copy-Item -LiteralPath $src -Destination $dst
    $subj[$pair[0]] = $dst
}

# ---- A on 5.1 ----
Say ''; Say '--- A : parse on Windows PowerShell 5.1 ---'
$neg = $null; $tk = $null; [Management.Automation.Language.Parser]::ParseInput('if (', [ref]$tk, [ref]$neg) | Out-Null
$A = 'GREEN'
foreach ($k in @('NEW','OLD')) { $e = $null; [Management.Automation.Language.Parser]::ParseFile($subj[$k], [ref]$tk, [ref]$e) | Out-Null; $n = Safe-Count $e; Say ('  {0} parse errors {1} (want 0)' -f $k, $n); if ($n -ne 0) { $A = 'RED' } }
Say ('  NEGCTL broken input errors ' + (Safe-Count $neg) + ' (want > 0)'); if ((Safe-Count $neg) -le 0) { $A = 'NOT RUN (parser NEGCTL 0)' }
Say ('A : ' + $A)
if ($A -ne 'GREEN') { Stop-Box 'A not green' }

# ---- D ----
Say ''; Say '--- D : three flags x two subjects ---'
$real0 = @{}; foreach ($n in @('RTMService','RTMViewShell','RTMTwilio_1')) { $real0[$n] = Snap $n; Say ('  BEFORE {0,-13} {1}' -f $n, $real0[$n]) }
$want = @{ 'NEW|SkipDrift'='[E1] Drift gate SKIPPED (-SkipDrift).'; 'NEW|ForceDeploy'='[E1] Drift gate SKIPPED (-ForceDeploy).'; 'NEW|SkipDriftGate'='[E1] Drift gate SKIPPED (-SkipDrift).';
          'OLD|SkipDrift'='[E1] Drift gate SKIPPED (-ForceDeploy/-SkipDrift).'; 'OLD|ForceDeploy'='[E1] Drift gate SKIPPED (-ForceDeploy/-SkipDrift).'; 'OLD|SkipDriftGate'='[E1] Drift gate SKIPPED (-ForceDeploy/-SkipDrift).' }
$okAll = $true; $got = @{}
foreach ($k in @('OLD','NEW')) { foreach ($flag in @('SkipDrift','ForceDeploy','SkipDriftGate')) {
    $key = $k + '|' + $flag
    $r = Run-Child ($k + '-' + $flag) $subj[$k] $flag
    $pos = Has $r.Text 'RTM View Shell - UPDATE'
    $ni = (Has $r.Text ('Not installed: ' + $FAKE_RTM)) -and (Has $r.Text ('Not installed: ' + $FAKE_SHELL))
    $noStop = -not (Has $r.Text '  Stopped: ')
    $hit = ($r.SkipCount -eq 1) -and ($r.PreCount -eq 1) -and (Has $r.Skip $want[$key])
    $got[$key] = $r.Skip.Trim()
    Say (('  {0,-18} rc={1} POSCTL {2} | [E1]-SKIPPED lines {3} (want 1) preflight-skipped lines {9} (want 1) | "{4}" | want "{5}" -> {6} | Not installed x2 {7} | no Stopped {8}') -f $key, $r.Rc, $pos, $r.SkipCount, $r.Skip.Trim(), $want[$key], $hit, $ni, $noStop, $r.PreCount)
    if (-not ($pos -and $hit -and $ni -and $noStop)) { $okAll = $false }
} }
$oldSame = ($got['OLD|SkipDrift'] -eq $got['OLD|ForceDeploy']) -and ($got['OLD|ForceDeploy'] -eq $got['OLD|SkipDriftGate'])
$newDiff = ($got['NEW|SkipDrift'] -ne $got['NEW|ForceDeploy'])
Say ('  discriminates : OLD identical {0} | NEW -SkipDrift != -ForceDeploy {1}' -f $oldSame, $newDiff)
$realOk = $true
foreach ($n in @('RTMService','RTMViewShell','RTMTwilio_1')) { $s = Snap $n; $same = ($s -eq $real0[$n]); if (-not $same) { $realOk = $false }; Say ('  AFTER  {0,-13} {1} | unchanged {2}' -f $n, $s, $same) }
$D = if ($okAll -and $oldSame -and $newDiff -and $realOk) { 'GREEN' } else { 'RED' }
Say ('D : ' + $D)

try { [IO.Directory]::Delete($DRY, $true); Say ('scratch removed : ' + (-not (Test-Path $DRY))) } catch { Say ('scratch NOT removed: ' + $_) }
Say ''
Say ('RESULT : A(5.1)=' + $A + ' | D=' + $D + ' | real services unchanged ' + $realOk)
Say ('LAST LINE: ' + $(if ($A -eq 'GREEN' -and $D -eq 'GREEN') { 'PASS' } else { 'FAIL' }))
Say '===== END ====='
Flush
Write-Host ''; Write-Host ('report : ' + $REPORT)
