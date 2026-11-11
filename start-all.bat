@echo off
title AR Smart Menu - Start All Dev Servers
echo Starting all 4 servers (Backend, Admin, Customer WebAR, Owner Flutter)...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\dev-all.ps1"
pause
