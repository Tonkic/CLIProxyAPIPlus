@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" %*
exit /b %errorlevel%
