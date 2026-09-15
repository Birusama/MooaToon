@echo off

setlocal EnableExtensions
set "ScriptDir=%~dp0"
set "EngineDir=%ScriptDir%MooaToon-Engine"
set "ProjectDir=%ScriptDir%MooaToon-Project"
set "OutputDir=%EngineDir%\LocalBuilds\InstalledBuildTest"
set "InstalledBuildScript=%EngineDir%\Engine\Build\InstalledEngineBuild.xml"
set "EditorPath=%OutputDir%\Windows\Engine\Binaries\Win64\UnrealEditor.exe"
set "ProjectPath=%ProjectDir%\MooaToon_Project.uproject"
set "LogPath=%ProjectDir%\Saved\Logs\MooaToon_InstalledBuildTest.log"
set "UbaSourceDir=%EngineDir%\Engine\Binaries\Win64\UnrealBuildAccelerator\x64"
set "UbaRuntimeDir=%EngineDir%\Engine\Binaries\DotNET\UnrealBuildTool\runtimes\win-x64\native"

if not exist "%EngineDir%\Engine\Build\BatchFiles\RunUAT.bat" (
    echo RunUAT.bat was not found: "%EngineDir%\Engine\Build\BatchFiles\RunUAT.bat"
    call :PauseOnError 1
    exit /b 1
)
if not exist "%InstalledBuildScript%" (
    echo InstalledEngineBuild.xml was not found: "%InstalledBuildScript%"
    call :PauseOnError 1
    exit /b 1
)
if not exist "%ProjectPath%" (
    echo Project was not found: "%ProjectPath%"
    call :PauseOnError 1
    exit /b 1
)

set "MooaToonPluginOption="
set "MooaToonPluginState=not present in BuildGraph script"
findstr /i /c:"CompileMooaToonPlugins" "%InstalledBuildScript%" >nul
if not errorlevel 1 (
    set "MooaToonPluginOption=-set:CompileMooaToonPlugins=false"
    set "MooaToonPluginState=skipped because VRM4U.uplugin is missing"
    if exist "%EngineDir%\Engine\Plugins\MooaToonThirdparty\VRM4U\VRM4U.uplugin" (
        set "MooaToonPluginOption=-set:CompileMooaToonPlugins=true"
        set "MooaToonPluginState=enabled because VRM4U.uplugin is present"
    )
)
echo MooaToon built-in plugin compile: %MooaToonPluginState%

echo Building Win64 Installed Build into:
echo   "%OutputDir%\Windows"
pushd "%EngineDir%"
if errorlevel 1 (
    echo Failed to enter engine directory: "%EngineDir%"
    call :PauseOnError 1
    exit /b 1
)

echo Generating UnrealBuildTool project files...
call "%EngineDir%\GenerateProjectFiles.bat"
set "GenerateExitCode=%ERRORLEVEL%"
if not "%GenerateExitCode%"=="0" (
    echo GenerateProjectFiles failed with exit code %GenerateExitCode%.
    popd
    call :PauseOnError %GenerateExitCode%
    exit /b %GenerateExitCode%
)

if not exist "%UbaSourceDir%\UbaHost.dll" (
    echo UBA host binary was not found: "%UbaSourceDir%\UbaHost.dll"
    popd
    call :PauseOnError 1
    exit /b 1
)
if not exist "%UbaRuntimeDir%" mkdir "%UbaRuntimeDir%"
copy /y "%UbaSourceDir%\UbaHost.dll" "%UbaRuntimeDir%\UbaHost.dll" >nul
copy /y "%UbaSourceDir%\UbaDetours.dll" "%UbaRuntimeDir%\UbaDetours.dll" >nul
if errorlevel 1 (
    echo Failed to prepare UBA runtime files for UnrealBuildTool.
    popd
    call :PauseOnError 1
    exit /b 1
)

call "%EngineDir%\Engine\Build\BatchFiles\RunUAT.bat" BuildGraph ^
    -Script=Engine/Build/InstalledEngineBuild.xml ^
    -Target="Make Installed Build Win64" ^
    -set:BuiltDirectory="%OutputDir%" ^
    -set:HostPlatformOnly=true ^
    -set:WithWin64=true ^
    -set:WithWinArm64=false ^
    -set:WithWinArm64ec=false ^
    -set:WithMac=false ^
    -set:WithLinux=false ^
    -set:WithLinuxArm64=false ^
    -set:WithAndroid=false ^
    -set:WithIOS=false ^
    -set:WithTVOS=false ^
    -set:WithDDC=false ^
    %MooaToonPluginOption% ^
    -set:CompileDatasmithPlugins=false ^
    -set:SignExecutables=false ^
    -set:ExtraCompileArgs=-NoUBA ^
    -set:IncludeDocs=false
set "BuildExitCode=%ERRORLEVEL%"
popd

if not "%BuildExitCode%"=="0" (
    echo Installed Build failed with exit code %BuildExitCode%. The editor will not be launched.
    call :PauseOnError %BuildExitCode%
    exit /b %BuildExitCode%
)
if not exist "%EditorPath%" (
    echo Installed Editor was not produced: "%EditorPath%"
    call :PauseOnError 1
    exit /b 1
)
if not exist "%OutputDir%\Windows\Engine\Build\InstalledBuild.txt" (
    echo Installed Build marker was not produced: "%OutputDir%\Windows\Engine\Build\InstalledBuild.txt"
    call :PauseOnError 1
    exit /b 1
)

if not exist "%ProjectDir%\Saved\Logs" mkdir "%ProjectDir%\Saved\Logs"
echo Starting Installed Build editor:
echo   "%EditorPath%" "%ProjectPath%"
echo Log:
echo   "%LogPath%"
pushd "%ProjectDir%"
if errorlevel 1 (
    echo Failed to enter project directory: "%ProjectDir%"
    call :PauseOnError 1
    exit /b 1
)

"%EditorPath%" "%ProjectPath%" -log -clearPSODriverCache -abslog="%LogPath%"
set "RunExitCode=%ERRORLEVEL%"
popd

echo Installed Build editor exited with code %RunExitCode%.
if not "%RunExitCode%"=="0" (
    call :PauseOnError %RunExitCode%
    exit /b %RunExitCode%
)
exit /b %RunExitCode%

:PauseOnError
set "PauseExitCode=%~1"
echo.
echo The script failed with exit code %PauseExitCode%.
pause
exit /b %PauseExitCode%
