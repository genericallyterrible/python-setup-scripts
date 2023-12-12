# A Windows-first powershell script for establishing a healthy
# baselevel platform for python development
function Invoke-YesNoPrompt {
    [OutputType([bool])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$message,
        [Alias('y')]
        [Parameter(Mandatory = $false, ParameterSetName = "setYes")]
        [switch]$defaultYes,
        [Alias('n')]
        [Parameter(Mandatory = $false, ParameterSetName = "setNo")]
        [switch]$defaultNo
    )

    $suffix = "y/n"
    if ($defaultYes) {
        $suffix = "Y/n"
    }
    elseif ($defaultNo) {
        $suffix = "y/N"
    }

    while ($true) {
        $response = Read-Host "$message [$suffix]"
        if ([string]::IsNullOrWhiteSpace($response)) {
            if ($defaultYes) {
                return $true
            }
            elseif ($defaultNo) {
                return $false
            }
            else {
                Write-Host "Please use 'Y' or 'N' to indicate yes or no."
            }
        }
        elseif ("$response".ToUpper().StartsWith("Y")) {
            return $true
        }
        elseif ("$response".ToUpper().StartsWith("N")) {
            return $false
        }
        else {
            Write-Host "I'm sorry, '$response' is not a valid response. Please use 'Y' or 'N' to indicate yes or no."
        }
    }
}

function Invoke-NounPrompt {
    [OutputType([string])]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$noun,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$default,
        [Alias('c')]
        [Parameter(Mandatory = $false)]
        [switch]$confirm
    )

    $prompt = "Please enter your $noun"
    $hasDefault = (-not [string]::IsNullOrWhiteSpace($default))
    if ($hasDefault) {
        $prompt = "$prompt [$default]" 
    }

    while ($true) {
        $response = Read-Host $prompt
        if (-not [string]::IsNullOrWhiteSpace($response)) {
            $response = $response.Trim()
            if ((-not $confirm) -or (Invoke-YesNoPrompt "Your $noun is '$response'?" -y)) {
                return $response
            }
        }
        elseif ($hasDefault) {
            return $default
        }
    }
}

