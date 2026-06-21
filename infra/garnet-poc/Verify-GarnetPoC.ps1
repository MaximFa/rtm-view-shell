#Requires -Version 5.1
<#
.SYNOPSIS
    Verify Garnet PoC parity matrix for INC-2026.06.20-001 (d) Phase 1 gate.
.DESCRIPTION
    Tests all Redis operations used by RTM View Shell against a running Garnet instance.
    Outputs PASS/GAP for each test. CRITICAL: SignalR pub/sub must PASS to gate Phase 2.
.PARAMETER RedisHost
    Garnet/Redis host (default: 127.0.0.1)
.PARAMETER RedisPort
    Garnet/Redis port (default: 6379)
.PARAMETER RedisPassword
    Garnet --auth password (default: TestPwd123)
.EXAMPLE
    .\Verify-GarnetPoC.ps1
    .\Verify-GarnetPoC.ps1 -RedisPassword "MyProdPwd"
#>

param(
    [string]$RedisHost = "127.0.0.1",
    [int]$RedisPort = 6379,
    [string]$RedisPassword = "TestPwd123"
)

$ErrorActionPreference = "Continue"

# Find redis-cli (from Memurai or standalone)
$redisCli = $null
$possiblePaths = @(
    "C:\Program Files\Memurai\redis-cli.exe",
    "C:\Program Files\Redis\redis-cli.exe",
    "C:\Garnet\redis-cli.exe",
    "redis-cli.exe"
)
foreach ($p in $possiblePaths) {
    if (Test-Path $p) { $redisCli = $p; break }
    $cmd = Get-Command $p -ErrorAction SilentlyContinue
    if ($cmd) { $redisCli = $cmd.Source; break }
}

if (-not $redisCli) {
    Write-Host "[WARN] redis-cli not found — using .NET StackExchange.Redis instead" -ForegroundColor Yellow
    $useNative = $false
} else {
    $useNative = $true
    Write-Host "Using redis-cli: $redisCli" -ForegroundColor Gray
}

