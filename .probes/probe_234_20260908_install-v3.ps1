#Requires -Version 5.1
<#
  PROBE 234 / install   -   CLEAN INSTALL with the fixed installer.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  SAFETY        : without -Proceed it ONLY reads and prints what WOULD be run. Nothing installs.
  SECRETS       : every password is read from preserve_\configs\current on this machine, or typed
                  here by the operator. NONE is ever printed - only its length. The command line
                  shown before the run has them masked.
  MANDATORY     : -FreshDb. Without it the installer takes the other branch and restores a dump
                  from the package instead of creating a clean database - invisibly.
                  -DBPort 5433. PG15 on 5432 is a foreign estate and is never touched.
  ONE-SHOT      : §5.0 - the hash of whatever data.sys the installer leaves is taken IMMEDIATELY
                  after the install and BEFORE we return ours. That window exists once.
  NOT HERE      : returning data.sys, installing the adapter, acceptance checks. Separate steps.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$Pkg      = "C:\Temp\install_234"
$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$CurDir   = Join-Path $Preserve "configs\current"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_install.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

# Masks a connection string BY CONTENT: every key=value pair whose KEY looks like a secret has
# its VALUE replaced by length + sha256 prefix. On 2026-09-08 the previous version printed the
# Redis connection string whole, password included, because it classified the field by its NAME
# ("a connection string") instead of looking at what was inside it.
function MaskConn([string]$cs) {
    if (-not $cs) { return "<absent>" }
    $out = @()
    foreach ($part in $cs.Split(',')) {
        $i = $part.IndexOf('=')
        if ($i -lt 1) { $out += $part.Trim(); continue }
        $k = $part.Substring(0,$i).Trim()
        $v = $part.Substring($i+1)
        if ($k -match '(?i)password|pwd|secret|token|key$') {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $h = ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($v)) | ForEach-Object { $_.ToString("X2") }) -join ""
            $sha.Dispose()
            $out += ("{0}=<length {1}, sha256 {2}, never printed>" -f $k, $v.Length, $h.Substring(0,8))
        } else { $out += ("{0}={1}" -f $k, $v) }
    }
    return ($out -join ", ")
}
function ConnPart([string]$cs, [string]$key) {
    if (-not $cs) { return $null }
    foreach ($part in $cs.Split(',')) {
        $i = $part.IndexOf('=')
        if ($i -lt 1) { continue }
        if ($part.Substring(0,$i).Trim() -ieq $key) { return $part.Substring($i+1) }
    }
    return $null
}

Say ("mode : {0}" -f $(if ($Proceed) { "INSTALL (-Proceed given)" } else { "PREVIEW ONLY - nothing will be installed" }))
Say ""

# ---------------- G0 ----------------
Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
$f = (Test-Path $Preserve)
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f $n, $u, $m, $f)
if (-not ($n -and $u -and $m -and $f)) { Say "  *** G0 FAILED - not server 234."; Fin $false }
Say "  G0 PASS"

$fail = 0

# ---------------- P0 redact the secret this probe itself leaked on 2026-09-08 ----------------
Say ""
Say "===== P0 redacting the password this probe printed in clear text on 2026-09-08 ====="
$leaked = @(Get-ChildItem $OutDir -File -Filter "234_*_install.txt" -ErrorAction SilentlyContinue)
$done = 0
foreach ($lf in $leaked) {
    $c = [IO.File]::ReadAllText($lf.FullName, [Text.Encoding]::UTF8)
    $mm = [regex]::Match($c, '(?i)(password|pwd|secret|token)\s*=\s*([^\s,;"<]+)')
    if (-not $mm.Success) { continue }
    $val = $mm.Groups[2].Value
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $h = ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($val)) | ForEach-Object { $_.ToString("X2") }) -join ""
    $sha.Dispose()
    $before = (Get-FileHash $lf.FullName -Algorithm SHA256).Hash
    $c2 = $c.Remove($mm.Groups[2].Index, $val.Length).Insert($mm.Groups[2].Index, ("<REDACTED length {0} sha256 {1}>" -f $val.Length, $h.Substring(0,16)))
    $c2 += "`r`n===== REDACTION NOTICE =====`r`n"
    $c2 += ("  a password was written here in clear text - a defect of the probe that wrote it`r`n")
    $c2 += ("  redacted {0} UTC; file sha256 before redaction {1}`r`n" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss"), $before)
    $c2 += ("  removed value: length {0}, sha256 {1}`r`n" -f $val.Length, $h)
    $c2 += "  the password itself was NOT changed - operator's decision of 2026-09-08`r`n"
    [IO.File]::WriteAllText($lf.FullName, $c2, (New-Object System.Text.UTF8Encoding($false)))
    Say ("  redacted: {0}   (removed value length {1})" -f $lf.Name, $val.Length)
    $done++
}
Say ("  files redacted : {0}" -f $done)
$still = @(Get-ChildItem $OutDir -File -Filter "234_*_install.txt" -ErrorAction SilentlyContinue |
           Where-Object { [IO.File]::ReadAllText($_.FullName) -match '(?i)(password|pwd|secret|token)\s*=\s*[^\s,;"<]' })
