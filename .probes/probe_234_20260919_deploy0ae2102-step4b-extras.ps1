#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step4b-extras.ps1
  UNIT   PR234-DEPLOY-0ae2102 / STEP 4b - naming the 70 routines that remain "extra on server".
  WHY    Step 4 v2 measured, on the live server, Missing 46 -> 0 and Extra 116 -> 70. The notation
         defect is gone. But the bar named before the run was "every remaining line is named", and the
         comparator prints only the FIRST TEN. Ten named out of seventy is not seventy named.
         The ten visible ones (armor, crypt, digest, encrypt, dearmor...) all look like pgcrypto, i.e.
         functions owned by a PostgreSQL EXTENSION, which our baseline corpus does not contain by design.
         That is a hypothesis about the other sixty. This probe tests it instead of believing it.
  HOW    Arithmetic that leaves no room for a comfortable answer:
           public routines total            = T
           owned by an extension (pg_depend deptype='e')  = X, grouped and named by extension
           not owned by any extension       = T - X
         Step 4 measured Missing = 0, so every baseline routine IS on the server. Therefore
           Extra = T - (baseline set size)  and, if X equals Extra exactly, every extra is
         extension-owned and the remainder is explained in full. If X is smaller, the difference is
         OURS and this probe lists each of those routines individually - no summary, no "and others".
  WHERE  SERVER 234 ONLY. READ ONLY - SELECT only, no writes anywhere but its own report.
  ROLLBACK  Delete the report.
#>

param(
  [int]$ExtrasReportedByStep4 = 70
)

$ErrorActionPreference = 'Continue'
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_deploy0ae2102-step4b-extras.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList

function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("STEP 4b  WHO ARE THE EXTRAS  " + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY - SELECT only. Nothing on this server is modified."
Write-Report
Rule

Say "G0  machine identity"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Rule

$psqlPath = $null
foreach ($pgVersionDir in @(Get-ChildItem -LiteralPath 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgVersionDir.FullName 'bin\psql.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
if ($null -eq $psqlPath) { Say "  psql not found - STOP"; Finish $false }
Say ("  psql : " + $psqlPath)

$securePassword = Read-Host -Prompt 'Password for ccdashboard_user@127.0.0.1:5433/rtmviewdb (SELECT only)' -AsSecureString
if (-not $securePassword -or $securePassword.Length -eq 0) { Say "  nothing supplied - STOP"; Finish $false }
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
Rule

function Invoke-Sql([string]$sqlText) {
  $queryFile = Join-Path $env:TEMP ("step4b_{0}_{1}.sql" -f $RunStamp, (Get-Random))
  [IO.File]::WriteAllText($queryFile, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
  $rows = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -At -F '|' -f $queryFile 2>&1
  $script:LastSqlExit = $LASTEXITCODE
  Remove-Item -LiteralPath $queryFile -ErrorAction SilentlyContinue
  return @($rows | ForEach-Object { "$_" })
}

Say "COUNTS"
$countRows = Invoke-Sql @'
SELECT 'total|' || count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
SELECT 'extension_owned|' || count(*)::text
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  JOIN pg_depend d ON d.objid=p.oid AND d.classid='pg_proc'::regclass AND d.deptype='e'
  WHERE n.nspname='public';
SELECT 'NEGCTL_impossible|' || count(*)::text FROM pg_proc WHERE proname='zzz_no_such_routine_here';
'@
foreach ($countRow in $countRows) { Say ("  " + $countRow) }
Say ("  psql exit : " + $script:LastSqlExit)
$totalRoutines = -1; $extensionOwned = -1
foreach ($countRow in $countRows) {
  if ($countRow -match '^total\|(\d+)$')            { $totalRoutines  = [int]$Matches[1] }
  if ($countRow -match '^extension_owned\|(\d+)$')  { $extensionOwned = [int]$Matches[1] }
}
Rule

Say "EXTENSION-OWNED ROUTINES, grouped and named by the extension that owns them"
$byExtension = Invoke-Sql @'
SELECT e.extname || '|' || count(*)::text
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  JOIN pg_depend d ON d.objid=p.oid AND d.classid='pg_proc'::regclass AND d.deptype='e'
  JOIN pg_extension e ON e.oid=d.refobjid
  WHERE n.nspname='public'
  GROUP BY e.extname ORDER BY 1;
'@
foreach ($extensionRow in $byExtension) { Say ("  " + $extensionRow) }
Rule

Say "ROUTINES OWNED BY NO EXTENSION - these are OURS, and every one is named"
$ourRoutines = Invoke-Sql @'
SELECT p.proname || '(' ||
       COALESCE((SELECT string_agg(format_type(t.oid, NULL), ', ' ORDER BY x.ord)
                 FROM unnest(p.proargtypes) WITH ORDINALITY AS x(oid, ord)
                 JOIN pg_type t ON t.oid = x.oid), '') || ')'
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public'
    AND NOT EXISTS (SELECT 1 FROM pg_depend d
                    WHERE d.objid=p.oid AND d.classid='pg_proc'::regclass AND d.deptype='e')
  ORDER BY 1;
'@
Say ("  count : " + $ourRoutines.Count)
foreach ($ourRoutine in $ourRoutines) { Say ("    . " + $ourRoutine) }
Rule

Say "THE ARITHMETIC"
$ourCount = $totalRoutines - $extensionOwned
Say ("  public routines total            : " + $totalRoutines)
Say ("  owned by an extension            : " + $extensionOwned)
Say ("  ours (owned by no extension)     : " + $ourCount)
Say ("  extras reported by step 4        : " + $ExtrasReportedByStep4)
Say ("  missing reported by step 4       : 0   (so every baseline routine IS on the server)")
$extrasFullyExplained = ($extensionOwned -eq $ExtrasReportedByStep4)
if ($extrasFullyExplained) {
  Say  "  => extension-owned count EQUALS the extras count: every extra is an extension function."
  Say  "     The baseline corpus does not carry extension functions, and is not meant to."
} else {
  Say ("  => they DO NOT match. " + [math]::Abs($extensionOwned - $ExtrasReportedByStep4) + " routine(s) are unaccounted for.")
  Say  "     The full list of OUR routines is printed above; the unexplained ones are among them and"
  Say  "     must be compared against the baseline corpus by name before anyone calls CMP-01 closed."
}
Rule

Say "VERDICT OF STEP 4b"
Say ("  every 'extra on server' explained : " + $extrasFullyExplained)
Say  "  This does NOT by itself close CMP-01 2/2b - it removes the last unnamed remainder from step 4."
Say "===== END-OF-RUN MARKER: STEP4B-COMPLETE ====="
$env:PGPASSWORD = ''
Finish $extrasFullyExplained
