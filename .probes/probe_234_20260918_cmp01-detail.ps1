#Requires -Version 5.1
<#
  PROBE 234 / cmp01-detail          PR234-CMP-01: what the 862 "extra" detail lines of DIMENSION A ARE.
  WHERE IT RUNS : server 234 (hostname "RTM"). Anything else aborts.
  SERVICES      : none touched, none read for state. No service is stopped, started or restarted.
  DATABASE      : rtmviewdb on 5433 - READ ONLY. One pg_dump --schema-only (no data, no writes).
  WRITES        : C:\RTMView-Ops\cmp01_<stamp>\ (temp dump + filtered copy, removed at the end),
                  C:\RTMView-Ops\output\234_<stamp>_cmp01-detail.txt
  WHY           : the 13.09 report says DIMENSION A = 912 lines (2 missing / 910 extra, of which 862 are
                  "detail" lines) and the gate counts 49 extra ROUTINES. The report carries counts only,
                  so the COMPOSITION of those lines cannot be recovered from it - it has to be re-measured.
                  Coordinator 2026-09-18: a reading measurement on my own territory needs no section-4.
  METHOD        : reproduce EXACTLY what Compare-ToBaseline.ps1 does for dimension A - Export-RtmSchema
                  (full public schema dump, filtered to blocks that mention a whitelisted table name),
                  the same Normalize-Schema filter, the same HashSet difference - then classify every
                  differing line by the BLOCK it came from. Nothing about the comparator is changed.
  NEEDS in C:\RTMView-Ops\incoming\ next to this file:
     cmp01_RtmSchemaDump_e1dd7da8.ps1     (v3:db/tools/RtmSchemaDump.ps1, shipped form)
     cmp01_schema_f6f8c3b7.sql            (v3:db/schema.sql - the baseline side)
  Author        : devops-0916, 2026-09-18. binding: .coord/cc/devops.md, block dated 2026-09-18 (cmp01 detail).
#>
$ErrorActionPreference = 'Continue'
$SENTINEL = -999
$DUMP_SHA = 'AAEE2E1F2EB266CF934AA0F4FD3502A4904C0D1B6841C80FDE72591A298AB032'
$BASE_SHA = 'B6C3CEDD3BF0668F3498185F9C8FD454D3DE5670B18BBD2D2BDCC5F9524AF6A1'
$STAMP = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OPS = 'C:\RTMView-Ops'; $IN = Join-Path $OPS 'incoming'; $OUT = Join-Path $OPS 'output'
$WORK = Join-Path $OPS ('cmp01_' + $STAMP)
$REPORT = Join-Path $OUT ('234_' + $STAMP + '_cmp01-detail.txt')
$PGBIN = 'C:\Program Files\PostgreSQL\18\bin'
$Lines = New-Object System.Collections.ArrayList
function Say($t) { [void]$Lines.Add([string]$t); Write-Host $t }
function Flush { try { New-Item -ItemType Directory -Path $OUT -Force | Out-Null; [IO.File]::WriteAllLines($REPORT, [string[]]$Lines, (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('report write failed: ' + $_) } }
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL }; return @($c).Count }
function Stop-Box($why) { Say ''; Say ('*** STOP: ' + $why); Say 'LAST LINE: FAIL'; Say '===== END ====='; Flush; Write-Host ('report : ' + $REPORT); exit 2 }

