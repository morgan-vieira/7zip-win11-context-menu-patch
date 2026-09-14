# 7-Zip native Windows 11 context menu patch

Adds a **7-Zip** flyout to the native Windows 11 right-click menu for selected files
and folders. It uses the existing 7-Zip `IExplorerCommand` implementation and an
MSIX manifest that registers the shell extension with package identity.

This is an independent community patch, not an official 7-Zip release. The
repository contains upstream 7-Zip 26.03 source plus the integration patch.
The package includes its own `7zFM.exe`, `7zG.exe`, `7z.exe`, `7z.dll`, and
`7-zip.dll`; a separate 7-Zip installation is not required. Archive commands use
these packaged binaries. Available commands follow 7-Zip's context menu settings.
Folder-background menus are not registered.

## Downloads

Built packages are distributed through the repository's **Releases** page as
`7zip-win11-context-menu-patch-<version>-x64-preview.zip`. Download the preview ZIP
and extract it; GitHub's automatic "Source code" archives require compilation.
The ZIP contains the MSIX, install/uninstall scripts, `INSTALL.txt`, license terms,
and `BUILD.json` with source and package metadata. A separate `.sha256` asset
provides the download checksum.

From an administrator Windows PowerShell in the extracted folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Previews are unsigned testing builds; see the installation and validation limits
below. No separate 7-Zip installation or compiler is needed to use a download.

## Build and test

Requirements: Windows 11, Windows PowerShell 5.1, Visual Studio Build Tools with
**Desktop development with C++**, and a Windows 11 SDK (tested with 10.0.26100).
For ARM64, install the corresponding MSVC ARM64 tools as well.

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows11\Build.ps1
```

Output: `out/windows11/x64/7Zip.NativeContextMenu.msix`. Build logs, staged
binaries, and test fixtures are also under `out/windows11/x64`. Build outputs
are ignored by Git. The script compiles the upstream release targets, derives
package tiles from the upstream icon, runs tests, and validates/packs the MSIX
using the Windows SDK. It does not install anything or change Explorer settings.

Use `-Architecture arm64` to cross-compile for ARM64. Cross-compiled tests must be
run on a matching Windows PC; ARM64 has not been validated on hardware.

To repeat tests after a build:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows11\Test.ps1
```

Tests load the DLL directly without registration and cover COM activation,
files/folders/mixed selections, submenu depth, repeated menu enumeration, and
rejection of empty invocations. A ZIP create/test/extract round trip verifies the
packaged archive engine and filenames containing spaces.

## Install on a test PC

The generated package is **unsigned and intended for local testing**. Windows
requires an elevated PowerShell for unsigned packages containing executable code.
Run the following as administrator using the same Windows account that will use
the menu:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows11\Install.ps1
```

For a copied package, pass `-PackagePath 'C:\path\7Zip.NativeContextMenu.msix'`.
No certificate installation or Developer Mode is required by this workflow.
For broad distribution, replace the unsigned publisher identity and sign the
package with a trusted signing identity.

Right-click a ZIP archive, a normal file, a folder, and several files in Explorer.
Check that the native menu contains **7-Zip**, and exercise Open, Add to archive,
Extract here, Extract to folder, and Test archive where applicable. If Explorer
has cached its menu registrations, sign out and back in. The scripts do not
automatically restart Explorer.

Package installation, Explorer rendering, and GUI command execution require this
manual test; direct DLL tests do not validate packaged COM activation.

To uninstall for the current user:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows11\Uninstall.ps1
```

## Cut a release

Build, test, and assemble a download locally:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows11\Release.ps1 -PatchVersion 1
```

The ZIP and its SHA256 file are written to `out/releases/`. Version `26.03.1`
means upstream 26.03, patch revision 1; the MSIX version is `26.3.1.0`. Increment
`-PatchVersion` for subsequent releases so Windows can install them as updates.
Local builds record uncommitted source changes in `BUILD.json`.

To create a GitHub release, push the source and workflow, open **Actions → Build
release → Run workflow**, select the source ref and patch revision, and run it.
The workflow builds/tests x64 on Windows, uploads the download artifacts, and
creates a **draft testing prerelease** targeting the exact workflow commit.
Enable **Publish a testing prerelease** to publish immediately. Reusing an
existing release version fails rather than overwriting its assets.

Only x64 is included in the automated release until ARM64 has been validated.
Trusted package signing and manual Explorer validation remain prerequisites for
a stable release intended for broad distribution. The current release process
deliberately labels unsigned builds as previews.

## Implementation

- `packaging/windows11/AppxManifest.xml` registers the existing shell-extension
  CLSID as a COM surrogate and associates it with files and directories.
- `CPP/7zip/UI/Explorer/ContextMenu.cpp` flattens nested command groups, resets
  enumeration when rebuilding/reopening menus, carries extraction settings into
  child commands, handles directory attributes without `IShellExtInit`, and
  rejects empty invocations. The legacy `IContextMenu` menu layout is unchanged.
- Build and install are separate operations; install/uninstall use the dedicated
  `SevenZipContextMenuPatch` package identity.

References: [Microsoft's context menu integration guide](https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/integrate-packaged-app-with-file-explorer),
[submenu depth restriction](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-iexplorercommand-enumsubcommands),
and [unsigned MSIX installation](https://learn.microsoft.com/en-us/windows/msix/package/unsigned-package).

Upstream: [7-zip.org](https://7-zip.org). License terms are in
[DOC/License.txt](DOC/License.txt), [DOC/copying.txt](DOC/copying.txt), and
[DOC/unRarLicense.txt](DOC/unRarLicense.txt); copies are included in the package.
