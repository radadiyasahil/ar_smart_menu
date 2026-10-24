@echo off
title AR Smart Menu - Customer WebAR Experience
echo Starting Customer WebAR 3D Menu...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\dev-webar.ps1"
pause
