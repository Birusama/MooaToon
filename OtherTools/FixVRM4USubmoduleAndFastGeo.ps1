[CmdletBinding()]
param(
    [switch]$SkipFastGeo
)

$ErrorActionPreference = 'Stop'

# Edit these local paths if the workspace is moved.
$WorkspaceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$EngineRoot = Join-Path $WorkspaceRoot 'MooaToon-Engine'
$ProjectRoot = Join-Path $WorkspaceRoot 'MooaToon-Project'
$ProjectFile = Join-Path $ProjectRoot 'MooaToon_Project.uproject'

$Vrm4UUrl = 'https://github.com/JasonMa0012/VRM4U_MooaToon.git'
$Vrm4URelativePath = 'Engine/Plugins/MooaToonThirdparty/VRM4U'
$Vrm4UPath = Join-Path $EngineRoot ($Vrm4URelativePath -replace '/', '\')

# Keep the commandlet scoped to the migrated map that has project HLOD data.
$FastGeoMapPackages = @(
    '/Game/MooaToonSamples/Maps/VolumetricPainting/L_VolumetricPainting'
)

function Assert-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory was not found: $Path"
    }
}

function Assert-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File was not found: $Path"
    }
}

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & git -C $script:EngineRoot @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Get-Vrm4UGitLink {
    $records = @(& git -C $script:EngineRoot ls-files -s -- $script:Vrm4URelativePath)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect the VRM4U submodule entry.'
    }

    return @($records | Where-Object { $_ -match '^160000\s' })
}

function Repair-Vrm4USubmodule {
    Write-Host "[VRM4U] Checking $Vrm4URelativePath"

    $gitLink = @(Get-Vrm4UGitLink)
    if ($gitLink.Count -eq 0) {
        if (Test-Path -LiteralPath $Vrm4UPath) {
            $existingItems = @(Get-ChildItem -LiteralPath $Vrm4UPath -Force)
            if ($existingItems.Count -gt 0) {
                throw "VRM4U path exists but is not a registered submodule; refusing to delete it: $Vrm4UPath"
            }
        }

        Write-Host "[VRM4U] Adding submodule from $Vrm4UUrl"
        Invoke-Git @('submodule', 'add', '--force', $Vrm4UUrl, $Vrm4URelativePath)
    }

    & git -C $EngineRoot config --file .gitmodules "submodule.$Vrm4URelativePath.url" $Vrm4UUrl
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to write the VRM4U URL to .gitmodules.'
    }

    Invoke-Git @('submodule', 'sync', '--', $Vrm4URelativePath)
    Invoke-Git @('submodule', 'update', '--init', '--recursive', '--', $Vrm4URelativePath)

    Assert-Directory $Vrm4UPath
    $pluginFile = Join-Path $Vrm4UPath 'VRM4U.uplugin'
    Assert-File $pluginFile

    $remoteUrl = ([string](& git -C $Vrm4UPath remote get-url origin 2>$null)).Trim()
    if ($LASTEXITCODE -ne 0 -or $remoteUrl -ne $Vrm4UUrl) {
        Write-Host "[VRM4U] Setting origin to $Vrm4UUrl"
        & git -C $Vrm4UPath remote set-url origin $Vrm4UUrl
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to set the VRM4U origin URL.'
        }
    }

    Write-Host '[VRM4U] Submodule status:'
    Invoke-Git @('submodule', 'status', '--recursive', '--', $Vrm4URelativePath)
    Write-Host '[VRM4U] Repaired without resetting the submodule worktree.'
}

function Get-UnrealEditorCommandlet {
    $candidates = @(
        (Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor-Win64-Debug-Cmd.exe'),
        (Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'),
        (Join-Path $EngineRoot 'Engine\Binaries\Win64\UnrealEditor.exe')
    )

    $editor = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($null -eq $editor) {
        throw 'No UnrealEditor commandlet executable was found in the source engine.'
    }

    return [string]$editor
}

function Assert-EditorClosed {
    $processes = @(
        Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like 'UnrealEditor*' -and
                $_.CommandLine -and
                $_.CommandLine -like "*$ProjectFile*"
            }
    )

    if ($processes.Count -gt 0) {
        $pids = ($processes | ForEach-Object { $_.ProcessId }) -join ', '
        throw "Close the MooaToon Editor before rebuilding FastGeo data. Running PIDs: $pids"
    }
}

function Repair-FastGeoData {
    Assert-File $ProjectFile
    Assert-EditorClosed

    $editor = Get-UnrealEditorCommandlet
    $logDirectory = Join-Path $ProjectRoot 'Saved\Logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory ("FixFastGeo-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    $arguments = @(
        $ProjectFile,
        '-run=ResavePackages',
        '-BuildHLOD',
        '-ProjectOnly',
        '-AllowCommandletRendering',
        '-SkipSkinVerify',
        '-SCCProvider=None',
        '-FastGeo.Enable=true',
        '-FastGeo.EnableTransformer=true',
        '-unattended',
        '-nop4',
        '-nosplash',
        '-NoSound',
        '-log'
    )

    foreach ($mapPackage in $FastGeoMapPackages) {
        if ([string]::IsNullOrWhiteSpace($mapPackage)) {
            throw 'FastGeo map package names must not be empty.'
        }
    }
    $arguments += "-Map=$($FastGeoMapPackages -join '+')"

    Write-Host "[FastGeo] Rebuilding HLOD/FastGeo data with: $editor"
    Write-Host "[FastGeo] Log: $logPath"
    & $editor @arguments 2>&1 | Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $logText = Get-Content -Raw -LiteralPath $logPath
        $unexpectedErrors = @(
            $logText -split "`r?`n" |
                Where-Object {
                    $_ -match 'Error:' -and
                    $_ -notmatch 'LogGrass: Error: ERROR: BuildGrassMapsNowForComponents\(\) took too long'
                }
        )
        $hasHlodReport = $logText -match '\[REPORT\].*packages were resaved'

        if (-not $hasHlodReport -or $unexpectedErrors.Count -gt 0) {
            throw "FastGeo/HLOD rebuild failed with exit code $exitCode. See $logPath"
        }

        Write-Warning "HLOD/FastGeo data was generated, but Unreal reported the unrelated Grass map timeout; see $logPath"
    }

    Write-Host '[FastGeo] HLOD/FastGeo rebuild completed.'
    Write-Host '[FastGeo] Project changes after rebuild:'
    & git -C $ProjectRoot status --short --untracked-files=all
}

try {
    Assert-Directory $EngineRoot
    Assert-Directory $ProjectRoot

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git.exe was not found in PATH.'
    }

    Repair-Vrm4USubmodule

    if (-not $SkipFastGeo) {
        Repair-FastGeoData
    } else {
        Write-Host '[FastGeo] Skipped by -SkipFastGeo.'
    }

    Write-Host 'Repair completed successfully.'
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