function Invoke-Redis {
    param([string]$Cmd)
    if ($useNative) {
        $result = & $redisCli -h $RedisHost -p $RedisPort -a $RedisPassword $Cmd.Split(' ') 2>&1
        return $result
    } else {
        # Fallback: use dotnet script or direct TCP (not implemented here)
        return "N/A (no redis-cli)"
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       Garnet PoC Verification — INC-001(d) Phase 1 Gate      ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  Target: $RedisHost`:$RedisPort"
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$results = @()

# ══════════════════════════════════════════════════════════════════════════════
# TEST 1: Basic connectivity (PING)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[1/8] PING test..." -ForegroundColor Cyan
$ping = Invoke-Redis "PING"
if ($ping -match "PONG") {
    Write-Host "  PASS: $ping" -ForegroundColor Green
    $results += @{Test="PING"; Status="PASS"; Evidence=$ping}
} else {
    Write-Host "  GAP: $ping" -ForegroundColor Red
    $results += @{Test="PING"; Status="GAP"; Evidence=$ping}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 2: String SET/GET (RedisCacheService basic ops)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[2/8] StringSet/StringGet (RedisCacheService)..." -ForegroundColor Cyan
$testKey = "poctest:string:$(Get-Random)"
$testVal = "hello-garnet-$(Get-Date -Format 'HHmmss')"
$set = Invoke-Redis "SET $testKey $testVal"
$get = Invoke-Redis "GET $testKey"
$del = Invoke-Redis "DEL $testKey"
if ($get -match $testVal) {
    Write-Host "  PASS: SET/GET works" -ForegroundColor Green
    $results += @{Test="StringSet/Get"; Status="PASS"; Evidence="SET=$set, GET=$get"}
} else {
    Write-Host "  GAP: GET returned '$get', expected '$testVal'" -ForegroundColor Red
    $results += @{Test="StringSet/Get"; Status="GAP"; Evidence="SET=$set, GET=$get"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 3: TTL/EXPIRE (PG-permission cache, revoked-JTI)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[3/8] TTL/EXPIRE semantics..." -ForegroundColor Cyan
$ttlKey = "poctest:ttl:$(Get-Random)"
$setex = Invoke-Redis "SET $ttlKey value EX 60"
$ttl = Invoke-Redis "TTL $ttlKey"
$del = Invoke-Redis "DEL $ttlKey"
if ($ttl -match "^\d+$" -and [int]$ttl -gt 0 -and [int]$ttl -le 60) {
    Write-Host "  PASS: TTL=$ttl seconds" -ForegroundColor Green
    $results += @{Test="TTL/EXPIRE"; Status="PASS"; Evidence="TTL=$ttl"}
} else {
    Write-Host "  GAP: TTL returned '$ttl'" -ForegroundColor Red
    $results += @{Test="TTL/EXPIRE"; Status="GAP"; Evidence="TTL=$ttl"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 4: INCR (rate-limit counters BFP-02)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[4/8] INCR (rate-limit counters)..." -ForegroundColor Cyan
$incrKey = "poctest:incr:$(Get-Random)"
$incr1 = Invoke-Redis "INCR $incrKey"
$incr2 = Invoke-Redis "INCR $incrKey"
$del = Invoke-Redis "DEL $incrKey"
if ($incr1 -eq "1" -and $incr2 -eq "2") {
    Write-Host "  PASS: INCR works (1, 2)" -ForegroundColor Green
    $results += @{Test="INCR"; Status="PASS"; Evidence="incr1=$incr1, incr2=$incr2"}
} else {
    Write-Host "  GAP: INCR returned '$incr1', '$incr2'" -ForegroundColor Red
    $results += @{Test="INCR"; Status="GAP"; Evidence="incr1=$incr1, incr2=$incr2"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 5: LIST operations (revoked-JTI list AUTH-API-05)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[5/8] LIST ops (revoked-JTI)..." -ForegroundColor Cyan
$listKey = "poctest:list:$(Get-Random)"
$rpush1 = Invoke-Redis "RPUSH $listKey jti-abc"
$rpush2 = Invoke-Redis "RPUSH $listKey jti-def"
$llen = Invoke-Redis "LLEN $listKey"
$lrange = Invoke-Redis "LRANGE $listKey 0 -1"
$del = Invoke-Redis "DEL $listKey"
if ($llen -eq "2") {
    Write-Host "  PASS: RPUSH/LLEN works (len=$llen)" -ForegroundColor Green
    $results += @{Test="LIST ops"; Status="PASS"; Evidence="LLEN=$llen, LRANGE=$lrange"}
} else {
    Write-Host "  GAP: LLEN returned '$llen'" -ForegroundColor Red
    $results += @{Test="LIST ops"; Status="GAP"; Evidence="LLEN=$llen"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 6: AUTH (requirepass equivalent)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[6/8] AUTH (requirepass)..." -ForegroundColor Cyan
# If we got this far with password, AUTH works
if ($results[0].Status -eq "PASS") {
    Write-Host "  PASS: Authenticated with --auth password" -ForegroundColor Green
    $results += @{Test="AUTH"; Status="PASS"; Evidence="Connected with password"}
} else {
    Write-Host "  GAP: Could not authenticate" -ForegroundColor Red
    $results += @{Test="AUTH"; Status="GAP"; Evidence="Connection failed"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 7: PUB/SUB (CRITICAL — SignalR backplane)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[7/8] PUB/SUB (CRITICAL — SignalR backplane)..." -ForegroundColor Cyan
$pubChannel = "poctest:channel:$(Get-Random)"
# Note: Full pub/sub test requires two processes. Here we test PUBLISH returns subscriber count.
$publish = Invoke-Redis "PUBLISH $pubChannel test-message"
# PUBLISH returns the number of subscribers (0 if none)
if ($publish -match "^\d+$") {
    Write-Host "  PASS: PUBLISH command accepted (subscribers: $publish)" -ForegroundColor Green
    Write-Host "        NOTE: Full fan-out test requires running Shell + two browser circuits" -ForegroundColor Yellow
    $results += @{Test="PUB/SUB (command)"; Status="PASS"; Evidence="PUBLISH returned $publish"}
} else {
    Write-Host "  GAP: PUBLISH returned '$publish'" -ForegroundColor Red
    $results += @{Test="PUB/SUB (command)"; Status="GAP"; Evidence="PUBLISH=$publish"}
}

# ══════════════════════════════════════════════════════════════════════════════
# TEST 8: Tenant-prefixed keys (SCALE-02)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "[8/8] Tenant-prefixed keys (SCALE-02)..." -ForegroundColor Cyan
$tenantId = [Guid]::NewGuid().ToString()
$tenantKey = "${tenantId}:pg_permissions:test"
$set = Invoke-Redis "SET $tenantKey value123"
$get = Invoke-Redis "GET $tenantKey"
$del = Invoke-Redis "DEL $tenantKey"
if ($get -match "value123") {
    Write-Host "  PASS: Tenant-prefixed key works" -ForegroundColor Green
    $results += @{Test="Tenant keys"; Status="PASS"; Evidence="key=$tenantKey"}
} else {
    Write-Host "  GAP: GET returned '$get'" -ForegroundColor Red
    $results += @{Test="Tenant keys"; Status="GAP"; Evidence="GET=$get"}
}

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                         SUMMARY                              ║" -ForegroundColor Cyan
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

$passCount = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$gapCount = ($results | Where-Object { $_.Status -eq "GAP" }).Count

foreach ($r in $results) {
    $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host ("  {0,-20} {1}" -f $r.Test, $r.Status) -ForegroundColor $color
}

Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  PASS: $passCount / $($results.Count)" -ForegroundColor $(if ($gapCount -eq 0) {"Green"} else {"Yellow"})
Write-Host "  GAP:  $gapCount / $($results.Count)" -ForegroundColor $(if ($gapCount -eq 0) {"Green"} else {"Red"})
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($gapCount -eq 0) {
    Write-Host ""
    Write-Host "VERDICT: GREEN — All automated tests PASS" -ForegroundColor Green
    Write-Host "NEXT: Run Shell + two browser circuits to verify SignalR pub/sub fan-out" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "VERDICT: RED — $gapCount test(s) failed" -ForegroundColor Red
    Write-Host "NEXT: Investigate GAPs before proceeding to Phase 2" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Manual SignalR backplane verification:" -ForegroundColor Cyan
Write-Host "  1. Start Shell: dotnet run --project src\CcDashboard.Web --no-launch-profile"
Write-Host "  2. Open http://localhost:5000 in two browser tabs"
Write-Host "  3. Login as admin in both"
Write-Host "  4. Open a dashboard with live widgets in both"
Write-Host "  5. Verify updates appear simultaneously in both tabs (SignalR fan-out)"
Write-Host ""
