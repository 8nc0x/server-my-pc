@echo off
:: ==============================================================================
:: server-my-pc Windows 1-Click Server Converter Launcher
:: Automatically requests Administrator elevation and runs setup.ps1
:: ==============================================================================

setlocal EnableDelayedExpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [server-my-pc] Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~dpnx0\"\"' -Verb RunAs"
    exit /b
)

:: Run PowerShell setup script with ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*

if %errorlevel% neq 0 (
    echo.
    echo [!] Setup encountered an error or was cancelled.
    pause
)
