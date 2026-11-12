# Flutter owner app (Chrome) â€” hot reload on save (press r in terminal to hot reload manually).

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

try {
    # If flutter is not in the active session's PATH but exists in C:\src\flutter\bin, add it
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue) -and (Test-Path "C:\src\flutter\bin")) {
        $env:Path = "C:\src\flutter\bin;$env:Path"
    }

    # Check if flutter is installed
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if (-not $flutterCmd) {
        Write-Host ""
        Write-Host "==================================================================" -ForegroundColor Red
        Write-Host " ERROR: Flutter SDK is not installed or not found in system PATH! " -ForegroundColor Red
        Write-Host "==================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "The Flutter Owner App requires the Flutter SDK to run." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To install Flutter on Windows:" -ForegroundColor Cyan
        Write-Host " 1. Open PowerShell and run:" -ForegroundColor White
        Write-Host "    git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter" -ForegroundColor Green
        Write-Host " 2. Add 'C:\src\flutter\bin' to your Environment PATH" -ForegroundColor White
        Write-Host " 3. Restart PowerShell and run: flutter doctor" -ForegroundColor White
        Write-Host ""
        Read-Host "Press Enter to exit this window"
        exit 1
    }

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
        Write-Host "Restoring Flutter dependencies (flutter pub get)..." -ForegroundColor Cyan
        flutter pub get
    }

    Write-Host "Starting Flutter Web on Chrome (http://localhost:8080)..." -ForegroundColor Green
    Write-Host "Tip: press 'r' in this terminal for hot reload, 'R' for hot restart" -ForegroundColor Yellow
    Write-Host ""

    flutter run -d chrome --web-port=8080
}
catch {
    Write-Host ""
    Write-Host "Flutter Owner App encountered an error: $_" -ForegroundColor Red
}
finally {
    Write-Host ""
    Write-Host "Flutter Owner App stopped." -ForegroundColor Yellow
    Read-Host "Press Enter to exit this window"
}
