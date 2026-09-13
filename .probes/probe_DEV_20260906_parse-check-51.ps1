#Requires -Version 5.1
# ============================================================================
#  PROBE DEV / parse-check-51  -  READ ONLY
#  WHERE IT RUNS : the LOCAL machine, inside the repo clone. Server 234 NOT touched.
#  WRITES        : nothing in the repo. Two throwaway files under $env:TEMP, deleted at the end.
#  PURPOSE       : the acceptance gate for commits 20b9c65 + d01851a - do the two edited
#                  PowerShell scripts still PARSE under Windows PowerShell 5.1?
#  WHY 5.1 AND NOT pwsh7 : pwsh 7 decodes UTF-8 by default and therefore HIDES the exact
#                  defect class we are guarding against (a BOM-less or mis-encoded PS1 that
#                  5.1 reads through the ANSI codepage). Checking with pwsh7 would be a
#                  green light that proves nothing. This probe refuses to run under 7.
#  NEGATIVE CTRL : a deliberately broken fragment MUST fail to parse. If it parses, the
#                  checker cannot fail, and its verdict on the real files is worthless.
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host "WHERE IT RUNS : local machine, repo clone. READ ONLY (repo untouched)."
Write-Host ("PowerShell    : {0}  (must be 5.x - see header)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host ""
    Write-Host "STOP: this must run under Windows PowerShell 5.1, not pwsh $($PSVersionTable.PSVersion)."
    Write-Host "      Launch with:  powershell.exe -ExecutionPolicy Bypass -File <this file>"
    exit 1
}

$repo = "D:\Claude\Projects\RTM View Shell"
$files = @(
    (Join-Path $repo "deploy\Install-RTMView.ps1"),
    (Join-Path $repo "deploy\Update-RTMView.ps1")
)

Write-Host ""
Write-Host "===== P0 NEGATIVE CONTROL - the checker must be able to say NO ====="
$bad = Join-Path $env:TEMP ("parsecheck_bad_{0}.ps1" -f ([guid]::NewGuid().ToString("N")))
# deliberately unbalanced brace + unterminated string
[IO.File]::WriteAllText($bad, "function Broken {`r`n    Write-Host `"unterminated`r`n", (New-Object System.Text.UTF8Encoding($true)))
$e = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($bad, [ref]$null, [ref]$e)
if ($e -and $e.Count -gt 0) {
    Write-Host ("  broken fragment -> {0} parse error(s)   OK, the checker can fail" -f $e.Count)
    Write-Host ("     first: {0}" -f $e[0].Message)
} else {
    Write-Host "  *** broken fragment PARSED CLEANLY - the checker cannot fail."
    Write-Host "  *** Its verdict on the real files means nothing. STOP."
    Remove-Item $bad -ErrorAction SilentlyContinue
    exit 1
}
Remove-Item $bad -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "===== P1 BYTES - BOM present, line endings unchanged, no NUL ====="
foreach ($f in $files) {
    if (-not (Test-Path $f)) { Write-Host ("  MISSING: {0}" -f $f); continue }
    $b = [IO.File]::ReadAllBytes($f)
    $bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
    $crlf = 0; $lf = 0; $nul = 0
    for ($i = 0; $i -lt $b.Length; $i++) {
        if ($b[$i] -eq 0x0A) { if ($i -gt 0 -and $b[$i-1] -eq 0x0D) { $crlf++ } else { $lf++ } }
        if ($b[$i] -eq 0x00) { $nul++ }
    }
    Write-Host ("  {0,-26} bytes={1,-7} BOM={2,-5} CRLF={3,-4} bareLF={4,-4} NUL={5}" -f (Split-Path $f -Leaf), $b.Length, $bom, $crlf, $lf, $nul)
}
Write-Host "  expected: BOM=True, CRLF=0, NUL=0  (repo is eol=lf; CRLF here would mean the files were rewritten whole)"

Write-Host ""
Write-Host "===== P2 PARSE under 5.1 - the actual gate ====="
$fail = 0
foreach ($f in $files) {
    if (-not (Test-Path $f)) { $fail++; continue }
    $err = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$err)
    if ($err -and $err.Count -gt 0) {
        $fail++
        Write-Host ("  {0} : {1} PARSE ERROR(S)" -f (Split-Path $f -Leaf), $err.Count)
        foreach ($x in ($err | Select-Object -First 5)) {
            Write-Host ("      line {0}: {1}" -f $x.Extent.StartLineNumber, $x.Message)
        }
    } else {
        Write-Host ("  {0} : parse OK" -f (Split-Path $f -Leaf))
    }
}

Write-Host ""
Write-Host "===== P3 THE PHRASE - install and update must log identically ====="
foreach ($f in $files) {
    $n = @(Select-String -Path $f -SimpleMatch 'package version ignored' -AllMatches).Count
    Write-Host ("  {0,-26} occurrences = {1}   (must be 2 - one per branch)" -f (Split-Path $f -Leaf), $n)
}

Write-Host ""
if ($fail -eq 0) { Write-Host "GATE: PASS - both scripts parse under Windows PowerShell 5.1" }
else { Write-Host "GATE: FAIL - do NOT ship; read the parse errors above" }
