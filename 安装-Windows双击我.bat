@echo off
rem ============================================================
rem  Schedule Assistant - Windows one-click installer
rem  This .bat only calls PowerShell (no Python required)
rem ============================================================
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_helper.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Install failed. Please check the message above.
    pause
)
