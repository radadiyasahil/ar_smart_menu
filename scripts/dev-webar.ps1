# WebAR customer viewer — Vite hot reload (port 5174).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\webar-experience"

# Free port 5174 if busy
$existing = Get-NetTCPConnection -LocalPort 5174 -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Freeing port 5174..." -ForegroundColor Yellow
    $pids = $existing | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) {
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}

# Ensure npm packages are installed
if (-not (Test-Path "$PSScriptRoot\..\webar-experience\node_modules")) {
    Write-Host "Installing WebAR dependencies..." -ForegroundColor Cyan
    npm install
}

Write-Host "Starting WebAR Customer Experience (http://localhost:5174)..." -ForegroundColor Green
Write-Host "Ready for AR digital menus and 3D dish previews." -ForegroundColor Cyan
Write-Host ""

npm run dev
