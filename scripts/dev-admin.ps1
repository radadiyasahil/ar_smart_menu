# Admin panel â€” Vite hot reload (updates browser automatically on save).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\..\admin-panel"

try {
    # Free port 8100 if busy
    $existing = Get-NetTCPConnection -LocalPort 8100 -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Freeing port 8100..." -ForegroundColor Yellow
        $pids = $existing | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($p in $pids) {
            Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500
    }

    # Ensure npm packages are installed
    if (-not (Test-Path "$PSScriptRoot\..\admin-panel\node_modules")) {
        Write-Host "Installing Admin Panel dependencies (npm install)..." -ForegroundColor Cyan
        npm install
    }

    Write-Host "Starting admin panel (Vite HMR)..." -ForegroundColor Cyan
    Write-Host "URL: http://localhost:8100" -ForegroundColor Green
    Write-Host ""

    npm run dev
}
catch {
    Write-Host ""
    Write-Host "Admin Panel encountered an error: $_" -ForegroundColor Red
}
finally {
    Write-Host ""
    Write-Host "Admin Panel process stopped." -ForegroundColor Yellow
    Read-Host "Press Enter to exit this window"
}
