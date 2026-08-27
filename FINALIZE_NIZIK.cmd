@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FINALIZE_NIZIK.ps1"
echo.
pause
