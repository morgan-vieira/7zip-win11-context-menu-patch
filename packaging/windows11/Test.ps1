[CmdletBinding()]
param([ValidateSet('x64', 'arm64')][string]$Architecture = 'x64')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo "out/windows11/$Architecture"
$stage = Join-Path $out 'package'
$testRoot = Join-Path $out ('test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$textFile = Join-Path $testRoot 'sample with spaces.txt'
$folder = Join-Path $testRoot 'folder with spaces'
New-Item -ItemType Directory -Path $folder | Out-Null
Set-Content -LiteralPath $textFile -Value '7-Zip native menu smoke test' -Encoding UTF8
$archive = Join-Path $testRoot 'sample archive.zip'
$sevenZip = Join-Path $stage '7z.exe'
& $sevenZip a -tzip $archive $textFile | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Archive creation failed.' }
& $sevenZip t $archive | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Archive verification failed.' }
& $sevenZip x $archive "-o$testRoot/extracted" -y | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Archive extraction failed.' }
if ((Get-FileHash $textFile).Hash -ne (Get-FileHash (Join-Path $testRoot 'extracted/sample with spaces.txt')).Hash) {
    throw 'Extracted content differs.'
}
& (Join-Path $out 'SmokeTest.exe') (Join-Path $stage '7-zip.dll') $textFile $archive $folder
if ($LASTEXITCODE -ne 0) { throw 'Shell extension smoke test failed.' }
Write-Host "PASS: archive round trip. Fixtures retained at $testRoot"
