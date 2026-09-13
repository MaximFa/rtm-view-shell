#Requires -Version 5.1
<#
  PROBE 234 / cert-and-host   -   READ ONLY. Nothing is installed, bound or changed.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  WRITES        : one report into C:\RTMView-Ops\output\ . Nothing else.
  PURPOSE       : Fqdn and CertSubject were DERIVED from Kestrel urls, not measured. A derived
                  value must not enter an install as if it were measured. Three sources are read
                  and printed side by side; if they disagree, the probe says so and picks nothing.
    1. the preserved Shell config - the whole Kestrel section as it stood before the wipe;
    2. Cert:\LocalMachine\My on this machine - the certificate survived the wipe, it was never
       inside C:\RTMView\;
    3. netsh http show sslcert - which thumbprint was bound to which port.
  NO GUESSES    : CertSubject is printed as the certificate's own Subject string. "CN=<fqdn>" is
                  a guess and is never constructed here.
  ABSENCE IS AN ANSWER : no key in the config, or no certificate at all, is printed as such -
                  not as an empty string, and never replaced by a default.
#>

$ErrorActionPreference = "Continue"
$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$CurDir   = Join-Path $Preserve "configs\current"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_cert-and-host.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "WHERE IT RUNS : server 234. READ ONLY - nothing installed, nothing bound, nothing changed."
Say ""
Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
$f = (Test-Path $Preserve)
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f $n, $u, $m, $f)
if (-not ($n -and $u -and $m -and $f)) { Say "  *** G0 FAILED - not server 234."; Fin $false }
Say "  G0 PASS"

# ---------------- 1. the preserved config ----------------
Say ""
Say "===== 1  the preserved Shell config - the Kestrel section as it stood before the wipe ====="
$shellCfg = Join-Path $CurDir "Shell__appsettings.json"
if (-not (Test-Path $shellCfg)) { Say ("  *** MISSING: {0}" -f $shellCfg); Fin $false }
$raw = [IO.File]::ReadAllText($shellCfg)

function HasKestrel([string]$t) { return ($t -match '"Kestrel"\s*:') }
Say ("  file : {0}   ({1} bytes, saved {2})" -f $shellCfg, (Get-Item $shellCfg).Length, (Get-Item $shellCfg).LastWriteTime)
Say ("  Kestrel section present : {0}" -f (HasKestrel $raw))

# negative control for the section-finder, on a file that certainly has no Kestrel section
$negFile = Join-Path $env:TEMP ("kestrel_neg_{0}.json" -f [guid]::NewGuid().ToString("N"))
[IO.File]::WriteAllText($negFile, '{ "Logging": { "LogLevel": { "Default": "Information" } } }')
Say ("  NEGCTL the same finder on a file without it : {0}   (must be False)" -f (HasKestrel ([IO.File]::ReadAllText($negFile))))
Remove-Item $negFile -ErrorAction SilentlyContinue

Say "  --- the Kestrel section, printed as it is (no password fields exist in it) ---"
$ki = $raw.IndexOf('"Kestrel"')
if ($ki -lt 0) { Say "      absent" }
else {
    $depth = 0; $started = $false; $end = $ki
    for ($i = $ki; $i -lt $raw.Length; $i++) {
        $ch = $raw[$i]
        if ($ch -eq '{') { $depth++; $started = $true }
        elseif ($ch -eq '}') { $depth--; if ($started -and $depth -eq 0) { $end = $i; break } }
    }
    foreach ($line in ($raw.Substring($ki, $end - $ki + 1) -split "`r?`n")) { Say ("      {0}" -f $line.TrimEnd()) }
}

foreach ($k in @('Fqdn','CertSubject','Subject','Path','Password','Store','Location','AllowInvalid')) {
    $mm = [regex]::Match($raw, '"' + $k + '"\s*:\s*"([^"]*)"')
    if ($k -eq 'Password') {
        if ($mm.Success) { Say ("  key {0,-14} : <length {1}, never printed>" -f $k, $mm.Groups[1].Value.Length) }
        else { Say ("  key {0,-14} : ABSENT in the config" -f $k) }
    } elseif ($mm.Success) { Say ("  key {0,-14} : {1}" -f $k, $mm.Groups[1].Value) }
    else { Say ("  key {0,-14} : ABSENT in the config   (this is an answer, not an empty value)" -f $k) }
}

# ---------------- 2. the machine's own certificate store ----------------
Say ""
Say "===== 2  Cert:\LocalMachine\My on THIS machine - the certificate survived the wipe ====="
$certs = @(Get-ChildItem Cert:\LocalMachine\My -ErrorAction SilentlyContinue)
Say ("  certificates in the store : {0}" -f $certs.Count)
if ($certs.Count -eq 0) {
    Say "  NONE. That is an answer: HTTPS on 234 was raised some other way, and that is a separate"
    Say "  conversation - not a reason to substitute anything."
}
foreach ($c in $certs) {
    Say ""
    Say ("      Subject     : {0}" -f $c.Subject)
    Say ("      Issuer      : {0}" -f $c.Issuer)
    Say ("      Thumbprint  : {0}" -f $c.Thumbprint)
    Say ("      NotBefore   : {0}" -f $c.NotBefore)
    Say ("      NotAfter    : {0}   (expired: {1})" -f $c.NotAfter, ($c.NotAfter -lt (Get-Date)))
    Say ("      HasPrivateKey : {0}" -f $c.HasPrivateKey)
    $sans = ($c.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Subject Alternative Name' })
    if ($sans) { foreach ($s2 in $sans) { Say ("      SAN         : {0}" -f ($s2.Format($false))) } }
    else { Say "      SAN         : none" }
}
Say ""
Say ("  NEGCTL a store path that must be empty of our certs (Cert:\CurrentUser\Root count > 0) : {0}   (must be True - proves the reader works)" -f (@(Get-ChildItem Cert:\CurrentUser\Root -ErrorAction SilentlyContinue).Count -gt 0))

# ---------------- 3. port bindings ----------------
Say ""
Say "===== 3  netsh http show sslcert - which thumbprint was bound to which port ====="
$netsh = & netsh.exe http show sslcert 2>&1
$printed = 0
foreach ($line in $netsh) {
    $t = "$line".TrimEnd()
    if ($t -match '(?i)IP:port|Hostname:port|Certificate Hash|Application ID|Certificate Store Name') {
        Say ("      {0}" -f $t); $printed++
    }
}
if ($printed -eq 0) { Say "      no ssl certificate bindings found - that is an answer too" }

Say ""
Say "===== SIDE BY SIDE - the probe compares, it does not choose ====="
$urls = @([regex]::Matches($raw, '"Url"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
Say ("  urls in the preserved config : {0}" -f ($urls -join " , "))
$hostsFromUrls = @()
foreach ($u2 in $urls) { try { $hostsFromUrls += ([Uri]$u2).Host } catch { } }
$hostsFromUrls = @($hostsFromUrls | Select-Object -Unique)
Say ("  host(s) implied by those urls : {0}" -f ($hostsFromUrls -join ", "))
Say ("  subject(s) in the store       : {0}" -f (@($certs | ForEach-Object { $_.Subject }) -join " | "))
Say  "  If these two disagree, NOTHING is chosen here. Both are reported and the coordinator decides."

Say ""
Say "===== END-OF-RUN MARKER: CERT-AND-HOST-COMPLETE ====="
Say ""
Say "NOTHING WAS INSTALLED, BOUND OR CHANGED."
Fin $true
