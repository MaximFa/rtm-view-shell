#Requires -Version 5.1
<#
  PROBE 234 / identity   -   READ ONLY. Nothing is stopped, changed or written outside output\.
  WHERE IT RUNS : server 234.
  PURPOSE       : establish the reference identity of the target machine, asked OF the machine,
                  so that every future box can refuse to run anywhere else.
                  On 2026-09-06 it turned out that the operator's own workstation carries
                  RTMViewShell and RTMService, Running, under the same C:\RTMView\ paths.
                  Our boxes address services by NAME and the directory by PATH, and none of
                  them checks WHICH MACHINE it is on. Seven gates guarded the state of the
                  machine; none guarded its identity.
  THREE INDEPENDENT MARKS, all of which a future G0 must match:
    1. host name - asked of the machine, never taken from memory or from a message;
    2. hardware marks - MAC address and the VM UUID, tied to the iron, not to configuration;
    3. the presence of C:\RTMView-Ops\preserve_20260906_1230\ - a folder that cannot exist
       on the operator's workstation. It does not replace 1 and 2 (it can be created by
       accident); they do not replace it (they do not know we have worked here).
  NEGATIVE CONTROL : each mark is also compared against a deliberately wrong value, which must
                  NOT match. A check that cannot say "no" cannot say "yes" either.
#>

$ErrorActionPreference = "Continue"
$OpsRoot = "C:\RTMView-Ops"
$OutDir  = Join-Path $OpsRoot "output"
$server  = "234"
$topic   = "identity"

Write-Host "WHERE IT RUNS : server $server. READ ONLY."
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

Say "===== 1  host name - asked OF the machine ====="
$cn  = $env:COMPUTERNAME
$dns = [System.Net.Dns]::GetHostName()
$fqdn = ""
try { $fqdn = [System.Net.Dns]::GetHostEntry($dns).HostName } catch { $fqdn = "<lookup failed>" }
$cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
Say ("  COMPUTERNAME            : {0}" -f $cn)
Say ("  Dns.GetHostName()       : {0}" -f $dns)
Say ("  resolved FQDN           : {0}" -f $fqdn)
Say ("  Win32_ComputerSystem    : {0}   domain/workgroup: {1}" -f $cs.Name, $cs.Domain)
Say ("  all three agree         : {0}   (must be True - if not, say so, do not pick one)" -f (($cn -eq $dns) -and ($cn -eq $cs.Name)))
Say ("  NEGCTL name equals a wrong one ('NOT-THE-SERVER') : {0}   (must be False)" -f ($cn -eq 'NOT-THE-SERVER'))

Say ""
Say "===== 2  hardware marks - tied to the iron, not to configuration ====="
$prod = Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
Say ("  VM UUID                 : {0}" -f $prod.UUID)
Say ("  known from the RTM log  : E9516FFB-...   (compare the prefix by eye in the report)")
Say ("  UUID starts E9516FFB    : {0}" -f ("$($prod.UUID)".ToUpper().StartsWith("E9516FFB")))
Say ("  NEGCTL UUID starts 00000000 : {0}   (must be False)" -f ("$($prod.UUID)".ToUpper().StartsWith("00000000")))
Say "  --- network adapters with a MAC, up or down ---"
$nics = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue)
$macFlat = @()
foreach ($n in $nics) {
    $m = "$($n.MACAddress)".Replace(":","").ToUpper()
    $macFlat += $m
    Say ("      {0,-40} {1}   netEnabled={2}" -f $n.Name, $n.MACAddress, $n.NetEnabled)
}
Say ("  a MAC equal to 000D3AD3061B is present : {0}" -f ($macFlat -contains "000D3AD3061B"))
Say ("  NEGCTL a MAC equal to 000000000000     : {0}   (must be False)" -f ($macFlat -contains "000000000000"))

Say ""
Say "===== 3  our own footprint - a folder that cannot exist on the operator's workstation ====="
$pres = Join-Path $OpsRoot "preserve_20260906_1230"
Say ("  {0} exists : {1}" -f $pres, (Test-Path $pres))
Say ("  {0}\ApplyService\env exists : {1}" -f $pres, (Test-Path (Join-Path $pres "ApplyService\env")))
Say ("  NEGCTL a preserve folder that must NOT exist : {0}   (must be False)" -f (Test-Path (Join-Path $OpsRoot "preserve_19000101_0000")))

Say ""
Say "===== 4  addresses, for the record - NOT used as a mark (they change) ====="
foreach ($ip in @(Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" -ErrorAction SilentlyContinue)) {
    Say ("      {0,-40} {1}" -f $ip.Description, ($ip.IPAddress -join ", "))
}

Say ""
Say "===== 5  what of ours is registered here, by name and path ====="
foreach ($n in @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')) {
    $s = Get-Service -Name $n -ErrorAction SilentlyContinue
    if ($s) {
        $w = Get-WmiObject Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue
        Say ("  PRESENT  {0,-16} {1,-9} {2}" -f $n, $s.Status, $w.PathName)
    } else { Say ("  absent   {0,-16}" -f $n) }
}

Say ""
Say "===== END-OF-RUN MARKER: IDENTITY-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, @(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "NOTHING WAS CHANGED."
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
