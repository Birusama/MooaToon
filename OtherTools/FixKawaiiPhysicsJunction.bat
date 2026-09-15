@echo off
setlocal

rem Change this path if the KawaiiPhysics source repository is moved.
set "KAWAII_PHYSICS_SOURCE_PATH=C:\Users\jason\Workspace\KawaiiPhysics_MooaToon"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FixKawaiiPhysicsJunction.ps1" -KawaiiPhysicsSourcePath "%KAWAII_PHYSICS_SOURCE_PATH%"
set "exitCode=%errorlevel%"
echo.
echo Exit code: %exitCode%
pause
exit /b %exitCode%
