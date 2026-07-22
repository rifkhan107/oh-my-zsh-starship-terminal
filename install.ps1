#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PowerShell equivalent of install.sh: Starship prompt + PSReadLine
    (autosuggestions / syntax highlighting) with your custom config.

.DESCRIPTION
    There is no Oh My Zsh on native Windows PowerShell, so this script sets up
    the closest equivalents:
      - Starship prompt (same as install.sh)
      - PSReadLine predictive IntelliSense (autosuggestions) + colorized
        tokens (syntax highlighting) — PowerShell's built-in analogues of
        zsh-autosuggestions and zsh-syntax-highlighting

.USAGE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
    # or, from an already-elevated PowerShell session:
    .\install.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipWinget
)

$ErrorActionPreference = "Stop"

$StarshipConfigUrl = "https://gist.githubusercontent.com/rifkhan107/a49706cb2e69ac0e467a585278a23d99/raw/666e5238c043a6eba8406715b36bbf70ddd9f912/ubuntu-starship.toml"
$BundledStarshipConfig = Join-Path $PSScriptRoot "configs\starship.toml"
$StarshipConfigDir = Join-Path $HOME ".config"
$StarshipConfigFile = Join-Path $StarshipConfigDir "starship.toml"

function Write-Log  { param($msg) Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  [X] $msg" -ForegroundColor Red }

function Install-Starship {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        $version = (starship --version | Select-Object -First 1)
        Write-Ok "Starship already installed ($version)"
        return
    }

    if ($SkipWinget -or -not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err "winget not found. Install 'App Installer' from the Microsoft Store, or install Starship manually: https://starship.rs/install.sh"
        throw "winget unavailable"
    }

    Write-Log "Installing Starship via winget"
    winget install --id Starship.Starship -e --source winget --accept-package-agreements --accept-source-agreements
    Write-Ok "Starship installed"
}

function Update-PSReadLine {
    $module = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1

    if ($module -and $module.Version -ge [version]"2.2.0") {
        Write-Ok "PSReadLine already up to date ($($module.Version))"
        return
    }

    Write-Log "Installing/updating PSReadLine (adds predictive autosuggestions)"
    Install-Module -Name PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber -MinimumVersion 2.2.0
    Write-Ok "PSReadLine updated"
}

function Initialize-Profile {
    if (-not (Test-Path $PROFILE)) {
        Write-Log "Creating PowerShell profile at $PROFILE"
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
}

function Set-PSReadLineConfig {
    $marker = "# --- oh-my-zsh-starship-terminal: PSReadLine config ---"
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($content -and $content.Contains($marker)) {
        Write-Ok "PSReadLine config already present in profile"
        return
    }

    $block = @"

$marker
# Autosuggestions from history (equivalent of zsh-autosuggestions)
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
# Colorized tokens (equivalent of zsh-syntax-highlighting)
Set-PSReadLineOption -Colors @{
    Command   = 'Green'
    Parameter = 'Gray'
    String    = 'Yellow'
    Operator  = 'Cyan'
    Error     = 'Red'
}
"@

    Add-Content -Path $PROFILE -Value $block
    Write-Ok "Added PSReadLine config to profile"
}

function Set-StarshipInit {
    $marker = 'Invoke-Expression (&starship init powershell)'
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($content -and $content.Contains($marker)) {
        Write-Ok "Starship init already present in profile"
        return
    }

    Add-Content -Path $PROFILE -Value "`n# Starship prompt`n$marker"
    Write-Ok "Added Starship init to profile"
}

function Set-StarshipConfig {
    if (-not (Test-Path $StarshipConfigDir)) {
        New-Item -ItemType Directory -Path $StarshipConfigDir -Force | Out-Null
    }

    Write-Log "Fetching your Starship config from gist"
    $tmpFile = New-TemporaryFile

    try {
        Invoke-WebRequest -Uri $StarshipConfigUrl -OutFile $tmpFile -UseBasicParsing
        Write-Ok "Downloaded latest config from gist"
    }
    catch {
        if (Test-Path $BundledStarshipConfig) {
            Write-Warn "Could not reach gist (network error), using bundled fallback config"
            Copy-Item $BundledStarshipConfig $tmpFile -Force
        }
        else {
            Write-Warn "Could not download custom Starship config, and no bundled fallback found."
            Write-Warn "Leaving existing config (if any) untouched; Starship will use its defaults otherwise."
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
            return
        }
    }

    if ((Test-Path $StarshipConfigFile) -and
        ((Get-FileHash $tmpFile).Hash -ne (Get-FileHash $StarshipConfigFile).Hash)) {
        $backup = "$StarshipConfigFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $StarshipConfigFile $backup
        Write-Warn "Existing starship.toml backed up to $backup"
    }

    Move-Item $tmpFile $StarshipConfigFile -Force
    Write-Ok "Starship config written to $StarshipConfigFile"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

Write-Log "Starting Starship + PSReadLine setup for PowerShell"

Install-Starship
Update-PSReadLine
Initialize-Profile
Set-PSReadLineConfig
Set-StarshipInit
Set-StarshipConfig

Write-Host ""
Write-Ok "All done!"
Write-Host "Restart your terminal, or run: . `$PROFILE"
