#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.dotfiles-backups/$STAMP"

case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)
    echo "Unsupported OS: $(uname -s)"
    echo "This installer supports macOS and Linux."
    exit 1
    ;;
esac

INSTALL_PACKAGES=true
INSTALL_WEZTERM=true
INSTALL_TMUX=true
INSTALL_STARSHIP=true
INSTALL_ZSH=true
INSTALL_NVIM=true

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --no-packages   Do not install Homebrew packages
  --terminal-only Install WezTerm, tmux, Starship, and zsh only
  --nvim-only     Install Neovim configuration only
  --help          Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-packages)
      INSTALL_PACKAGES=false
      ;;
    --terminal-only)
      INSTALL_NVIM=false
      ;;
    --nvim-only)
      INSTALL_WEZTERM=false
      INSTALL_TMUX=false
      INSTALL_STARSHIP=false
      INSTALL_ZSH=false
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

backup_file() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local relative="${target#$HOME/}"
    local destination="$BACKUP_ROOT/$relative"
    mkdir -p "$(dirname "$destination")"
    cp -R "$target" "$destination"
    echo "Backed up: $target"
  fi
}

copy_file() {
  local source="$1"
  local target="$2"
  backup_file "$target"
  mkdir -p "$(dirname "$target")"
  cp "$source" "$target"
  echo "Installed: $target"
}

copy_directory() {
  local source="$1"
  local target="$2"
  backup_file "$target"
  rm -rf "$target"
  mkdir -p "$(dirname "$target")"
  cp -R "$source" "$target"
  echo "Installed: $target"
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  echo "Homebrew was not found."
  echo "Install Homebrew from https://brew.sh and run this installer again."
  echo "(Homebrew supports both macOS and Linux.)"
  exit 1
}

install_packages() {
  install_homebrew
  echo "Installing packages from Brewfile..."
  brew bundle --file="$REPO_ROOT/Brewfile"

  if [[ "$OS" == "macos" ]]; then
    echo "Installing macOS casks from Brewfile.mac..."
    brew bundle --file="$REPO_ROOT/Brewfile.mac"
  else
    echo "Skipping macOS-only casks (WezTerm, Nerd Font) on Linux."
    echo "Install WezTerm from https://wezterm.org/installation and a Nerd" \
      "Font (e.g. Hack Nerd Font from https://www.nerdfonts.com) using your" \
      "distribution's package manager."
  fi
}

update_zshrc() {
  local zshrc="$HOME/.zshrc"
  local block="$REPO_ROOT/shell/zshrc-managed-block.zsh"

  backup_file "$zshrc"
  touch "$zshrc"

  python3 - "$zshrc" "$block" <<'PY'
from pathlib import Path
import re
import sys

zshrc = Path(sys.argv[1])
block = Path(sys.argv[2]).read_text().strip()
text = zshrc.read_text()

text = re.sub(
    r"\n?# >>> shotu-dotfiles >>>.*?# <<< shotu-dotfiles <<<\n?",
    "\n",
    text,
    flags=re.S,
)

# Remove the marker names used by earlier versions of this installer too,
# so renaming the repo never leaves a stale duplicate block behind.
for legacy_marker in ("danwu-dotfiles", "kunchen-terminal-setup"):
    text = re.sub(
        r"\n?# >>> " + re.escape(legacy_marker) + r" >>>.*?# <<< " + re.escape(legacy_marker) + r" <<<\n?",
        "\n",
        text,
        flags=re.S,
    )

managed = (
    "# >>> shotu-dotfiles >>>\n"
    + block
    + "\n# <<< shotu-dotfiles <<<"
)

zshrc.write_text(text.rstrip() + "\n\n" + managed + "\n")
PY

  echo "Updated: $zshrc"
}

echo "Repository: $REPO_ROOT"
echo "Platform:  $OS"
echo "Backups:   $BACKUP_ROOT"
echo

if [[ "$INSTALL_PACKAGES" == true ]]; then
  install_packages
fi

if [[ "$INSTALL_WEZTERM" == true ]]; then
  # Remove the legacy top-level config after backing it up; otherwise it can
  # override ~/.config/wezterm/wezterm.lua.
  if [[ -e "$HOME/.wezterm.lua" || -L "$HOME/.wezterm.lua" ]]; then
    backup_file "$HOME/.wezterm.lua"
    rm -f "$HOME/.wezterm.lua"
    echo "Removed legacy ~/.wezterm.lua so the XDG config is used."
  fi
  copy_file \
    "$REPO_ROOT/.config/wezterm/wezterm.lua" \
    "$HOME/.config/wezterm/wezterm.lua"
fi

if [[ "$INSTALL_TMUX" == true ]]; then
  copy_file "$REPO_ROOT/.tmux.conf" "$HOME/.tmux.conf"
fi

if [[ "$INSTALL_STARSHIP" == true ]]; then
  copy_file \
    "$REPO_ROOT/.config/starship.toml" \
    "$HOME/.config/starship.toml"
fi

if [[ "$INSTALL_ZSH" == true ]]; then
  update_zshrc
fi

if [[ "$INSTALL_NVIM" == true ]]; then
  copy_directory \
    "$REPO_ROOT/.config/nvim" \
    "$HOME/.config/nvim"
fi

echo
echo "Installation complete."
if [[ "$OS" == "macos" ]]; then
  echo "Quit WezTerm completely with Cmd-Q, then reopen it."
else
  echo "Quit WezTerm completely, then reopen it."
fi
echo "The first Neovim launch will install plugins automatically."
echo
echo "Backups were written to:"
echo "  $BACKUP_ROOT"
