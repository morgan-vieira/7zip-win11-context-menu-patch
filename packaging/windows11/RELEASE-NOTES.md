7-Zip native Windows 11 context menu integration, based on upstream 7-Zip 26.03.

Download the **preview ZIP** and extract it. It includes the complete package,
install/uninstall scripts, instructions, licenses, and build metadata. The GitHub
"Source code" archives require compilation. SHA256 files accompany the binaries.

The package registers a 7-Zip flyout for selected files and folders. Commands use
the included 7-Zip binaries. Menu fixes address nested submenus, repeated
enumeration, directory selections, and propagation of extraction settings.

**Testing prerelease:** unsigned; installation requires administrator PowerShell.
Build tests and MSIX validation pass. Installation and use inside Explorer still
need manual validation. See `INSTALL.txt` for installation and removal.

This is an independent community patch, not an official 7-Zip release.
