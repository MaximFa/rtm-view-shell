#Requires -Version 5.1
<#
  PROBE LOCAL / seqfix-proof-v3   -   BEHAVIOURAL proof of the step-7 fix. THIS ONE WRITES,
  but only into a throwaway database it creates itself and drops at the end.
  WHERE IT RUNS : the BUILD machine, on the PostgreSQL port DISCOVERED there. It REFUSES to run on server 234.
  NOT TOUCHED   : rtmviewdb and every other existing database, PG15 on 5432, server 234.
  WHAT IT PROVES, in this order (red first - a green that cannot go red is worth nothing):
    A  negative  : with a filter that matches nothing the step reports count=0 and STOPS the install
    B  third     : with the count line suppressed the step takes the OTHER branch (did not report)
    C  positive  : unmodified, the step reports the real number and the install continues
  The SQL block and the parsing block are READ OUT OF db/tools/Provision-FreshDb.ps1 at run time -
  the artifact is tested, not a copy of it retyped here.
#>

$ErrorActionPreference = "Continue"
$Repo   = "D:\Claude\Projects\RTM View Shell"
$Script = Join-Path $Repo "db\tools\Provision-FreshDb.ps1"
$DBHost = "127.0.0.1"
$DBPort = ""   # never assumed - discovered below from the listeners on this machine
$SuperUser = "postgres"

