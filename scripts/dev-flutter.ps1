# Flutter owner app (Chrome) — hot reload on save (press r in terminal to hot reload manually).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

Write-Host "Configuring Flutter for Web..." -ForegroundColor Cyan

# Ensure Windows desktop target is disabled to avoid symlink requirements
flutter config --no-enable-windows-desktop | Out-Null

# Free port 8080 if previously left open by another process
$existing = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Freeing port 8080..." -ForegroundColor Yellow
    $pids = $existing | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) {
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}

# Ensure dependencies are restored
if (-not (Test-Path "$PSScriptRoot\..\.dart_tool\package_config.json")) {
    Write-Host "Restoring Flutter dependencies..." -ForegroundColor Cyan
    flutter pub get
}

Write-Host "Starting Flutter Web on Chrome (http://localhost:8080)..." -ForegroundColor Green
Write-Host "Tip: press 'r' in this terminal for hot reload, 'R' for hot restart" -ForegroundColor Yellow
Write-Host ""

flutter run -d chrome --web-port=8080
