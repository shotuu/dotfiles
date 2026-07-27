#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$NoPackages,
    [switch]$TerminalOnly,
    [switch]$NvimOnly,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host @"
Usage: .\install.ps1 [options]

Options:
  -NoPackages     Do not install winget packages
  -TerminalOnly   Install WezTerm and Starship configuration only
  -NvimOnly       Install Neovim configuration only
  -Help           Show this help

There is no native Windows tmux build, so this installer never touches
.tmux.conf on Windows. WezTerm's own tab bar and Ctrl-Space pane bindings
take over instead (see README.md). If you'd rather use tmux for real, run
this repo's Linux install path inside WSL and let WezTerm hand off into it
automatically (also documented in README.md).
"@
    exit 0
}

$RepoRoot = $PSScriptRoot
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupRoot = Join-Path $HOME ".dotfiles-backups\$Stamp"

$InstallPackages = -not $NoPackages
$InstallWezTerm = $true
$InstallStarship = $true
$InstallProfile = $true
$InstallNvim = $true

if ($TerminalOnly) {
    $InstallNvim = $false
}
if ($NvimOnly) {
    $InstallWezTerm = $false
    $InstallStarship = $false
    $InstallProfile = $false
}

function Backup-Item {
    param([Parameter(Mandatory)][string]$Target)

    if (Test-Path -LiteralPath $Target) {
        $relative = $Target.Substring($HOME.Length).TrimStart('\', '/')
        $destination = Join-Path $BackupRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
        Copy-Item -LiteralPath $Target -Destination $destination -Recurse -Force
        Write-Host "Backed up: $Target"
    }
}

function Install-DotfileFile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    Backup-Item -Target $Target
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Force
    Write-Host "Installed: $Target"
}

function Install-DotfileDirectory {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    Backup-Item -Target $Target
    if (Test-Path -LiteralPath $Target) {
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force
    Write-Host "Installed: $Target"
}

function Install-Packages {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "winget was not found."
        Write-Host "Install 'App Installer' from the Microsoft Store, then run this installer again."
        exit 1
    }

    # winget IDs verified against microsoft/winget-pkgs. Each install is
    # independent: a single missing/renamed package warns and continues
    # rather than aborting the whole run.
    $packages = @(
        "wez.wezterm",
        "Neovim.Neovim",
        "Starship.Starship",
        "ajeetdsouza.zoxide",
        "junegunn.fzf",
        "eza-community.eza",
        "sharkdp.bat",
        "sharkdp.fd",
        "BurntSushi.ripgrep",
        "aristocratos.btop4win",
        "JesseDuffield.lazygit",
        "sxyazi.yazi",
        "Git.Git",
        "JohnnyMorganz.StyLua",
        "equalsraf.win32yank"
    )

    foreach ($id in $packages) {
        Write-Host "Installing $id..."
        winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget could not install $id (already installed, or unavailable on this system). Continuing."
        }
    }

    Write-Host ""
    Write-Host "No native Windows tmux build exists. This repo's WezTerm config binds"
    Write-Host "the same split/navigate/resize/new-tab actions to Ctrl-Space instead"
    Write-Host "(see README.md), or run the Linux install path inside WSL for real tmux."
    Write-Host ""
    Write-Host "Homebrew's Nerd Font cask has no winget equivalent. Download Hack Nerd"
    Write-Host "Font manually from https://www.nerdfonts.com and install it."
}

function Update-Profile {
    $blockPath = Join-Path $RepoRoot "shell\profile-managed-block.ps1"
    $block = (Get-Content -Raw -LiteralPath $blockPath).TrimEnd()

    $profilePath = $PROFILE
    Backup-Item -Target $profilePath
    New-Item -ItemType Directory -Force -Path (Split-Path $profilePath) | Out-Null
    if (-not (Test-Path -LiteralPath $profilePath)) {
        New-Item -ItemType File -Path $profilePath | Out-Null
    }

    $text = Get-Content -Raw -LiteralPath $profilePath
    if ($null -eq $text) {
        $text = ""
    }

    $pattern = "(?s)\r?\n?# >>> shotu-dotfiles >>>.*?# <<< shotu-dotfiles <<<\r?\n?"
    $text = [regex]::Replace($text, $pattern, "`n")

    $managed = "# >>> shotu-dotfiles >>>`n$block`n# <<< shotu-dotfiles <<<"
    $text = $text.TrimEnd() + "`n`n$managed`n"
    Set-Content -LiteralPath $profilePath -Value $text -NoNewline

    Write-Host "Updated: $profilePath"
}

Write-Host "Repository: $RepoRoot"
Write-Host "Platform:  windows"
Write-Host "Backups:   $BackupRoot"
Write-Host ""

if ($InstallPackages) {
    Install-Packages
}

if ($InstallWezTerm) {
    Install-DotfileFile `
        -Source (Join-Path $RepoRoot ".config\wezterm\wezterm.lua") `
        -Target (Join-Path $HOME ".config\wezterm\wezterm.lua")
}

if ($InstallStarship) {
    Install-DotfileFile `
        -Source (Join-Path $RepoRoot ".config\starship.toml") `
        -Target (Join-Path $HOME ".config\starship.toml")
}

if ($InstallProfile) {
    Update-Profile
}

if ($InstallNvim) {
    # Neovim on native Windows reads %LOCALAPPDATA%\nvim, not ~\.config\nvim.
    Install-DotfileDirectory `
        -Source (Join-Path $RepoRoot ".config\nvim") `
        -Target (Join-Path $env:LOCALAPPDATA "nvim")
}

Write-Host ""
Write-Host "Installation complete."
Write-Host "Quit WezTerm completely, then reopen it."
Write-Host "The first Neovim launch will install plugins automatically."
Write-Host ""
Write-Host "Backups were written to:"
Write-Host "  $BackupRoot"
