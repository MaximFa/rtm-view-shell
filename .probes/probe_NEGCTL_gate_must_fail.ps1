#Requires -Version 5.1
<#
  NEGATIVE CONTROL for the probe gate. NOT a measurement of anything. NEVER hand this to the operator.
  Its only job is to FAIL every check the gate claims to have, so that a gate which passes everything
  can be told apart from a gate that is switched off. One deliberate fault per class.
  Run it as: python3 tools/lint_probe.py .probes/probe_NEGCTL_gate_must_fail.ps1   -> must print faults.
#>
$L = New-Object System.Collections.ArrayList          # 1. one-letter name
function H($p) { (Get-FileHash $p).Hash }             # 2. shadowed by the alias h = Get-History
foreach ($l in @('a','b')) { [void]$L.Add($l) }       # 3. $l and $L are ONE variable, same scope
$when = Get-Date -Format u                            # 4. local time wearing a 'Z' ...
$utc  = (Get-Date).ToUniversalTime()                  #    ... beside a real UTC value
if ($when -like '*[E1]*') { 'never' }                 # 5. [ ] in -like is a character class
$newest = Get-ChildItem C:\Temp -Filter *.txt | Sort-Object LastWriteTime -Descending | Select-Object -First 1
& powershell.exe -File C:\Temp\x.ps1 -Arg ''          # 6. empty string through -File is dropped
[IO.File]::WriteAllLines('C:\Temp\r.txt', $L)         # 7. report written in ONE place only