Say '===== PROBE 234 / cmp01-detail ====='
Say ('WHERE IT RUNS : ' + $env:COMPUTERNAME + ' (want RTM) | PS ' + $PSVersionTable.PSVersion + ' ' + $PSVersionTable.PSEdition + ' | now ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say 'READ ONLY     : one pg_dump --schema-only against rtmviewdb@5433. No service touched. No DB write.'
Say 'EXPECT (named before the numbers, from the 13.09 report):'
Say '  missing-on-server 2 | extra-on-server 910 | of the extra, 49 are CREATE FUNCTION|PROCEDURE headers and 862 are "detail"'
Say '  The composition of those 862 is UNKNOWN - that is what this probe measures. Any split is a result, not a failure.'
Say '  A total that does NOT reproduce 2 / 910 is itself a finding and is reported as such.'
Say ''
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('self-gate Safe-Count {0}/{1}/{2} (want {3}/0/2)' -f $gA, $gB, $gC, $SENTINEL)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Stop-Box 'self-gate broken' }
if ($env:COMPUTERNAME -ne 'RTM') { Stop-Box ('host is ' + $env:COMPUTERNAME + ', not 234') }
if ($PSVersionTable.PSEdition -ne 'Desktop') { Stop-Box 'not Windows PowerShell 5.1' }
$helper = Join-Path $IN 'cmp01_RtmSchemaDump_e1dd7da8.ps1'
$baseline = Join-Path $IN 'cmp01_schema_f6f8c3b7.sql'
foreach ($pair in @(@($helper, $DUMP_SHA), @($baseline, $BASE_SHA))) {
    if (-not (Test-Path -LiteralPath $pair[0])) { Stop-Box ('missing ' + $pair[0]) }
    $h = (Get-FileHash -LiteralPath $pair[0] -Algorithm SHA256).Hash
    Say ('  {0} sha256 == reviewed : {1}' -f (Split-Path $pair[0] -Leaf), ($h -eq $pair[1]))
    if ($h -ne $pair[1]) { Stop-Box 'input file is not the reviewed one' }
}
$pgDump = Join-Path $PGBIN 'pg_dump.exe'
if (-not (Test-Path -LiteralPath $pgDump)) { Stop-Box ('missing ' + $pgDump) }
if (Test-Path $WORK) { Stop-Box ('exists: ' + $WORK) }
New-Item -ItemType Directory -Path $WORK -Force | Out-Null

$sec = Read-Host -AsSecureString 'password for the DB user that may READ rtmviewdb@5433'
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
Say ('  password length : ' + $pw.Length)
if ($pw.Length -eq 0) { Stop-Box 'empty password' }
$user = Read-Host 'DB user (Enter = postgres)'
if (-not $user) { $user = 'postgres' }
$env:PGPASSWORD = $pw; $pw = $null

# ---- reproduce Export-RtmSchema exactly ----
Say ''; Say '--- server side: Export-RtmSchema (the comparator own helper, dot-sourced unchanged) ---'
. $helper
$serverFile = Join-Path $WORK 'server_schema.sql'
try { Export-RtmSchema -PgDump $pgDump -DBHost '127.0.0.1' -DBPort '5433' -DBUser $user -Database 'rtmviewdb' -OutFile $serverFile }
catch { Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue; Stop-Box ('Export-RtmSchema failed: ' + $_.Exception.Message) }
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
if (-not (Test-Path $serverFile)) { Stop-Box 'no server schema file produced' }
Say ('  server dump bytes : ' + (Get-Item $serverFile).Length)

# ---- the comparator own Normalize-Schema ----
function Normalize-Schema([string]$path) {
    $lines = Get-Content $path -ErrorAction SilentlyContinue
    return $lines | Where-Object {
        $_ -notmatch "^--" -and $_ -notmatch "^SET " -and $_ -notmatch "^SELECT " -and
        $_ -notmatch "^\s*$" -and $_ -notmatch "OWNER TO" -and $_ -notmatch "^\\connect" -and
        $_ -notmatch "Dumped from" -and $_ -notmatch "Dumped by"
    } | ForEach-Object { $_.TrimEnd() }
}
$ServerNorm = Normalize-Schema $serverFile
$BaselineNorm = Normalize-Schema $baseline
$ServerSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$ServerNorm)
$BaselineSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$BaselineNorm)
$MissingOnServer = @($BaselineNorm | Where-Object { -not $ServerSet.Contains($_) })
$ExtraOnServer = @($ServerNorm | Where-Object { -not $BaselineSet.Contains($_) })
Say ''; Say '--- dimension A, reproduced ---'
Say ('  server normalised lines {0} | baseline normalised lines {1}' -f (Safe-Count $ServerNorm), (Safe-Count $BaselineNorm))
Say ('  missing on server {0} (13.09: 2) | extra on server {1} (13.09: 910)' -f $MissingOnServer.Count, $ExtraOnServer.Count)

