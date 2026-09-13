#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / preserve-applysvc   -   WRITES ONLY INTO C:\RTMView-Ops\preserve_...
#  WHERE IT RUNS : server 234.
#  WRITES        : C:\RTMView-Ops\preserve_20260906_1230\ApplyService\files\  (copy of 373 files)
#                  C:\RTMView-Ops\preserve_20260906_1230\ApplyService\env\    (2 ENV values)
#                  C:\RTMView-Ops\output\  (the report)
#  DOES NOT      : stop/start/delete any service; change or delete any ENV; modify anything
#                  under C:\RTMView\; touch C:\IceDash\; touch any database.
#  PURPOSE       : the token (length 38) and the CatalogueOwner connection string exist
#                  NOWHERE ELSE on this machine. Deleting the service takes its ENV with it.
#                  This is the single irreversible thing in the whole operation.
#  CLOSED GATE   : written -> READ BACK -> sha256 and length compared -> only then PASS.
#                  "Saved" without reading back is an intention, not a fact.
#  SECRETS       : values are written to disk on 234 and NEVER printed. The report carries
#                  the variable name, the length and the sha256 of the value - nothing else.
# ============================================================================

$ErrorActionPreference = "Continue"

$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$Dest     = Join-Path $Preserve "ApplyService"
$DestF    = Join-Path $Dest "files"
$DestE    = Join-Path $Dest "env"
$ApplyDir = "C:\RTMView\ApplyService"
$SvcName  = "RTMApplyService"
$server   = "234"
$topic    = "preserve-applysvc"

Write-Host "WHERE IT RUNS : server $server."
Write-Host "WRITES        : only under $Dest and $OutDir. Nothing under C:\RTMView\ is modified."
Write-Host "SECRETS       : ENV values go to disk on this machine only - name/length/sha256 in the report."

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

function Sha256OfString([string]$s) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $b   = [System.Text.Encoding]::UTF8.GetBytes($s)
    $h   = $sha.ComputeHash($b)
    $sha.Dispose()
    return (($h | ForEach-Object { $_.ToString("X2") }) -join "")
}

$fatal = $false

# ============================== 0. PRECONDITIONS ==============================
Say "===== 0  preconditions ====="
Say ("  source directory exists : {0}" -f (Test-Path $ApplyDir))
Say ("  preserve_ root exists   : {0}" -f (Test-Path $Preserve))
if (-not (Test-Path $ApplyDir)) { Say "  STOP: source directory missing."; $fatal = $true }
if (-not (Test-Path $Preserve)) { Say "  STOP: preserve_ root missing - wrong stamp?"; $fatal = $true }
$svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
Say ("  service {0} present : {1}   status : {2}" -f $SvcName, ($svc -ne $null), $(if ($svc) { $svc.Status } else { "n/a" }))
if ($svc -ne $null -and $svc.Status -ne "Stopped") {
    Say "  NOTE: the service is NOT Stopped. This probe still only reads it - nothing is stopped here."
}

if ($fatal) {
    Say ""
    Say "===== END-OF-RUN MARKER: PRESERVE-APPLYSVC-ABORTED ====="
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host "GATE: FAIL - preconditions. Nothing was written."
    Write-Host "COPY THESE BACK:"
    Write-Host "   $outf"
    Write-Host "   $errf"
    exit 1
}

New-Item -ItemType Directory -Force -Path $DestF | Out-Null
New-Item -ItemType Directory -Force -Path $DestE | Out-Null

# ============================== 1. THE ENV - the irreversible part, first ==============================
Say ""
Say "===== 1  ENV of the service - written, then READ BACK and compared ====="
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SvcName"
$envOk = $false
$envRows = @()
if (-not (Test-Path $regPath)) {
    Say "  STOP: service registry key not found."
    $fatal = $true
} else {
    $props  = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    $envRaw = @($props.Environment)
    Say ("  Environment entries found : {0}" -f $envRaw.Count)
    if ($envRaw.Count -eq 0) { Say "  STOP: no Environment entries - nothing to preserve, and that contradicts the recon."; $fatal = $true }

    foreach ($line in $envRaw) {
        $i = "$line".IndexOf('=')
        if ($i -lt 1) { Say "  STOP: unparsable Environment entry."; $fatal = $true; continue }
        $n = "$line".Substring(0,$i)
        $v = "$line".Substring($i+1)
        $f = Join-Path $DestE ($n + ".value.txt")

        # write: raw bytes, no BOM, no trailing newline - the value and nothing else
        [IO.File]::WriteAllBytes($f, [System.Text.Encoding]::UTF8.GetBytes($v))

        # READ BACK from disk - this is the gate, not the write
        $back    = [System.Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f))
        $shaMem  = Sha256OfString $v
        $shaDisk = Sha256OfString $back
        $match   = ($shaMem -eq $shaDisk -and $v.Length -eq $back.Length)
        $envRows += @{ n=$n; len=$v.Length; sha=$shaMem; ok=$match }
        Say ("  {0}" -f $n)
        Say ("      length in registry : {0}" -f $v.Length)
        Say ("      length read back   : {0}" -f $back.Length)
        Say ("      sha256 of value    : {0}" -f $shaMem)
        Say ("      sha256 read back   : {0}" -f $shaDisk)
        Say ("      MATCH              : {0}" -f $match)
        if (-not $match) { $fatal = $true }
    }

    # POSITIVE/NEGATIVE control of the comparison itself:
    # the comparator must be able to say "different" - otherwise MATCH above means nothing.
    $ctlA = Sha256OfString "control-string-A"
    $ctlB = Sha256OfString "control-string-B"
    Say ("  CONTROL comparator says equal on identical input   : {0}   (must be True)" -f ((Sha256OfString "control-string-A") -eq $ctlA))
    Say ("  CONTROL comparator says different on differing one : {0}   (must be True)" -f ($ctlA -ne $ctlB))
    if (((Sha256OfString "control-string-A") -ne $ctlA) -or ($ctlA -eq $ctlB)) { Say "  STOP: the comparator is not trustworthy."; $fatal = $true }

    $envOk = (@($envRows | Where-Object { -not $_.ok }).Count -eq 0 -and $envRows.Count -ge 2)
    Say ("  variables preserved and verified : {0} of {1}" -f @($envRows | Where-Object { $_.ok }).Count, $envRows.Count)
}

