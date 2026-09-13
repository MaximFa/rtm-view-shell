#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / evacuation-inventory  -  READ ONLY (step A of the evacuation)
#  WHERE IT RUNS : server 234.
#  WRITES        : nothing except its own manifest file under C:\RTMView-Ops\output\
#                  Nothing is deleted, moved, installed or uninstalled.
#  PURPOSE       : the machine is about to be wiped. This lists EVERY artefact that
#                  dies with it and records a SHA-256 for each, so that after the
#                  operator copies them off, step C can prove byte-for-byte arrival.
#                  Until step C matches every hash, the evacuation is NOT done.
#  WHY IT MATTERS: the 5432 dump is the only remaining place where the six removed
#                  metric rows and the 21/21 dangling baseline still exist, and the
#                  preinstall backup is the only proof of what the installer overwrote.
# ============================================================================

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$manifest = Join-Path $OutDir "234_$($stamp)_evacuation-manifest.txt"

$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

Say "WHERE IT RUNS : server 234. READ ONLY - nothing is deleted, moved or installed."
Say ("manifest      : {0}" -f $manifest)
Say ""

# ---- the evacuation list. Directories are walked; every file gets a hash. ----
$targets = @(
    @{ path='C:\RTMView-Ops\backup';                     why='DUMPS - the 5432 one is the ONLY place the six removed metric rows still exist' },
    @{ path='C:\RTMView-Ops\output';                     why='every measurement taken this week, in original form' },
    @{ path='C:\RTMView\Backup\preinstall_20260830_004812'; why='state BEFORE the installer ran - the only proof of what it overwrote' },
    @{ path='C:\RTMView\Shell\appsettings.json';         why='evidence: the four keys the installer lost' },
    @{ path='C:\RTMView\RTM\appsettings.json';           why='evidence: AdaptorServiceName + DB port not injected' },
    @{ path='C:\RTMView\RTM\data.sys';                   why='evidence: defect #1; on a clean machine this file will not exist at all' },
    @{ path='C:\RTMView\RTM.Twilio\appsettings.json';    why='adapter config as deployed' }
)

$rows = New-Object System.Collections.ArrayList
$grandBytes = 0
$missing = 0

foreach ($t in $targets) {
    Say ("===== {0}" -f $t.path)
    Say ("      why : {0}" -f $t.why)
    if (-not (Test-Path $t.path)) {
        Say "      *** ABSENT - not on this machine (printed as a fact, not skipped silently)"
        $missing++
        Say ""
        continue
    }
    $item = Get-Item $t.path
    $files = @()
    if ($item.PSIsContainer) { $files = @(Get-ChildItem $t.path -Recurse -File -ErrorAction SilentlyContinue) }
    else { $files = @($item) }
    Say ("      files: {0}" -f $files.Count)
    foreach ($f in $files) {
        $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
        $rel = $f.FullName
        [void]$rows.Add([pscustomobject]@{ Path=$rel; Bytes=$f.Length; SHA256=$h })
        $grandBytes += $f.Length
        Say ("      {0}  {1,12}  {2}" -f $h.Substring(0,16), $f.Length, $rel)
    }
    Say ""
}

Say "===== SUMMARY ====="
Say ("  files to evacuate : {0}" -f $rows.Count)
Say ("  total bytes       : {0}  ({1} MB)" -f $grandBytes, [math]::Round($grandBytes/1MB,2))
Say ("  targets ABSENT    : {0}   (non-zero means something expected is not here - read above)" -f $missing)
Say ("  free space on C:  : {0} GB" -f [math]::Round((Get-PSDrive C).Free/1GB,2))

Say ""
Say "===== NEGATIVE CONTROL ====="
$fake = 'C:\RTMView-Ops\backup\ZZZ_NO_SUCH_FILE.dump'
Say ("  Test-Path on a file that cannot exist : {0}   (must be False)" -f (Test-Path $fake))

Say ""
Say "===== MACHINE-READABLE MANIFEST (this is what step C will verify against) ====="
foreach ($r in $rows) { Say ("HASH|{0}|{1}|{2}" -f $r.SHA256, $r.Bytes, $r.Path) }

Say ""
Say "===== END-OF-RUN MARKER: EVACUATION-INVENTORY-COMPLETE ====="

[IO.File]::WriteAllLines($manifest, $L, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "COPY THIS BACK FIRST (it is the checklist for the copy itself):"
Write-Host "   $manifest"
