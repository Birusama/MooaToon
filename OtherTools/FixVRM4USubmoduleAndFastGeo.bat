@echo off
setlocal

rem Run this file after closing Unreal Editor.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FixVRM4USubmoduleAndFastGeo.ps1" %*
set "exitCode=%errorlevel%"
echo.
echo Exit code: %exitCode%
pause
exit /b %exitCode%
