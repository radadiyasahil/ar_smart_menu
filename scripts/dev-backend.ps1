# ASP.NET Core API with auto-restart on code changes (dotnet watch).
# Stops when you close this window or press Ctrl+C.

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\backend\src\ARSmartMenu.API"

Write-Host "Starting API with dotnet watch (auto-reload on .cs changes)..." -ForegroundColor Cyan
Write-Host "URL: http://localhost:5232" -ForegroundColor Green
Write-Host "Swagger: http://localhost:5232/swagger" -ForegroundColor Green
Write-Host ""

dotnet watch run --launch-profile http
