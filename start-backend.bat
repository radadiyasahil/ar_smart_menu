@echo off
title AR Smart Menu - Backend API (.NET 9)
echo Starting Backend API Server on port 5232...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\dev-backend.ps1"
pause
