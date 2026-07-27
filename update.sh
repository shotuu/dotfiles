#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Updating repository..."
git -C "$ROOT" pull --ff-only

echo "Reapplying configuration..."
"$ROOT/install.sh" --no-packages

if command -v brew >/dev/null 2>&1; then
  echo "Updating Homebrew packages..."
  brew update
  brew upgrade
fi

echo "Done."
