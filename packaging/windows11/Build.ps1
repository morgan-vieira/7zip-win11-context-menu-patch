[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')][string]$Architecture = 'x64',
    [ValidateRange(1, 65535)][int]$PatchVersion = 1
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo "out/windows11/$Architecture"
$stage = Join-Path $out 'package'
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (!(Test-Path $vswhere)) { throw 'Install Visual Studio Build Tools with Desktop development with C++ and the Windows 11 SDK.' }
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'No Visual Studio installation with C++ tools was found.' }
# Import the compiler environment without constructing a shell command from paths.
$devShell = Join-Path $vs 'Common7/Tools/Launch-VsDevShell.ps1'
& $devShell -Arch $Architecture -HostArch amd64 -SkipAutomaticLocation | Out-Null
if (!(Get-Command makeappx.exe -ErrorAction SilentlyContinue)) { throw 'Windows SDK makeappx.exe is required.' }

$targets = [ordered]@{
    'CPP/7zip/UI/Explorer' = '7-zip.dll'
    'CPP/7zip/UI/FileManager' = '7zFM.exe'
    'CPP/7zip/UI/GUI' = '7zG.exe'
    'CPP/7zip/Bundles/Format7zF' = '7z.dll'
    'CPP/7zip/UI/Console' = '7z.exe'
}
foreach ($entry in $targets.GetEnumerator()) {
    Push-Location (Join-Path $repo $entry.Key)
    try {
        $log = Join-Path $out ($entry.Value + '.build.log')
        Write-Host "Building $($entry.Value)... ($log)"
        # Windows PowerShell treats native stderr as errors, including compiler banners.
        $ErrorActionPreference = 'Continue'
        & nmake.exe /nologo "PLATFORM=$Architecture" > $log 2>&1
        $buildExitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($buildExitCode -ne 0) { Get-Content $log -Tail 40; throw "Build failed: $($entry.Value)" }
        Copy-Item -LiteralPath (Join-Path $Architecture $entry.Value) -Destination $stage -Force
    } finally { Pop-Location }
}

[xml]$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'AppxManifest.xml')
$manifest.Package.Identity.ProcessorArchitecture = $Architecture
$versionHeader = Get-Content (Join-Path $repo 'C/7zVersion.h') -Raw
$major = [regex]::Match($versionHeader, '#define MY_VER_MAJOR (\d+)').Groups[1].Value
$minor = [regex]::Match($versionHeader, '#define MY_VER_MINOR (\d+)').Groups[1].Value
$manifest.Package.Identity.Version = "$major.$minor.$PatchVersion.0"
$manifest.Save((Join-Path $stage 'AppxManifest.xml'))
Copy-Item -LiteralPath (Join-Path $repo 'DOC/License.txt'), (Join-Path $repo 'DOC/copying.txt'), (Join-Path $repo 'DOC/unRarLicense.txt') -Destination $stage -Force

# Derive package tiles from the existing upstream icon.
Add-Type -AssemblyName System.Drawing
$assets = Join-Path $stage 'Assets'
New-Item -ItemType Directory -Force -Path $assets | Out-Null
$icon = New-Object System.Drawing.Icon((Join-Path $repo 'CPP/7zip/UI/FileManager/7zipLogo.ico'), 256, 256)
$source = $icon.ToBitmap()
try {
    foreach ($tile in @(@('StoreLogo', 50), @('Square44x44Logo', 44), @('Square150x150Logo', 150))) {
        $bitmap = New-Object System.Drawing.Bitmap($tile[1], $tile[1])
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.DrawImage($source, 0, 0, $tile[1], $tile[1])
            $bitmap.Save((Join-Path $assets ($tile[0] + '.png')), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $graphics.Dispose(); $bitmap.Dispose() }
    }
} finally { $source.Dispose(); $icon.Dispose() }

Push-Location $out
try {
    & cl.exe /nologo /EHsc /W4 /WX /std:c++17 (Join-Path $PSScriptRoot 'SmokeTest.cpp') /Fe:SmokeTest.exe /link ole32.lib shell32.lib uuid.lib
    if ($LASTEXITCODE -ne 0) { throw 'Smoke test compilation failed.' }
} finally { Pop-Location }
$nativeArchitecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'x64' }
if ($Architecture -eq $nativeArchitecture) {
    & (Join-Path $PSScriptRoot 'Test.ps1') -Architecture $Architecture
} else {
    Write-Host "Cross-compiled tests: run Test.ps1 -Architecture $Architecture on a matching Windows PC."
}

$package = Join-Path $out '7Zip.NativeContextMenu.msix'
& makeappx.exe pack /o /d $stage /p $package
if ($LASTEXITCODE -ne 0) { throw 'MSIX packaging or manifest validation failed.' }
Write-Host "Built $package"
