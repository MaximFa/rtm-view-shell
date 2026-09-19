#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step1b-hashes.ps1
  UNIT   PR234-DEPLOY-0ae2102 / STEP 1b - the hash set that steps 1 and 1-v2 both failed to take.
  WHY    In both runs every sha256 line was missing, with no error. Cause found afterwards:
         the helper was named  H , and PowerShell resolves ALIASES BEFORE FUNCTIONS - `h` is the
         built-in alias for Get-History. So `H $path` called Get-History with a string, the statement
         failed, and $ErrorActionPreference='Continue' swallowed it. The function was never reached.
         v2's try/catch could not help: the catch was inside a function that was never called.
         Here the helper is named Sha256Of, and a self-test proves it works BEFORE anything is measured.
  WHERE  SERVER 234 ONLY. G0 refuses to run anywhere else.
  CHANGES  NOTHING. This probe is read-only: no dump, no service, no config. The only file it creates
         is its own report under C:\RTMView-Ops\output\.
  ROLLBACK  Delete the report. There is nothing else to undo.
#>

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutDir = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outf = Join-Path $OutDir ("234_{0}_deploy0ae2102-step1b-hashes.txt" -f $stamp)
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add("$s"); Write-Host "$s" }
function Line() { Say ('-' * 78) }
function Fin($pass) {
  [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ""
  Write-Host ("REPORT: " + $outf)
  if ($pass) { exit 0 } else { exit 1 }
}
function Sha256Of($p) {
  if (-not (Test-Path -LiteralPath $p)) { return 'ABSENT' }
  try { return (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash }
  catch { return ('HASH-FAILED: ' + $_.Exception.GetType().Name + ': ' + $_.Exception.Message) }
}

Say ("STEP 1b  hash set  " + (Get-Date -Format u) + "   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say "READ ONLY. Nothing is started, stopped, dumped or changed."
Line

Say "G0  machine identity"
$nameOk = ($env:COMPUTERNAME -eq 'RTM')
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameOk + " / uuid match " + $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say "  G0 PASS"
Line

Say "SELF-TEST of the instrument, BEFORE it is used on anything that matters"
$tmp = Join-Path $env:TEMP ("sha_selftest_{0}.txt" -f $stamp)
[IO.File]::WriteAllText($tmp, 'abc', (New-Object System.Text.UTF8Encoding($false)))
$known = 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'  # sha256('abc')
$got = Sha256Of $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
Say ("  sha256 of the three bytes 'abc' : " + $got)
Say ("  expected                        : " + $known)
$selfOk = ($got -eq $known)
Say ("  SELF-TEST : " + $(if ($selfOk) { 'PASS - every ABSENT or HASH-FAILED below is a fact about the file, not about the tool' } else { 'FAIL - do not trust a single line below' }))
Say ("  NEGCTL a path that cannot exist : " + (Sha256Of 'C:\RTMView\zzz-no-such-file.dll') + "   (must be ABSENT)")
if (-not $selfOk) { Fin $false }
Line

Say "1  binaries the flight will re-measure after the install"
foreach ($f in @(
    'C:\RTMView\Shell\CcDashboard.Web.dll',
    'C:\RTMView\Shell\CcDashboard.Web.exe',
    'C:\RTMView\RTM\RTM.exe',
    'C:\RTMView\RTM\data.sys',
    'C:\RTMView\RTM.Twilio\RTM.Twilio.exe')) {
  Say ("  " + $f)
  Say ("      sha256 " + (Sha256Of $f))
  if (Test-Path -LiteralPath $f) {
    $i = Get-Item -LiteralPath $f
    Say ("      " + $i.Length + " B   modified " + $i.LastWriteTimeUtc.ToString('u'))
  }
}
Line

Say "2  config set - step 3 expects these SAME hashes; the installer must not rewrite them"
foreach ($c in @(
    'C:\RTMView\Shell\appsettings.json',
    'C:\RTMView\Shell\appsettings.Development.json',
    'C:\RTMView\RTM\appsettings.json',
    'C:\RTMView\RTM\log4net.config',
    'C:\RTMView\RTM.Twilio\appsettings.json')) {
  Say ("  " + $c)
  Say ("      sha256 " + (Sha256Of $c))
}
Line

Say "3  the floor taken by step 1, re-hashed here so the dump can be identified later"
$dumps = @(Get-ChildItem -LiteralPath 'C:\RTMView-Ops\backup' -Filter 'rtmviewdb_pre0ae2102_*.dump' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ("  dumps matching the flight's name : " + $dumps.Count)
foreach ($d in $dumps) {
  Say ("  " + $d.FullName)
  Say ("      " + $d.Length + " B   " + $d.LastWriteTimeUtc.ToString('u'))
  Say ("      sha256 " + (Sha256Of $d.FullName))
}
Line

Say "VERDICT"
Say ("  self-test : " + $selfOk)
Say  "  This probe changed nothing. It only supplies the hashes that step 3 will compare against."
Say "===== END-OF-RUN MARKER: STEP1B-COMPLETE ====="
Fin $true
