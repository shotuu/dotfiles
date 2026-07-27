#requires -Version 5.1
$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot

Write-Host "Updating repository..."
git -C $RepoRoot pull --ff-only

Write-Host "Reapplying configuration..."
& (Join-Path $RepoRoot "install.ps1") -NoPackages

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Updating winget packages..."
    winget upgrade --all --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "Done."
