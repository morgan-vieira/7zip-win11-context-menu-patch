[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')][string]$Architecture = 'x64',
    [ValidateRange(1, 65535)][int]$PatchVersion = 1
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
& (Join-Path $PSScriptRoot 'Build.ps1') -Architecture $Architecture -PatchVersion $PatchVersion
$out = Join-Path $repo "out/windows11/$Architecture"
[xml]$manifest = Get-Content -LiteralPath (Join-Path $out 'package/AppxManifest.xml')
$version = [version]$manifest.Package.Identity.Version
$releaseVersion = '{0}.{1:00}.{2}' -f $version.Major, $version.Minor, $version.Build
$name = "7zip-win11-context-menu-patch-$releaseVersion-$Architecture-preview"
# Each assembly uses a fresh directory, preventing stale release files.
$bundle = Join-Path $out ('bundle-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $bundle | Out-Null
Copy-Item -LiteralPath (Join-Path $out '7Zip.NativeContextMenu.msix') -Destination $bundle
foreach ($file in @('Install.ps1', 'Uninstall.ps1', 'INSTALL.txt', 'RELEASE-NOTES.md')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $bundle
}
foreach ($file in @('License.txt', 'copying.txt', 'unRarLicense.txt')) {
    Copy-Item -LiteralPath (Join-Path $repo "DOC/$file") -Destination $bundle
}
$commit = & git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine the source commit.' }
$changes = & git -C $repo status --porcelain --untracked-files=normal
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source status.' }
[ordered]@{
    project = '7zip-win11-context-menu-patch'
    version = $releaseVersion
    architecture = $Architecture
    commit = $commit
    workingTreeModified = [bool]$changes
    packageVersion = $version.ToString()
    packageSha256 = (Get-FileHash (Join-Path $bundle '7Zip.NativeContextMenu.msix') -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bundle 'BUILD.json') -Encoding UTF8
$releaseDir = Join-Path $repo 'out/releases'
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
$zip = Join-Path $releaseDir ($name + '.zip')
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip -Force
$hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $name.zip" | Set-Content -LiteralPath ($zip + '.sha256') -Encoding ASCII
Write-Host "Release archive: $zip"
Write-Host "SHA256: $hash"
