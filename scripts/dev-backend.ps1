# ASP.NET Core API with auto-restart on code changes (dotnet watch).
# Stops when you close this window or press Ctrl+C.

$ErrorActionPreference = "Continue"
Set-Location "$PSScriptRoot\..\backend\src\ARSmartMenu.API"

try {
    # Pre-flight: kill any orphaned ARSmartMenu.API process holding port 5232
    $existing = Get-Process -Name "ARSmartMenu.API" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Freeing previous ARSmartMenu.API instance (PID: $($existing.Id -join ', '))..." -ForegroundColor Yellow
        $existing | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400
    }

    # Ensure port 5232 is completely released
    $portConns = Get-NetTCPConnection -LocalPort 5232 -ErrorAction SilentlyContinue
    if ($portConns) {
        $pids = $portConns | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($p in $pids) {
            if ($p -gt 4) {
                Write-Host "Releasing port 5232 (PID: $p)..." -ForegroundColor Yellow
                Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Milliseconds 500
    }

    # Try starting SQL LocalDB if installed
    try {
        sqllocaldb start mssqllocaldb 2>$null | Out-Null
    } catch {}

    Write-Host "Starting API with dotnet watch (auto-reload on .cs changes)..." -ForegroundColor Cyan
    Write-Host "URL: http://localhost:5232" -ForegroundColor Green
    Write-Host "Swagger: http://localhost:5232/swagger" -ForegroundColor Green
    Write-Host ""

    dotnet watch run --launch-profile http
}
catch {
    Write-Host ""
    Write-Host "Backend API encountered an error: $_" -ForegroundColor Red
}
finally {
    # Clean up on exit/Ctrl+C
    Get-Process -Name "ARSmartMenu.API" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host ""
    Write-Host "Backend API process stopped." -ForegroundColor Yellow
    Read-Host "Press Enter to exit this window"
}
