# Start all dev servers in separate windows (each auto-reloads on its own).
# Run once â€” keep windows open while you work.

$root = Split-Path $PSScriptRoot -Parent

Write-Host "Opening 4 dev terminals (backend + admin + webar + flutter)..." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend API : http://localhost:5232  (dotnet watch - restarts on .cs changes)" -ForegroundColor Green
Write-Host "  Admin panel : http://localhost:8100  (Vite - instant browser refresh)" -ForegroundColor Green
Write-Host "  WebAR viewer: http://localhost:5174  (QR / dish links - 3D + AR)" -ForegroundColor Green
Write-Host "  Flutter app : http://localhost:8080  (hot reload - save .dart files)" -ForegroundColor Green
Write-Host ""
Write-Host "Close each window to stop that server." -ForegroundColor Yellow

function Start-DevServer([string]$scriptName) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    $argList = "-NoExit -ExecutionPolicy Bypass -File `"$scriptPath`""
    Start-Process powershell.exe -ArgumentList $argList
}

Start-DevServer "dev-backend.ps1"
Start-Sleep -Seconds 1
Start-DevServer "dev-admin.ps1"
Start-Sleep -Seconds 1
Start-DevServer "dev-webar.ps1"
Start-Sleep -Seconds 1
Start-DevServer "dev-flutter.ps1"

Write-Host "Done - check the new PowerShell windows." -ForegroundColor Green