# ---- classify every EXTRA line by the block it belongs to ----
Say ''; Say '--- composition of the EXTRA lines, by owning block ---'
$raw = Get-Content $serverFile
$blockKind = @{}   # line text -> kind of the block it first appeared in
$cur = 'other'
foreach ($ln in $raw) {
    if ($ln -match '^\s*$') { $cur = 'other'; continue }
    if ($ln -match '(?i)^CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s') { $cur = 'routine' }
    elseif ($ln -match '(?i)^CREATE\s+TABLE\s') { $cur = 'table' }
    elseif ($ln -match '(?i)^CREATE\s+(UNIQUE\s+)?INDEX\s') { $cur = 'index' }
    elseif ($ln -match '(?i)^CREATE\s+SEQUENCE\s') { $cur = 'sequence' }
    elseif ($ln -match '(?i)^ALTER\s+TABLE') { $cur = 'alter' }
    elseif ($ln -match '^--') { continue }
    $t = $ln.TrimEnd()
    if (-not $blockKind.ContainsKey($t)) { $blockKind[$t] = $cur }
}
$tally = @{ routine = 0; table = 0; index = 0; sequence = 0; alter = 0; other = 0 }
$routineHeaders = 0
foreach ($l in $ExtraOnServer) {
    $k = if ($blockKind.ContainsKey($l)) { $blockKind[$l] } else { 'other' }
    $tally[$k] = $tally[$k] + 1
    if ($l -match '(?i)^CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s') { $routineHeaders++ }
}
$sum = 0; foreach ($k in $tally.Keys) { $sum += $tally[$k] }
Say ('  routine blocks  : {0}   (of which CREATE FUNCTION|PROCEDURE header lines: {1}; bodies: {2})' -f $tally['routine'], $routineHeaders, ($tally['routine'] - $routineHeaders))
Say ('  table blocks    : {0}' -f $tally['table'])
Say ('  index blocks    : {0}' -f $tally['index'])
Say ('  sequence blocks : {0}' -f $tally['sequence'])
Say ('  ALTER TABLE     : {0}' -f $tally['alter'])
Say ('  other           : {0}' -f $tally['other'])
Say ('  SUM {0} == extra {1} : {2}   <- the split must account for every line, or it is not a split' -f $sum, $ExtraOnServer.Count, ($sum -eq $ExtraOnServer.Count))
Say ''
Say '  first 5 lines of each non-empty class, verbatim (evidence, not summary):'
foreach ($k in @('routine','table','index','sequence','alter','other')) {
    if ($tally[$k] -eq 0) { continue }
    $n = 0
    foreach ($l in $ExtraOnServer) {
        $kk = if ($blockKind.ContainsKey($l)) { $blockKind[$l] } else { 'other' }
        if ($kk -eq $k) { Say ('    [' + $k + '] ' + $l); $n++; if ($n -ge 5) { break } }
    }
}
Say ''
Say '  MISSING on server, all of them:'
foreach ($l in $MissingOnServer) { Say ('    - ' + $l) }

try { [IO.Directory]::Delete($WORK, $true); Say ''; Say ('temp removed : ' + (-not (Test-Path $WORK))) } catch { Say ('temp NOT removed: ' + $_) }
Say ''
Say ('RESULT : extra {0} | routine-block lines {1} (headers {2}) | table {3} | index {4} | sequence {5} | alter {6} | other {7} | missing {8}' -f $ExtraOnServer.Count, $tally['routine'], $routineHeaders, $tally['table'], $tally['index'], $tally['sequence'], $tally['alter'], $tally['other'], $MissingOnServer.Count)
Say ('LAST LINE: ' + $(if ($sum -eq $ExtraOnServer.Count) { 'PASS (composition accounts for every extra line)' } else { 'FAIL (composition does not sum to the extra count)' }))
Say '===== END ====='
Flush
Write-Host ''; Write-Host ('report : ' + $REPORT)
