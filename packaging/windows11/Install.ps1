#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$PackagePath)
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Version.Build -lt 22000) { throw 'Windows 11 is required.' }
if (!$PackagePath) {
    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'arm64' } else { 'x64' }
    $PackagePath = Join-Path $PSScriptRoot '7Zip.NativeContextMenu.msix'
    if (!(Test-Path -LiteralPath $PackagePath)) {
        $PackagePath = Join-Path $PSScriptRoot "../../out/windows11/$architecture/7Zip.NativeContextMenu.msix"
    }
}
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
Add-AppxPackage -Path $PackagePath -AllowUnsigned
Write-Host 'Installed. Right-click a file or folder to use 7-Zip. If necessary, sign out and back in to refresh Explorer.'