Say ("  files STILL carrying a clear-text secret : {0}   (must be 0)" -f $still.Count)
foreach ($x in $still) { Say ("      {0}" -f $x.Name) }
if ($still.Count -ne 0) { $fail++ }

# ---------------- P1 the package ----------------
Say ""
Say "===== P1 the package, and NO database dump in it ====="
$inst = @(Get-ChildItem $Pkg -Recurse -File -Filter "Install-RTMView.ps1" -ErrorAction SilentlyContinue)
Say ("  Install-RTMView.ps1 copies : {0}   (must be 1)" -f $inst.Count)
if ($inst.Count -ne 1) { Say "  *** STOP"; Fin $false }
$itxt = [IO.File]::ReadAllText($inst[0].FullName, [Text.Encoding]::UTF8)
$g1 = $itxt.Contains('$preserveShell')
$g2 = $itxt.Contains('Preserved:')
$g3 = ([regex]::Matches($itxt, [regex]::Escape('(package version ignored)'))).Count
Say ("  fixed-installer marks : preserve {0} / log line {1} / d01851a {2}   (True/True/2)" -f $g1, $g2, $g3)
if (-not ($g1 -and $g2 -and $g3 -eq 2)) { Say "  *** STOP - this is not the fixed installer."; $fail++ }

# dumps are found BY EXTENSION, never by folder name: Windows does not distinguish DB\ from db\,
# and on 2026-09-08 that made a probe count schema.sql as a dump.
$dumps = @(Get-ChildItem $Pkg -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Extension -in @('.dump','.backup') })
Say ("  files with a dump extension anywhere in the package : {0}   (must be 0)" -f $dumps.Count)
foreach ($x in $dumps) { Say ("      {0}  {1} bytes" -f $x.FullName, $x.Length) }
Say ("  NEGCTL the same predicate finds .sql files          : {0}   (must be > 0 - proves it can find)" -f @(Get-ChildItem $Pkg -Recurse -File -Filter "*.sql" -ErrorAction SilentlyContinue).Count)
if ($dumps.Count -ne 0) { Say "  *** STOP - a dump in the package would be restored if -FreshDb were ever dropped."; $fail++ }

# ---------------- P2 parameters, read from the preserved configs ----------------
Say ""
Say "===== P2 install parameters - read from preserve_, not from memory ====="
$shellCfg = Join-Path $CurDir "Shell__appsettings.json"
$rtmCfg   = Join-Path $CurDir "RTM__appsettings.json"
foreach ($p in @($shellCfg, $rtmCfg)) {
    if (-not (Test-Path $p)) { Say ("  *** MISSING: {0}" -f $p); $fail++ }
}
if ($fail -gt 0) { Say "  *** STOP"; Fin $false }

$sRaw = [IO.File]::ReadAllText($shellCfg)
$rRaw = [IO.File]::ReadAllText($rtmCfg)
function JVal([string]$raw, [string]$key) {
    $mm = [regex]::Match($raw, '"' + $key + '"\s*:\s*"([^"]*)"')
    if ($mm.Success) { return $mm.Groups[1].Value } else { return $null }
}
function ConnVal([string]$raw, [string]$key) {
    $mm = [regex]::Match($raw, $key + '\s*=\s*([^;"]+)')
    if ($mm.Success) { return $mm.Groups[1].Value.Trim() } else { return $null }
}

$dbHost   = ConnVal $rRaw "Host";     if (-not $dbHost)   { $dbHost   = ConnVal $sRaw "Host" }
$dbName   = ConnVal $rRaw "Database"; if (-not $dbName)   { $dbName   = ConnVal $sRaw "Database" }
$appUser  = ConnVal $rRaw "Username"; if (-not $appUser)  { $appUser  = ConnVal $sRaw "Username" }
$appPwd   = ConnVal $sRaw "Password"
$pipeName = JVal $rRaw "PipeName"
$tenantId = JVal $rRaw "TenantId"
$adaptor  = JVal $rRaw "AdaptorServiceName"
$slug     = JVal $sRaw "DefaultTenantSlug"
$superPwd = JVal $sRaw "SuperadminPassword"
$redisCs  = JVal $sRaw "Redis"

