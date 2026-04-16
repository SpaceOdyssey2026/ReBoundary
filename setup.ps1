param (
    [Parameter(Mandatory=$true, HelpMessage="Enter the path to the Boundary game installation directory (e.g. D:\STEAM\steamapps\common\Boundary\ProjectBoundary\Binaries\Win64)")]
    [string]$BoundaryPath
)

Write-Host "Setting up Project ReBoundary..." -ForegroundColor Cyan

# 1. Look for vswhere.exe to locate MSBuild
$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    Write-Error "Could not find vswhere.exe. Is Visual Studio installed?"
    exit 1
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
if (-not $vsPath) {
    Write-Error "Could not locate Visual Studio installation with MSBuild."
    exit 1
}

$msbuild = "$vsPath\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuild)) {
    Write-Error "Could not find MSBuild at $msbuild"
    exit 1
}

Write-Host "Found MSBuild at: $msbuild" -ForegroundColor Green
Write-Host "Compiling ReBoundaryMain (Release/x64)..." -ForegroundColor Cyan

# 2. Switch to the ReBoundaryMain directory robustly based on where the script is run
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$mainDir = Join-Path $scriptDirectory "ReBoundaryMain"
Set-Location $mainDir

# 3. Build the solution
& $msbuild "ProjectRebound.sln" "/p:Configuration=Release" "/p:Platform=x64"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Compilation failed. Check the MSBuild output above."
    exit $LASTEXITCODE
}

Write-Host "Compilation successful!" -ForegroundColor Green

# 4. Copy the compiled DLLs and Config to the provided game directory
$dest = $BoundaryPath
if (-not (Test-Path $dest)) {
    Write-Host "Creating destination directory $dest" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
}

Write-Host "Copying files to $dest..." -ForegroundColor Cyan
Copy-Item -Path "x64\Release\dxgi.dll" -Destination $dest -Force
Copy-Item -Path "x64\Release\Payload.dll" -Destination $dest -Force
Copy-Item -Path "reboundary_config.json" -Destination $dest -Force

Write-Host "Setup Completed Successfully! You can now start the MetaServer and then launch the game." -ForegroundColor Green
