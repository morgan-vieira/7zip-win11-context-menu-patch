#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Get-AppxPackage -Name 'SevenZipContextMenuPatch' | Remove-AppxPackage
Write-Host 'Removed the native context menu package for the current user. Sign out and back in if Explorer still shows the menu.'
