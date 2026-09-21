# Admin panel — Vite hot reload (updates browser automatically on save).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\admin-panel"

Write-Host "Starting admin panel (Vite HMR)..." -ForegroundColor Cyan
Write-Host "URL: http://localhost:8100" -ForegroundColor Green
Write-Host ""

npm run dev
