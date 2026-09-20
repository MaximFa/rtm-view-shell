#Requires -Version 5.1
<#
.SYNOPSIS
    Tests for Select-RtmSchemaBlocks (PR234-CMP-01 part 1).
    Verifies controls C1-C4 first; counters N1-N4 read only if controls pass.
.NOTES
    Uses the fixture tools/fixtures/pgdump16_rtm_fixture.sql (real pg_dump 16.13 output).
    Exit 1 on any FAIL.
#>

$ErrorActionPreference = 'Stop'

# Resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$FixturePath = Join-Path $RepoRoot 'tools\fixtures\pgdump16_rtm_fixture.sql'
$SchemaDumpPath = Join-Path $ScriptDir 'RtmSchemaDump.ps1'

# Dot-source the module under test
. $SchemaDumpPath

# Load fixture
if (-not (Test-Path $FixturePath)) {
    Write-Host "FAIL: Fixture not found at $FixturePath"
    exit 1
}
$fixtureRaw = Get-Content -LiteralPath $FixturePath -Raw -Encoding UTF8

# Helper: count blocks matching a quoted whitelist table name (PRE-FIX LOGIC, verbatim)
function Get-PreFixBlocks {
    param([string]$Raw)
    $blocks = $Raw -split "(?m)\r?\n\r?\n"
    $keep = New-Object System.Collections.Generic.List[string]
    foreach ($b in $blocks) {
        foreach ($name in $script:RtmTableNames) {
            if ($name -match '^public\.(.+)$') {
                $quotedPart = $Matches[1]
            } else {
                $quotedPart = $name
            }
            if ($b.Contains($quotedPart)) {
                [void]$keep.Add($b.TrimEnd())
                break
            }
        }
    }
    return @($keep)
}

# Helper: identify routine header+body blocks (contains "CREATE FUNCTION" or "CREATE PROCEDURE" or "Type: FUNCTION/PROCEDURE")
function Test-IsRoutineBlock {
    param([string]$Block)
    if ($Block -match 'Type:\s*(FUNCTION|PROCEDURE)\s*;') { return $true }
    if ($Block -match '^\s*CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+') { return $true }
    # Also match routine body fragments (plpgsql, LANGUAGE, AS $$, END $$)
    if ($Block -match '\bLANGUAGE\s+(plpgsql|sql)\b') { return $true }
    if ($Block -match '\bAS\s*\$\$') { return $true }
    if ($Block -match '\bEND\s*\$\$') { return $true }
    return $false
}

# Count routine blocks in a list
function Count-RoutineBlocks {
    param([string[]]$Blocks)
    $count = 0
    foreach ($b in $Blocks) {
        if (Test-IsRoutineBlock $b) { $count++ }
    }
    return $count
}

$failCount = 0

Write-Host "`n=== PR234-CMP-01 part 1: Select-RtmSchemaBlocks test ==="
Write-Host "Fixture: $FixturePath`n"

# --- CONTROLS (must all pass before reading counters) ---

# C4: Fixture integrity (sha256)
$expectedSha = '1b34438bcfc9d395725e617063dbe417ef59eb73721168892c48771134f30d6f'
$actualSha = (Get-FileHash $FixturePath -Algorithm SHA256).Hash.ToLower()
if ($actualSha -eq $expectedSha) {
    Write-Host "PASS C4: fixture integrity sha256 = $actualSha"
} else {
    Write-Host "FAIL C4: fixture sha256 mismatch. Expected $expectedSha, got $actualSha"
    $failCount++
}

# C1: Fixture is live - pre-fix logic keeps routine header+body blocks >= 3
$preFix = Get-PreFixBlocks $fixtureRaw
$preFixRoutineCount = Count-RoutineBlocks $preFix
if ($preFixRoutineCount -ge 3) {
    Write-Host "PASS C1: pre-fix logic keeps $preFixRoutineCount routine header+body blocks (>= 3 required)"
} else {
    Write-Host "FAIL C1: pre-fix logic keeps only $preFixRoutineCount routine blocks (need >= 3 to show defect)"
    $failCount++
}

# C2: Trap 1 - 'Type:'-block exclusion still keeps routine blocks
# (filter out blocks that match 'Type: FUNCTION' or 'Type: PROCEDURE' header only)
$trap1 = $preFix | Where-Object { $_ -notmatch 'Type:\s*(FUNCTION|PROCEDURE)\s*;' }
$trap1RoutineCount = Count-RoutineBlocks $trap1
if ($trap1RoutineCount -ge 3) {
    Write-Host "PASS C2: trap 1 (Type:-block exclusion) still keeps $trap1RoutineCount routine blocks"
} else {
    Write-Host "FAIL C2: trap 1 changed the count unexpectedly to $trap1RoutineCount"
    $failCount++
}

