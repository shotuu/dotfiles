#requires -Version 5.1
$ErrorActionPreference = "Stop"

$BackupBase = Join-Path $HOME ".dotfiles-backups"
$Latest = Get-ChildItem -LiteralPath $BackupBase -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -Last 1

if (-not $Latest) {
    Write-Host "No backups found in $BackupBase"
    exit 1
}

Write-Host "Latest backup: $($Latest.FullName)"
Write-Host "This script restores files from that backup into your home directory."
$answer = Read-Host "Continue? [y/N]"

if ($answer -match '^[Yy]$') {
    Copy-Item -Path (Join-Path $Latest.FullName '*') -Destination $HOME -Recurse -Force
    Write-Host "Backup restored."
} else {
    Write-Host "Cancelled."
}
