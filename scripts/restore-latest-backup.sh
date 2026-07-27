#!/usr/bin/env bash
set -euo pipefail

BACKUP_BASE="$HOME/.dotfiles-backups"
LATEST="$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1)"

if [[ -z "${LATEST:-}" ]]; then
  echo "No backups found in $BACKUP_BASE"
  exit 1
fi

echo "Latest backup: $LATEST"
echo "This script restores files from that backup into your home directory."
read -r -p "Continue? [y/N] " answer

case "$answer" in
  y|Y)
    cp -R "$LATEST"/. "$HOME"/
    echo "Backup restored."
    ;;
  *)
    echo "Cancelled."
    ;;
esac
