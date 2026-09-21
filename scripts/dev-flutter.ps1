# Flutter owner app (Chrome) — hot reload on save (press r in terminal to hot reload manually).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

Write-Host "Starting Flutter web on Chrome (hot reload enabled)..." -ForegroundColor Cyan
Write-Host "Tip: press 'r' in this terminal for hot reload, 'R' for hot restart" -ForegroundColor Yellow
Write-Host ""

flutter run -d chrome --web-port=8080