function Test-CommandExists {
    [OutputType([bool])]
    param($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { $response = $true }
    }
    catch {
        $response = $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    return $response
}

function Test-RunningAsAdmin {
    [OutputType([bool])]
    param()

    return ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent() `
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

}

function Expand-EnvVars {
    [OutputType([string])]
    param ([string]$content)

    return [Environment]::ExpandEnvironmentVariables($content)
}

function Get-Path {
    [OutputType([string])]
    param ([string]$context)

    return [Environment]::GetEnvironmentVariable("Path", $context)
}

function Update-Path {
    Write-Host "Updating '`$env:Path' to match system environment."
    $env:Path = "$(Get-Path('Machine'));$(Get-Path('User'))"
}

function Find-InUserPath {
    [OutputType([bool])]
    param ([string]$newPathItem)

    $userPathContent = Get-Path("User")
    
    if ($null -eq $userPathContent) {
        return $false
    }

    $newPathItem = Expand-EnvVars($newPathItem)
    return ($userPathContent -split ";" -contains $newPathItem) 
}

function Add-ToUserPath {
    param ([string]$newPathItem)

    $newPathItem = Expand-EnvVars($newPathItem)

    if (!(Find-InUserPath $newPathItem)) {
        Write-Host "Adding $newPathItem to user 'Path' variable"
        $newPathContent = "$(Get-Path('User'));$newPathItem"
        [Environment]::SetEnvironmentVariable("Path", $newPathContent, "User")
    }
}

function Set-PipRequireVirtualEnv {
    param ([bool]$require)

    [Environment]::SetEnvironmentVariable("PIP_REQUIRE_VIRTUALENV", "$require", "User")
}

function Install-WinGetApp {
    param ([string]$PackageID)

    Write-Host "Installing $PackageID"
    winget install --id "$PackageID" --source winget --silent --accept-source-agreements --accept-package-agreements
}

function Install-VSCodeExtension {
    param ([string]$ExtensionID)

    Write-Host "Installing VS Code Extension $ExtensionID"
    code --install-extension $ExtensionID --force
}

function Get-GitCredentials {
    Write-Host "Configuring git."
    
    $userName = ""
    $userEmail = ""
    $initDefBranch = ""

    # Check if the user already has their git configured
    if (Test-CommandExists "git") {
        $userName = git config --global user.name
        $userEmail = git config --global user.email
        $initDefBranch = git config --global init.defaultBranch
    }

    # Git doesn't exist or isn't configured, collect name now, to configure when we're sure git exists
    if ([string]::IsNullOrWhiteSpace($userName)) {
        $userName = Invoke-NounPrompt "full name" -c
    }
    
    # Git doesn't exist or isn't configured, collect email now, to configure when we're sure git exists
    if ([string]::IsNullOrWhiteSpace($userEmail)) {
        $userEmail = Invoke-NounPrompt "email" -c
    }

    return @($userName, $userEmail, $initDefBranch)
}

function Set-GitCredentials {
    param ([Array]$gitCredentials)

    $userName, $userEmail, $initDefBranch = $gitCredentials

    if ([string]::IsNullOrWhiteSpace($initDefBranch) -or $initDefBranch.Trim().ToLower().Contains("master")) {
        git config --global init.defaultBranch "main"
    }
    git config --global user.name $userName
    git config --global user.email $userEmail
}

function Set-ValidExecutionPolicy {
    $executionPolicy = Get-ExecutionPolicy

    if (-not($executionPolicy -eq "RemoteSigned" -or $executionPolicy -eq "Unrestricted")) {
        Write-Host "Execution policy is set to '$executionPolicy'."
        Write-Host "Udating current user's script execution policy to enable venv activation."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    }

}

function Get-SelectedWingetApps {
    # ID list of winget applicatoins to install
    $packageIDs = @(
        "Microsoft.VisualStudioCode",
        "Git.Git"
    )

    $optionalPackages = @(
        "Microsoft.WindowsTerminal",
        "Microsoft.PowerShell",
        "gerardog.gsudo"
    )

    if (Invoke-YesNoPrompt "Would you like to install optional packages?" -y) {
        if (Invoke-YesNoPrompt "Install all optional packages?" -y) {
            $packageIDs += $optionalPackages
        }
        else {
            Write-Host "Please select the optional packages you wish to install."
            foreach ($packageID in $optionalPackages) {
                if (Invoke-YesNoPrompt "$packageID" -y) {
                    $packageIDs += $packageID
                }
            }
        }
    }
}

function Get-VSCodeExtensions {
    # ID list of all VS Code extensions to install
    $extensionIDs = @(
        "njpwerner.autodocstring",
        "charliermarsh.ruff",
        # "ms-python.black-formatter",
        "tamasfe.even-better-toml",
        "mhutchie.git-graph",
        # "ms-python.isort",
        "ms-toolsai.datawrangler",
        "ms-toolsai.jupyter",
        "ms-python.vscode-pylance",
        "ms-python.python"
    )
    # $optionalExtensions = @(
    #     "ms-toolsai.jupyter"
    #     "ryanluker.vscode-coverage-gutters"
    # )

    # if (Invoke-YesNoPrompt "Would you like to install optional VS Code Extensions?" -y) {
    #     if (Invoke-YesNoPrompt "Install all optional packages?" -y) {
    #         $extensionIDs += $optionalExtensions
    #     }
    #     else {
    #         Write-Host "Please select the optional packages you wish to install."
    #         foreach ($extensionID in $optionalExtensions) {
    #             if (Invoke-YesNoPrompt "$extensionID" -y) {
    #                 $extensionIDs += $extensionID
    #             }
    #         }
    #     }
    # }
    return $extensionIDs
}

function Invoke-Setup {
    if (-not (Test-RunningAsAdmin)) {
        Throw "Please run this script as an admin. Right click start, Powershell (Admin), and run '`$HOME/py_setup_script.ps1'."
    }

    $pythonVersion = "3.12.0"

    # ID list of winget applicatoins to install
    $packageIDs = Get-SelectedWingetApps

    # ID list of VS Code extensions to install
    $extensionsIDs = Get-VSCodeExtensions

    # May require user input to configure git, get all necessary input first, config later
    Write-Host "Configuring git."

    $gitCredentials = Get-GitCredentials

    Set-ValidExecutionPolicy

    foreach ($packageID in $packageIDs) {
        Install-WinGetApp -PackageID $packageID
    }

    Update-Path

    # Git has to exist now, we're safe to configure
    Set-GitCredentials $gitCredentials


    if (-not (Test-CommandExists "pyenv")) {
        Write-Host "Installing pyenv-win"
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile "./install-pyenv-win.ps1"; &"./install-pyenv-win.ps1"
    
        Update-Path
    }

    if (-not (Test-CommandExists "python")) {
        pyenv install $pythonVersion
        pyenv global $pythonVersion
        Update-Path
    }

    Set-PipRequireVirtualEnv $true

    if (-not (Test-CommandExists "pipx")) {
        Write-Host "Installing pipx"
        Set-PipRequireVirtualEnv $false
        pip install pipx
        Set-PipRequireVirtualEnv $true
        Update-Path
    }

    if (-not (Test-CommandExists "poetry")) {
        Write-Host "Installing Poetry"
        pipx install poetry
    
        Update-Path

        # Config poetry to put venvs in project roots instead of the default cache dir
        poetry config virtualenvs.in-project true
        poetry config virtualenvs.prefer-active-python true
    }


    foreach ($extensionID in $extensionsIDs) {
        Install-VSCodeExtension -ExtensionID $extensionID
    }

    Write-Host "Setup complete!"
    Pause; Exit
}

Invoke-Setup
