Stop-Process -Name "CcDashboard.Web" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "Building..." -ForegroundColor Cyan
dotnet build "src\CcDashboard.Web\CcDashboard.Web.csproj" -c Debug --nologo -v q
if ($LASTEXITCODE -ne 0) { Write-Host "Build FAILED" -ForegroundColor Red; exit 1 }

Write-Host "Starting..." -ForegroundColor Cyan
Start-Process -FilePath "dotnet" -ArgumentList "run --no-build --project src\CcDashboard.Web\CcDashboard.Web.csproj" -WindowStyle Hidden
Write-Host "Done." -ForegroundColor Green