$OutDir = Join-Path $Repo ".measurements"
if (-not (Test-Path $OutDir)) { $OutDir = $env:TEMP }
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ("LOCAL_{0}_seqfix-proof-v3.txt" -f $stamp)
$TestDb = "rtm_seqcheck_{0}" -f $stamp
$ProbeLines = New-Object System.Collections.ArrayList
$created = $false
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "RUN COMPLETE" } else { "RUN ABORTED" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function RunSql($db, $sqlText, $stopOnError) {
    $f = Join-Path $env:TEMP ("seqproof_{0}_{1}.sql" -f $stamp, (Get-Random))
    [IO.File]::WriteAllText($f, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $args = @("-h", $DBHost, "-p", $DBPort, "-U", $SuperUser, "-d", $db, "-f", $f)
    if ($stopOnError) { $args = @("-v", "ON_ERROR_STOP=1") + $args }
    $out = & $script:psql @args 2>&1
    $rc = $LASTEXITCODE
    Remove-Item $f -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Rc = $rc; Text = ($out | Out-String) }
}

Say "===== WHERE IT RUNS ====="
Say "  the BUILD machine, on the PostgreSQL port discovered below. Server 234 is NOT touched."
Say "  THIS PROBE WRITES: it creates one throwaway database and drops it at the end. Nothing else."
Say ("  probe file sha256 : {0}" -f (Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Say ("  throwaway database name : {0}" -f $TestDb)
Say ("  local time now    : {0}" -f (Get-Date))
Say ""

Say "===== G0  not the server, inputs present (gate) ====="
Say ("  machine name : {0}   (must NOT be RTM)" -f $env:COMPUTERNAME)
if ($env:COMPUTERNAME -eq "RTM") { Say "  *** this is server 234 - aborting"; Fin $false }
$script:psql = $null
$pg18 = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
if (Test-Path $pg18) { $script:psql = $pg18 }
Say ("  psql (PG18 only) : {0}" -f $(if ($script:psql) { $script:psql } else { "NOT FOUND at $pg18" }))
Say ("  edited script    : {0}   exists {1}" -f $Script, (Test-Path $Script))
if ((-not $script:psql) -or (-not (Test-Path $Script))) { Say "  *** cannot proceed; aborting"; Fin $false }
Say ("  script blob (git hash-object) : {0}" -f (& git -C $Repo hash-object $Script 2>$null))
$pw = Read-Host -Prompt "postgres password (input is masked)" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))
Say ("  postgres password entered : {0} characters (value never printed)" -f $env:PGPASSWORD.Length)
Say "  G0 PASS"
Say ""

Say "===== G0b  WHICH PORT - discovered, never assumed (gate) ====="
Say "  the 20:14 run died because 5433 was carried over from server 234 and typed in here from memory"
$pgProcs = @(Get-Process -Name postgres -ErrorAction SilentlyContinue)
Say ("  postgres processes on this machine : {0}" -f $pgProcs.Count)
$ports = @()
foreach ($p in $pgProcs) {
    foreach ($c in @(Get-NetTCPConnection -State Listen -OwningProcess $p.Id -ErrorAction SilentlyContinue)) {
        if ($ports -notcontains $c.LocalPort) { $ports += $c.LocalPort }
    }
}
$ports = @($ports | Sort-Object)
Say ("  listening ports owned by postgres  : {0}" -f $(if ($ports.Count -gt 0) { ($ports -join ", ") } else { "NONE" }))
if ($ports.Count -eq 0) { Say "  *** no PostgreSQL listener on this machine. NOT inventing a stand, NOT going to 234."; Say "  *** the list above is the whole finding - stopping for the coordinator."; Fin $false }
if ($ports.Count -gt 1) { Say "  *** more than one listener - guessing which one is ours is exactly the mistake of the 20:14 run."; Say "  *** the list above is the whole finding - stopping for the coordinator."; Fin $false }
$DBPort = "$($ports[0])"
Say ("  exactly one listener -> port {0} is used for everything below" -f $DBPort)
Say "  G0b PASS"
Say ""

Say "===== G1  connectivity FIRST, then the ability to fail, then a FREE name (gate) ====="
$alive = RunSql "postgres" "SELECT 'ALIVE=' || 1::text;" $true
Say ("  a deliberately VALID query -> rc {0}" -f $alive.Rc)
if (($alive.Rc -ne 0) -or ($alive.Text -notmatch "ALIVE=1")) {
    Say ("  server answer: {0}" -f ($alive.Text.Trim() -replace "\s+", " "))
    Say "  *** the server did not answer a trivially valid query. This says nothing about the product -"
    Say "  *** it says the stand is unreachable, and every check below would pass for the wrong reason; aborting"
    Fin $false
}
Say "  connectivity established - only now does a non-zero code mean SYNTAX rather than WIRE"
$bad = RunSql "postgres" "SELECT this_function_does_not_exist();" $true
Say ("  deliberately broken query -> rc {0}   (must be non-zero)" -f $bad.Rc)
if ($bad.Rc -eq 0) { Say "  *** psql returns 0 on a broken query - every zero below would be meaningless; aborting"; Fin $false }
$idf = RunSql "postgres" "SELECT 'connected to: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;" $true
Say ("  the server names itself BEFORE any write: {0}" -f ($idf.Text.Trim() -replace "\s+", " "))
$ver = RunSql "postgres" "SELECT version();" $true
Say ("  version() of the stand: {0}" -f ($ver.Text.Trim() -replace "\s+", " "))
Say "  (recorded on purpose: the fix is meaningful on any PostgreSQL with IDENTITY, but the proof must say WHERE it was taken)"
$exists = RunSql "postgres" ("SELECT 'NAME_TAKEN=' || (EXISTS (SELECT 1 FROM pg_database WHERE datname = '{0}'))::text;" -f $TestDb) $true
Say ("  target name check : {0}" -f ($exists.Text.Trim() -replace "\s+", " "))
if ($exists.Text -match "NAME_TAKEN=t") { Say "  *** the name is taken - this probe never reuses an existing database; aborting"; Fin $false }
if ($exists.Text -notmatch "NAME_TAKEN=f") { Say "  *** no answer received - absence of NAME_TAKEN=t is NOT the same as NAME_TAKEN=f; aborting"; Fin $false }
Say "  G1 PASS"
Say ""

Say "===== SETUP  create the throwaway database and a schema shaped like ours ====="
$mk = RunSql "postgres" ("CREATE DATABASE {0};" -f $TestDb) $true
Say ("  CREATE DATABASE {0} -> rc {1}" -f $TestDb, $mk.Rc)
if ($mk.Rc -ne 0) { Say $mk.Text; Say "  *** could not create the database; aborting"; Fin $false }
$created = $true
$schema = @'
CREATE SCHEMA identity;
CREATE TABLE public."RTSGrid_Cell" ("CellId" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, note text);
CREATE TABLE public.plain_serial (id serial PRIMARY KEY, note text);
CREATE TABLE identity."RoleClaims" ("Id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, note text);
INSERT INTO public."RTSGrid_Cell" ("CellId", note) OVERRIDING SYSTEM VALUE VALUES (16, 'seeded with an explicit id');
INSERT INTO identity."RoleClaims" ("Id", note) OVERRIDING SYSTEM VALUE VALUES (7, 'seeded with an explicit id');
INSERT INTO public.plain_serial (id, note) VALUES (4, 'seeded with an explicit id');
'@
$sc = RunSql $TestDb $schema $true
Say ("  schema+seed -> rc {0}   (3 sequences: 2 IDENTITY incl. PascalCase in a non-public schema, 1 old-style serial)" -f $sc.Rc)
if ($sc.Rc -ne 0) { Say $sc.Text }
$census = RunSql $TestDb "SELECT 'deptype a=' || count(*) FILTER (WHERE d.deptype='a')::text || ' i=' || count(*) FILTER (WHERE d.deptype='i')::text FROM pg_class s JOIN pg_depend d ON d.objid=s.oid JOIN pg_namespace n2 ON n2.oid=s.relnamespace WHERE s.relkind='S' AND n2.nspname IN ('public','identity','audit') AND d.deptype IN ('a','i');" $true
Say ("  census of the throwaway database : {0}" -f ($census.Text.Trim() -replace "\s+", " "))
$oldfilter = RunSql $TestDb "SELECT 'OLD FILTER deptype=a sees ' || count(*)::text || ' of 3' FROM pg_class s JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a' JOIN pg_namespace n2 ON n2.oid=s.relnamespace WHERE s.relkind='S' AND n2.nspname IN ('public','identity','audit');" $true
Say ("  {0}" -f ($oldfilter.Text.Trim() -replace "\s+", " "))
Say "  expected 1 of 3 - the stand must be able to REPRODUCE the original blindness, not only the fix;"
Say "  if the old filter saw 3 here, scenario C below would be green with nothing to compare against"
$oldSees1 = ($oldfilter.Text -match "sees 1 of 3")
Say ("  stand reproduces the defect : {0}" -f $oldSees1)
if (-not $oldSees1) { Say "  *** the stand does not reproduce the original blindness - scenario C would prove nothing; aborting"; Fin $false }
Say ""

$raw = Get-Content $Script -Raw
$sqlM = [regex]::Match($raw, "(?s)\`$seqResyncSql = @'\r?\n(.*?)\r?\n'@")
$parseM = [regex]::Match($raw, "(?s)(# RAISE NOTICE goes to stderr.*?Write-Host `"  Sequences resynced: \`$resyncN`" -ForegroundColor Green)")
Say "===== THE ARTIFACT ITSELF, not a copy ====="
Say ("  SQL block extracted from the file    : {0} ({1} chars)" -f $sqlM.Success, $sqlM.Groups[1].Value.Length)
Say ("  parsing block extracted from the file: {0} ({1} chars)" -f $parseM.Success, $parseM.Groups[1].Value.Length)
if (-not ($sqlM.Success -and $parseM.Success)) { Say "  *** could not lift the blocks out of the script - this probe would be testing itself; aborting"; Fin $false }
$sqlBlock = $sqlM.Groups[1].Value
$parseBlock = $parseM.Groups[1].Value
Say ""

function RunScenario($label, $sqlVariant, $expectStop, $expectMarker) {
    $sqlFile = Join-Path $env:TEMP ("seqproof_sql_{0}_{1}.sql" -f $stamp, $label)
    [IO.File]::WriteAllText($sqlFile, $sqlVariant, (New-Object System.Text.UTF8Encoding($false)))
    $harness = @"
`$psql = '$($script:psql)'
`$DBHost = '$DBHost'
`$DBPort = '$DBPort'
`$SuperUser = '$SuperUser'
`$Database = '$TestDb'
`$TmpSql = '$sqlFile'
$parseBlock
exit 0
"@
    $hf = Join-Path $env:TEMP ("seqproof_harness_{0}_{1}.ps1" -f $stamp, $label)
    [IO.File]::WriteAllText($hf, $harness, (New-Object System.Text.UTF8Encoding($true)))
    $out = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $hf 2>&1
    $rc = $LASTEXITCODE
    $text = ($out | Out-String)
    Say ("  child process exit code : {0}   (expected {1})" -f $rc, $(if ($expectStop) { "1 = install stops" } else { "0 = install continues" }))
    foreach ($ln in ($text -split "`r?`n")) { if ($ln.Trim()) { Say ("      | {0}" -f $ln.TrimEnd()) } }
    $markerSeen = ($text -match [regex]::Escape($expectMarker))
    Say ("  expected wording present : {0}" -f $markerSeen)
    Say ("  looked for : {0}" -f $expectMarker)
    Remove-Item $hf, $sqlFile -ErrorAction SilentlyContinue
    $ok = (($expectStop -and ($rc -eq 1)) -or ((-not $expectStop) -and ($rc -eq 0))) -and $markerSeen
    return $ok
}

Say "===== A  NEGATIVE HALF FIRST - a filter that matches nothing must STOP the install ====="
$sqlA = $sqlBlock.Replace("d.deptype IN ('a','i')", "d.deptype='x'")
Say ("  variant built by replacing the filter; differs from the original : {0}" -f ($sqlA -ne $sqlBlock))
$okA = RunScenario "A" $sqlA $true "processed 0 sequences"
Say ("  A : {0}" -f $(if ($okA) { "PASS - the step can go red" } else { "FAIL - a step that cannot stop is not a gate" }))
Say ""

Say "===== B  THIRD OUTCOME - no count line is NOT the same as count=0 ====="
$sqlB = [regex]::Replace($sqlBlock, "(?m)^\s*RAISE NOTICE 'RESYNC count=%', seq_count;\s*$", "")
Say ("  variant built by removing the RAISE NOTICE line; differs from the original : {0}" -f ($sqlB -ne $sqlBlock))
$okB = RunScenario "B" $sqlB $true "did not report a count"
Say ("  B : {0}" -f $(if ($okB) { "PASS - silence takes its own branch, with its own wording" } else { "FAIL" }))
Say ""

Say "===== C  POSITIVE - the unmodified block reports the real number and lets the install go on ====="
Say "  expected : count = 3 (two IDENTITY sequences, one serial), install continues"
$okC = RunScenario "C" $sqlBlock $false "Sequences resynced: 3"
Say ("  C : {0}" -f $(if ($okC) { "PASS" } else { "FAIL" }))
Say ""

Say "===== D  and the point of it all: did the counters actually move? ====="
Say "  v3 note: in v2 this section died on 'invalid command \\' - the PowerShell escape \\\" put a LITERAL"
Say "  backslash into the SQL file. Same family as the stripped quotes: my text was mangled between me and"
Say "  the native tool. Fixed by writing the SQL as a here-string, with no PowerShell escaping at all."
$sqlAfter = @'
SELECT 'RTSGrid_Cell seq last_value=' || last_value::text FROM public."RTSGrid_Cell_CellId_seq";
'@
$after = RunSql $TestDb $sqlAfter $true
Say ("  {0}" -f ($after.Text.Trim() -replace "\s+", " "))
Say "  expected: 16 - the seeded maximum. Before the fix this sequence stayed at 1 and the next insert collided."
$sqlIns = @'
INSERT INTO public."RTSGrid_Cell" (note) VALUES ('insert after resync');
'@
$ins = RunSql $TestDb $sqlIns $true
Say ("  a real insert after the resync -> rc {0}   (0 means no 23505; this is the defect that cost a day)" -f $ins.Rc)
if ($ins.Rc -ne 0) { Say $ins.Text }
$okD = ($ins.Rc -eq 0)
Say ""

Say "===== CLEANUP  drop exactly what was created, and say so ====="
$drop = RunSql "postgres" ("DROP DATABASE IF EXISTS {0};" -f $TestDb) $true
Say ("  DROP DATABASE {0} -> rc {1}" -f $TestDb, $drop.Rc)
$gone = RunSql "postgres" ("SELECT 'STILL_THERE=' || (EXISTS (SELECT 1 FROM pg_database WHERE datname = '{0}'))::text;" -f $TestDb) $true
Say ("  after cleanup : {0}   (must say f)" -f ($gone.Text.Trim() -replace "\s+", " "))
$env:PGPASSWORD = ""
Say ""

Say "===== SUMMARY ====="
Say ("  A negative (stops on zero)      : {0}" -f $okA)
Say ("  B third outcome (no count line) : {0}" -f $okB)
Say ("  C positive (real number)        : {0}" -f $okC)
Say ("  D insert after resync succeeds  : {0}" -f $okD)
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: SEQFIX-PROOF-V3-COMPLETE ====="
$all = ($okA -and $okB -and $okC -and $okD)
Say ("  LAST LINE : {0}" -f $(if ($all) { "PASS" } else { "FAIL (read the scenarios)" }))
Fin $all
