# Move screenshots from Chrome Downloads to RTM View Shell screenshots folder
# Run this from PowerShell after Claude captures the screenshots

$downloads = "$env:USERPROFILE\Downloads"
$dest = "C:\Users\farbe\Documents\Claude\Projects\RTM View Shell\docs\user-documentation\user\screenshots"

# Create destination if needed
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# Copy sc01-sc09 if they exist
1..9 | ForEach-Object {
    $n = "sc{0:D2}.jpg" -f $_
    $src = Join-Path $downloads $n
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $dest $n) -Force
        Write-Host "Copied $n"
    } else {
        Write-Host "Not found: $n"
    }
}

# Copy named screenshots from this session
foreach ($name in @("sc_editor.jpg", "sc_call_metrics_tab.jpg")) {
    $src = Join-Path $downloads $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $dest $name) -Force
        Write-Host "Copied $name"
    } else {
        Write-Host "Not found: $name"
    }
}

Write-Host ""
Write-Host "Done. Files in $dest :"
Get-ChildItem $dest -Filter "*.jpg" | Select-Object Name, Length
