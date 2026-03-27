@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "proxy-switcher.ps1"
pause
