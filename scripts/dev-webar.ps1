# WebAR customer viewer — Vite hot reload (port 5174).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\webar-experience"

Write-Host "Starting WebAR experience (Vite HMR)..." -ForegroundColor Cyan
Write-Host "URL: http://localhost:5174/dish/{slug}" -ForegroundColor Green
Write-Host "API : http://localhost:5232/api" -ForegroundColor Green
Write-Host ""

npm run dev