# C3: Trap 2 - first-statement exclusion keeps at least 1 (the body tail after blank line)
$trap2 = $preFix | Where-Object { $_ -notmatch '^\s*CREATE\s+(OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+' }
$trap2RoutineCount = Count-RoutineBlocks $trap2
if ($trap2RoutineCount -ge 1) {
    Write-Host "PASS C3: trap 2 (first-statement exclusion) keeps $trap2RoutineCount routine blocks (body tail leak)"
} else {
    Write-Host "FAIL C3: trap 2 keeps 0 routine blocks - expected at least 1 (body tail)"
    $failCount++
}

# If any control failed, stop
if ($failCount -gt 0) {
    Write-Host "`nCONTROLS FAILED ($failCount). Counters N1-N4 NOT read."
    exit 1
}

Write-Host "`n--- Controls C1-C4 PASS. Reading counters N1-N4. ---`n"

# --- COUNTERS ---

# N1: Select-RtmSchemaBlocks(fixture): routine header+body blocks = 0
$fixed = Select-RtmSchemaBlocks -Raw $fixtureRaw
$fixedRoutineCount = Count-RoutineBlocks $fixed
if ($fixedRoutineCount -eq 0) {
    Write-Host "PASS N1: Select-RtmSchemaBlocks keeps 0 routine header+body blocks"
} else {
    Write-Host "FAIL N1: Select-RtmSchemaBlocks keeps $fixedRoutineCount routine blocks (expected 0)"
    $failCount++
}

# N2: non-routine blocks = 5, byte-identical to pre-fix non-routine blocks
$preFixNonRoutine = $preFix | Where-Object { -not (Test-IsRoutineBlock $_) }
$fixedNonRoutine = $fixed | Where-Object { -not (Test-IsRoutineBlock $_) }
$preFixNonRoutineCount = @($preFixNonRoutine).Count
$fixedNonRoutineCount = @($fixedNonRoutine).Count

if ($fixedNonRoutineCount -eq 5) {
    Write-Host "PASS N2a: Select-RtmSchemaBlocks keeps $fixedNonRoutineCount non-routine blocks"
} else {
    Write-Host "FAIL N2a: expected 5 non-routine blocks, got $fixedNonRoutineCount"
    $failCount++
}

# Check byte-identical
$preJoin = ($preFixNonRoutine | Sort-Object) -join "`n`n"
$fixJoin = ($fixedNonRoutine | Sort-Object) -join "`n`n"
if ($preJoin -eq $fixJoin) {
    Write-Host "PASS N2b: non-routine blocks byte-identical to pre-fix"
} else {
    Write-Host "FAIL N2b: non-routine blocks differ from pre-fix"
    $failCount++
}

# N3: the blank-line function specifically (NGC_GetSiteTable): 0 of its blocks kept
# NGC_GetSiteTable has a blank line in body, so pre-fix keeps 2 blocks for it
$getSiteBlocks = $fixed | Where-Object { $_ -match 'NGC_GetSiteTable' -or $_ -match 'v_count\s*:=' }
$getSiteCount = @($getSiteBlocks).Count
if ($getSiteCount -eq 0) {
    Write-Host "PASS N3: NGC_GetSiteTable (blank-line function) blocks kept = 0"
} else {
    Write-Host "FAIL N3: NGC_GetSiteTable blocks kept = $getSiteCount (expected 0)"
    $failCount++
}

# N4: Additional case - verify no PROCEDURE blocks kept (NGC_DeleteBusinessUnit)
$procBlocks = $fixed | Where-Object { $_ -match 'NGC_DeleteBusinessUnit' -or $_ -match 'CREATE\s+PROCEDURE' }
$procCount = @($procBlocks).Count
if ($procCount -eq 0) {
    Write-Host "PASS N4: PROCEDURE blocks (NGC_DeleteBusinessUnit) kept = 0"
} else {
    Write-Host "FAIL N4: PROCEDURE blocks kept = $procCount (expected 0)"
    $failCount++
}

# Summary
Write-Host ""
if ($failCount -eq 0) {
    Write-Host "=== ALL TESTS PASS ==="
    exit 0
} else {
    Write-Host "=== $failCount TEST(S) FAILED ==="
    exit 1
}
