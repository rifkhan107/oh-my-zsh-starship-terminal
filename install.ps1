#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PowerShell equivalent of install.sh: Starship prompt + PSReadLine
    (autosuggestions / syntax highlighting) + Terminal-Icons, with your
    custom config.

.DESCRIPTION
    There is no Oh My Zsh on native Windows PowerShell, so this script sets up
    the closest equivalents:
      - Starship prompt (same as install.sh). Tries winget in per-user scope
        first; if that's unavailable or needs admin rights you don't have, it
        falls back to downloading the official binary straight from GitHub
        releases into %LOCALAPPDATA%\Programs\starship and adds that to your
        *user* PATH — no admin/UAC required either way.
      - PSReadLine predictive IntelliSense (autosuggestions) + colorized
        tokens (syntax highlighting) — PowerShell's built-in analogues of
        zsh-autosuggestions and zsh-syntax-highlighting
      - Terminal-Icons for file/folder icons, with the "windows" well-known
        folder overridden to use the nf-custom-windows Nerd Font glyph
        instead of the default nf-fa-windows

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

$TerminalIconsCustomThemeName = "devblackops-nf-custom-windows"
$TerminalIconsCustomThemeDir = Join-Path $HOME ".config\terminal-icons"
$TerminalIconsCustomThemeFile = Join-Path $TerminalIconsCustomThemeDir "$TerminalIconsCustomThemeName.psd1"

function Write-Log  { param($msg) Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  [X] $msg" -ForegroundColor Red }

function Sync-Path {
    # Pull the latest Machine + User PATH into this process, so a binary
    # installed by winget/manually in this run is visible without reopening
    # the terminal.
    $paths = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) | Where-Object { $_ }
    $env:Path = ($paths -join ';')
}

function Install-Starship {
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        $version = (starship --version | Select-Object -First 1)
        Write-Ok "Starship already installed ($version)"
        return
    }

    if (-not $SkipWinget -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "Installing Starship via winget (per-user scope, no admin required)"
        winget install --id Starship.Starship -e --source winget --scope user --accept-package-agreements --accept-source-agreements
        Sync-Path

        if (Get-Command starship -ErrorAction SilentlyContinue) {
            Write-Ok "Starship installed via winget"
            return
        }
        Write-Warn "winget install did not complete (exit code $LASTEXITCODE) — it likely requires admin rights on this machine."
    }
    else {
        Write-Warn "winget not available, skipping straight to per-user install"
    }

    Install-StarshipManual
}

function Install-StarshipManual {
    # Downloads the official prebuilt binary directly and puts it on the
    # *user* PATH — no admin rights, no UAC prompt, no MSI.
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        return
    }

    Write-Log "Installing Starship for the current user only (no admin required)"

    $installDir = Join-Path $env:LOCALAPPDATA "Programs\starship"
    $exePath = Join-Path $installDir "starship.exe"

    if (Test-Path $exePath) {
        Write-Ok "Starship binary already present at $exePath"
    }
    else {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null

        $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
            'ARM64'  { 'aarch64' }
            'x86'    { 'i686' }
            default  { 'x86_64' }
        }
        $zipUrl = "https://github.com/starship/starship/releases/latest/download/starship-$arch-pc-windows-msvc.zip"
        $zipPath = Join-Path $env:TEMP "starship-$arch.zip"

        Write-Log "Downloading $zipUrl"
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        Remove-Item $zipPath -ErrorAction SilentlyContinue

        if (-not (Test-Path $exePath)) {
            throw "starship.exe not found in $installDir after extracting $zipUrl"
        }
        Write-Ok "Downloaded Starship to $installDir"
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $userPathEntries = @(); if ($userPath) { $userPathEntries = $userPath -split ';' }
    if ($userPathEntries -notcontains $installDir) {
        $newUserPath = if ($userPath) { "$($userPath.TrimEnd(';'));$installDir" } else { $installDir }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Ok "Added $installDir to your user PATH"
    }

    if (($env:Path -split ';') -notcontains $installDir) {
        $env:Path += ";$installDir"
    }

    Write-Ok "Starship installed for current user at $exePath"
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

function Install-TerminalIcons {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Write-Ok "Terminal-Icons already installed"
        return
    }

    Write-Log "Installing Terminal-Icons (file/folder icons in the terminal)"
    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
    Write-Ok "Terminal-Icons installed"
}

function Set-TerminalIconsWindowsGlyph {
    # Terminal-Icons' default theme maps the "windows" well-known folder to
    # nf-fa-windows. Override it to nf-custom-windows (U+E62A), which is the
    # glyph meant for this in current Nerd Fonts (v3+).
    $module = Get-Module -ListAvailable -Name Terminal-Icons | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        Write-Warn "Terminal-Icons module not found, skipping Windows icon override"
        return
    }

    $defaultTheme = Join-Path $module.ModuleBase "Data\iconThemes\devblackops.psd1"
    if (-not (Test-Path $defaultTheme)) {
        Write-Warn "Could not find default Terminal-Icons theme at $defaultTheme, skipping Windows icon override"
        return
    }

    if (-not (Test-Path $TerminalIconsCustomThemeDir)) {
        New-Item -ItemType Directory -Path $TerminalIconsCustomThemeDir -Force | Out-Null
    }

    Write-Log "Building custom icon theme (Windows folder -> nf-custom-windows)"
    $content = Get-Content $defaultTheme -Raw
    $content = $content -replace "(?<=Name\s*=\s*)'devblackops'", "'$TerminalIconsCustomThemeName'"
    $content = $content -replace "(?<=windows\s*=\s*)'nf-fa-windows'", "'nf-custom-windows'"

    if ($content -notmatch "windows\s*=\s*'nf-custom-windows'") {
        Write-Warn "Expected 'windows = ''nf-fa-windows''' entry not found in the installed theme (Terminal-Icons version may have changed layout)."
        Write-Warn "Copying the default theme through unmodified; the Windows folder icon override was NOT applied."
    }

    Set-Content -Path $TerminalIconsCustomThemeFile -Value $content

    # -Force makes this safe to re-run: it registers/overwrites the theme each time.
    Add-TerminalIconsIconTheme -Path $TerminalIconsCustomThemeFile -Force
    Write-Ok "Registered custom icon theme '$TerminalIconsCustomThemeName'"
}

function Set-TerminalIconsProfileConfig {
    $marker = "# --- oh-my-zsh-starship-terminal: Terminal-Icons config ---"
    $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($content -and $content.Contains($marker)) {
        Write-Ok "Terminal-Icons config already present in profile"
        return
    }

    $block = @"

$marker
Import-Module -Name Terminal-Icons
Set-TerminalIconsTheme -IconTheme '$TerminalIconsCustomThemeName'
"@

    Add-Content -Path $PROFILE -Value $block
    Write-Ok "Added Terminal-Icons config to profile"
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

Write-Log "Starting Starship + PSReadLine + Terminal-Icons setup for PowerShell"

Install-Starship
Update-PSReadLine
Install-TerminalIcons
Set-TerminalIconsWindowsGlyph
Initialize-Profile
Set-PSReadLineConfig
Set-TerminalIconsProfileConfig
Set-StarshipInit
Set-StarshipConfig

Write-Host ""
Write-Ok "All done!"
Write-Host "Restart your terminal, or run: . `$PROFILE"
