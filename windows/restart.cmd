@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0restart.ps1" %*
exit /b %errorlevel%