# CertSubject comes from the Certificate section of the preserved config, VERBATIM.
# Measured 2026-09-08: the config holds "insightense.com" - no "CN=", while the certificate in the
# store is "CN=*.insightense.com". A guessed "CN=insightense.com" would match NEITHER.
# It must be passed: if it is empty the installer falls into Read-Host and a non-interactive run
# hangs there mid-install. Same for -Fqdn.
$certSubject = $null
$ci = $sRaw.IndexOf('"Certificate"')
if ($ci -ge 0) {
    $mm = [regex]::Match($sRaw.Substring($ci), '"Subject"\s*:\s*"([^"]*)"')
    if ($mm.Success) { $certSubject = $mm.Groups[1].Value }
}
$urls = @([regex]::Matches($sRaw, '"Url"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
$fqdn = $null; $httpPort = $null; $httpsPort = $null
foreach ($u2 in $urls) {
    try {
        $uri = [Uri]$u2
        if ($uri.Scheme -eq 'http')  { $httpPort  = $uri.Port; if (-not $fqdn) { $fqdn = $uri.Host } }
        if ($uri.Scheme -eq 'https') { $httpsPort = $uri.Port; $fqdn = $uri.Host }
    } catch { }
}

Say ("  DBHost            = {0}" -f $dbHost)
Say ("  DBName            = {0}" -f $dbName)
Say ("  DBAppUser         = {0}" -f $appUser)
Say ("  DBAppPassword     = <length {0}, never printed>" -f $(if ($appPwd) { $appPwd.Length } else { 0 }))
Say ("  SuperadminPassword= <length {0}, never printed>" -f $(if ($superPwd) { $superPwd.Length } else { 0 }))
Say ("  DefaultTenantSlug = {0}" -f $slug)
Say ("  RTMPipeName       = {0}" -f $pipeName)
Say ("  RTMTenantId       = {0}" -f $tenantId)
Say ("  AdaptorServiceName= {0}   (adapter itself is installed by hand, later)" -f $adaptor)
Say ("  Kestrel urls      = {0}" -f ($urls -join " , "))
Say ("  -> Fqdn           = {0}   (DERIVED from the Kestrel url - the config has no Fqdn key)" -f $fqdn)
Say ("  -> ShellPort      = {0} / ShellHttpsPort = {1}   (from the Kestrel section, whole)" -f $httpPort, $httpsPort)
Say ("  CertSubject       = {0}   (VERBATIM from the config's Certificate.Subject - not constructed)" -f $(if ($certSubject) { $certSubject } else { "<ABSENT - HTTPS would be skipped>" }))
$redisPwd = ConnPart $redisCs "password"
Say ("  Redis conn string = {0}" -f (MaskConn $redisCs))
$redisHasPwd = ($redisPwd -ne $null -and $redisPwd.Length -gt 0)
Say ("  Redis needs a password : {0}   (it will be PASSED to the installer, not just printed)" -f $redisHasPwd)

foreach ($pair in @(@("DBHost",$dbHost), @("DBName",$dbName), @("DBAppUser",$appUser),
                    @("DBAppPassword",$appPwd), @("RTMPipeName",$pipeName), @("RTMTenantId",$tenantId))) {
    if (-not $pair[1]) { Say ("  *** MISSING VALUE: {0}" -f $pair[0]); $fail++ }
}
if (-not $fqdn)        { Say "  *** MISSING VALUE: Fqdn - the installer would stop at Read-Host and hang"; $fail++ }
if (-not $certSubject) { Say "  *** MISSING VALUE: CertSubject - the installer would stop at Read-Host and hang"; $fail++ }
if ($fail -gt 0) { Say "  *** STOP - a missing value would become a placeholder on the machine, or hang the run."; Fin $false }

Say ""
Say "  NOTE: measured 2026-09-08, not guessed. The config has no Fqdn/CertSubject KEYS, but it does"
Say "        carry the whole Kestrel section: the urls give the host and both ports, and"
Say "        Certificate.Subject gives the certificate name verbatim. The certificate itself is in"
Say "        LocalMachine\My (CN=*.insightense.com, thumbprint 828718...C26D, valid to 2027-01-03,"
Say "        private key present) and its SAN covers insightense.com."

# ---------------- the command, with secrets masked ----------------
Say ""
Say "===== the command that WOULD run ====="
Say ("  & `"{0}`" ``" -f $inst[0].FullName)
Say  "      -Mode Full -FreshDb ``"
Say  "      -DBPort 5433 ``"
Say ("      -DBHost {0} -DBName {1} ``" -f $dbHost, $dbName)
Say ("      -DBAppUser {0} -DBAppPassword <hidden> ``" -f $appUser)
Say  "      -DBPassword <typed by the operator, hidden> ``"
Say ("      -Fqdn {0} -CertSubject `"{1}`" -ShellPort {2} -ShellHttpsPort {3} ``" -f $fqdn, $certSubject, $httpPort, $httpsPort)
Say ("      -RTMPipeName {0} -RTMTenantId {1} ``" -f $pipeName, $tenantId)
Say ("      -AdaptorServiceName {0} ``" -f $adaptor)
Say  "      -SuperadminPassword <hidden> ``"
Say ("      {0}" -f $(if ($redisHasPwd) { "-RedisPassword <hidden>" } else { "-SkipRedis   (no password in the saved config)" }))

if (-not $Proceed) {
    Say ""
    Say "PREVIEW ONLY. Nothing was installed. Read the parameters above, then run again with -Proceed."
    Fin $true
}

# ---------------- LAYER 2: SENTINEL ----------------
if (-not $Proceed) {
    Say "*** SENTINEL: reached the install without -Proceed. Aborting."
    Fin $false
}

# ---------------- the superuser password, typed here, never printed ----------------
Say ""
Say "===== PostgreSQL superuser password ====="
Write-Host "Enter the postgres superuser password for the instance on port 5433 (input hidden):"
$sec = Read-Host -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$suPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
Say ("  superuser password entered : length {0}   (never printed, never written to the report)" -f $suPwd.Length)
if ($suPwd.Length -eq 0) { Say "  *** STOP - empty password."; Fin $false }

# ---------------- INSTALL ----------------
Say ""
Say "===== INSTALLING - fixed installer, -FreshDb, port 5433 ====="
$args = @(
  "-Mode","Full","-FreshDb",
  "-DBPort","5433",
  "-DBHost",$dbHost,"-DBName",$dbName,
  "-DBUser","postgres","-DBPassword",$suPwd,
  "-DBAppUser",$appUser,"-DBAppPassword",$appPwd,
  "-RTMPipeName",$pipeName,"-RTMTenantId",$tenantId,
  "-AdaptorServiceName",$adaptor,
  "-SuperadminPassword",$superPwd
)
if ($redisHasPwd) { $args += @("-RedisPassword",$redisPwd) } else { $args += @("-SkipRedis") }
if ($fqdn)        { $args += @("-Fqdn",$fqdn) }
if ($certSubject) { $args += @("-CertSubject",$certSubject) }
if ($httpPort)  { $args += @("-ShellPort","$httpPort") }
if ($httpsPort) { $args += @("-ShellHttpsPort","$httpsPort") }

Push-Location (Split-Path $inst[0].FullName -Parent)
$log = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $inst[0].FullName @args 2>&1
Pop-Location
$suPwd = $null

foreach ($line in $log) { Say ("  | {0}" -f $line) }

# ---------------- §5.0 - THE ONE-SHOT MEASUREMENT ----------------
Say ""
Say "===== 5.0 data.sys AS THE INSTALLER LEFT IT - before we return ours. This window exists ONCE ====="
$ds = "C:\RTMView\RTM\data.sys"
if (Test-Path $ds) {
    $h = (Get-FileHash $ds -Algorithm SHA256).Hash
    Say ("  present : size {0}, sha256 {1}, written {2}" -f (Get-Item $ds).Length, $h, (Get-Item $ds).LastWriteTime)
    Say ("  equals our preserved file (24F0BFAC...DE43) : {0}" -f ($h -eq "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"))
    Say  "  -> the installer PUT A data.sys THERE. Which one, the numbers above say."
} else {
    Say "  absent - the installer left no data.sys at all."
    Say "  This is an ANSWER, not a probe failure: on a clean machine there was nothing to overwrite."
}
Say "  (our file is NOT returned in this box - that is the next step)"

Say ""
Say "===== state right after the install ====="
foreach ($n3 in @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService')) {
    $s = Get-Service -Name $n3 -ErrorAction SilentlyContinue
    Say ("  {0,-16} {1}" -f $n3, $(if ($s) { $s.Status } else { "not registered" }))
}
Say  "  (RTMTwilio_1 and RTMApplyService are EXPECTED to be absent: the adapter is installed by"
Say  "   hand in the next step, and the installer does not register ApplyService at all)"
foreach ($n4 in @('RTM.Twilio','RTM')) {
    $s = Get-Service -Name $n4 -ErrorAction SilentlyContinue
    Say ("  NEVER {0,-14} {1}" -f $n4, $(if ($s) { $s.Status } else { "not present" }))
}
Say ("  C:\RTMView\ exists : {0}" -f (Test-Path "C:\RTMView"))
Say ("  preserve_ intact   : {0}" -f (Test-Path $Preserve))

Say ""
Say "===== END-OF-RUN MARKER: INSTALL-COMPLETE ====="
Fin ($fail -eq 0)
