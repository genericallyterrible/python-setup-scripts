## Powershell

### Notes
- Developed and tested on Windows machines, though should also work on the cross-platform PowerShell 7+.
- You may have to run `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned` in a non-admin PowerShell window before running the code below.

### How-To
Run the snipped below in an admin level PowerShell window. This will download and run [poershell.ps1](powershell.ps1) in the [`$HOME`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.3#home) folder

```ps
Invoke-WebRequest -UseBasicParsing `
-Uri "https://raw.githubusercontent.com/genericallyterrible/python-setup-scripts/main/powershell.ps1" `
-OutFile "$HOME/py_setup_script.ps1"; &"$HOME/py_setup_script.ps1"
```
