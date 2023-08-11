## Powershell

### Notes
- Windows-only due to use of [`winget`](https://learn.microsoft.com/en-us/windows/package-manager/winget/) to install packages.
- You may have to run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` in a non-admin PowerShell window before running the code below.

### How-To
Run the snippet below in an admin level PowerShell window. This will download and run [poershell.ps1](powershell.ps1) in the [`$HOME`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.3#home) folder. You may receive a warning about pasting multiple lines, choose to paste anyway.

```ps
Invoke-WebRequest -UseBasicParsing `
-Uri "https://raw.githubusercontent.com/genericallyterrible/python-setup-scripts/main/powershell.ps1" `
-OutFile "$HOME/py_setup_script.ps1"; &"$HOME/py_setup_script.ps1"

```
