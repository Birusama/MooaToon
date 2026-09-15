@echo off

setlocal
set "ScriptDir=%~dp0"

if not exist "%ScriptDir%_2_5_Settings.bat" goto :Fail
call "%ScriptDir%_2_5_Settings.bat"
if errorlevel 1 goto :Fail

@echo on

pushd "%ScriptDir%%engineFolderName%"
if errorlevel 1 goto :Fail

call GenerateProjectFiles.bat
if errorlevel 1 (
    echo GenerateProjectFiles failed. The editor will not be launched.
    popd
    pause
    exit /b 1
)

call _build.bat
if errorlevel 1 (
    echo Installed Build failed. The editor will not be launched.
    popd
    pause
    exit /b 1
)

set "EditorPath=%CD%\LocalBuilds\Engine\Windows\Engine\Binaries\Win64\UnrealEditor.exe"
set "ProjectPath=%ScriptDir%%projectFolderName%\MooaToon_Project.uproject"
set "LogPath=%ScriptDir%%projectFolderName%\Saved\Logs\MooaToon_InstalledBuild.log"

if not exist "%EditorPath%" (
    echo Installed Editor was not produced: "%EditorPath%"
    popd
    pause
    exit /b 1
)
if not exist "%ProjectPath%" (
    echo Project was not found: "%ProjectPath%"
    popd
    pause
    exit /b 1
)

"%EditorPath%" "%ProjectPath%" -log -clearPSODriverCache -abslog="%LogPath%"
set "RunExitCode=%ERRORLEVEL%"
popd

pause
exit /b %RunExitCode%

:Fail
echo Startup script prerequisites failed. The editor will not be launched.
pause
exit /b 1
