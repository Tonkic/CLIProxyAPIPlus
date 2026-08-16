@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\start.ps1" -Root "%~dp0." %*
exit /b %errorlevel%