# lock the env folder down: no inheritance, SYSTEM + Administrators only
if (Test-Path $DestE) {
    $null = & icacls.exe $DestE /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" 2>&1
    Say ("  ACL on env folder reset to SYSTEM + Administrators only : exit {0}" -f $LASTEXITCODE)
}

# ============================== 2. THE DIRECTORY ==============================
Say ""
Say "===== 2  the ApplyService directory - copied, then compared file by file ====="
$src = @(Get-ChildItem $ApplyDir -Recurse -File -ErrorAction SilentlyContinue)
Say ("  source files : {0}" -f $src.Count)
Copy-Item -Path (Join-Path $ApplyDir "*") -Destination $DestF -Recurse -Force -ErrorAction SilentlyContinue
$dst = @(Get-ChildItem $DestF -Recurse -File -ErrorAction SilentlyContinue)
Say ("  copied files : {0}" -f $dst.Count)

$manifest = New-Object System.Collections.ArrayList
$bad = 0
foreach ($f in $src) {
    $rel = $f.FullName.Substring($ApplyDir.Length + 1)
    $to  = Join-Path $DestF $rel
    if (-not (Test-Path $to)) { $bad++; Say ("  MISSING IN COPY : {0}" -f $rel); continue }
    $h1 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    $h2 = (Get-FileHash $to -Algorithm SHA256).Hash
    if ($h1 -ne $h2) { $bad++; Say ("  HASH DIFFERS    : {0}" -f $rel) }
    [void]$manifest.Add(("{0}|{1}|{2}" -f $h1, $f.Length, $rel))
}
$manPath = Join-Path $Dest "manifest_applysvc.txt"
[IO.File]::WriteAllLines($manPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))
Say ("  manifest written : {0}   ({1} entries)" -f $manPath, $manifest.Count)
Say ("  files whose copy is missing or differs : {0}   (must be 0)" -f $bad)

$negPath = Join-Path $DestF "NoSuchFile_xyz.bin"
Say ("  NEGCTL a file that must NOT be in the copy : {0}   (must be False)" -f (Test-Path $negPath))
$dirOk = ($bad -eq 0 -and $dst.Count -eq $src.Count -and $src.Count -gt 0)
Say ("  directory preserved and verified : {0}" -f $dirOk)

# ============================== 3. THE SOURCE IS UNTOUCHED ==============================
Say ""
Say "===== 3  the source is exactly as it was ====="
$srcAfter = @(Get-ChildItem $ApplyDir -Recurse -File -ErrorAction SilentlyContinue)
Say ("  source files before : {0}" -f $src.Count)
Say ("  source files after  : {0}   (must be identical)" -f $srcAfter.Count)
$svc2 = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
Say ("  service status now  : {0}   (unchanged by this probe)" -f $(if ($svc2) { $svc2.Status } else { "n/a" }))
$propsAfter = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
Say ("  ENV entries still in registry : {0}   (must equal the number found above)" -f @($propsAfter.Environment).Count)

Say ""
Say "===== END-OF-RUN MARKER: PRESERVE-APPLYSVC-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))

$errSize = (Get-Item $errf).Length
$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$marker  = $content.Contains('PRESERVE-APPLYSVC-COMPLETE')
$pass    = ($envOk -and $dirOk -and $marker -and (-not $fatal))

Write-Host ""
Write-Host "ENV preserved and read back  : $envOk   (must be True)"
Write-Host "directory copied and hashed  : $dirOk   (must be True)"
Write-Host "END marker                   : $marker  (must be True)"
Write-Host ""
if ($pass) {
    Write-Host "GATE: PASS - the irreversible part is now held in preserve_. The service may be taken down later."
} else {
    Write-Host "GATE: FAIL - DO NOT take the service down. The token would be lost. Report this."
}
Write-Host ""
Write-Host "NOTHING WAS STOPPED, DELETED OR CHANGED under C:\RTMView\."
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
