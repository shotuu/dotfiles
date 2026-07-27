# shotu-dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-232136?style=flat-square&logo=opensourceinitiative&logoColor=f6c177)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-232136?style=flat-square&logo=apple&logoColor=f6c177)](#macos)
[![Linux](https://img.shields.io/badge/Linux-232136?style=flat-square&logo=linux&logoColor=f6c177)](#linux)
[![Windows](https://img.shields.io/badge/Windows-232136?style=flat-square&logoColor=f6c177)](#windows-with-wsl-recommended-for-the-full-tmuxzsh-setup)
[![WezTerm](https://img.shields.io/badge/WezTerm-232136?style=flat-square&logo=wezterm&logoColor=f6c177)](https://wezterm.org)
[![tmux](https://img.shields.io/badge/tmux-232136?style=flat-square&logo=tmux&logoColor=f6c177)](https://github.com/tmux/tmux)
[![Neovim](https://img.shields.io/badge/Neovim-232136?style=flat-square&logo=neovim&logoColor=f6c177)](https://neovim.io)
[![zsh](https://img.shields.io/badge/zsh-232136?style=flat-square&logo=zsh&logoColor=f6c177)](https://www.zsh.org)
[![PowerShell](https://img.shields.io/badge/PowerShell-232136?style=flat-square&logoColor=f6c177)](https://github.com/PowerShell/PowerShell)
[![Starship](https://img.shields.io/badge/Starship-232136?style=flat-square&logo=starship&logoColor=f6c177)](https://starship.rs)
[![Homebrew](https://img.shields.io/badge/Homebrew-232136?style=flat-square&logo=homebrew&logoColor=f6c177)](https://brew.sh)

A portable terminal and Neovim setup for macOS, Linux, and Windows, built
around:

- WezTerm
- tmux (macOS, Linux, and Windows via WSL)
- zsh (macOS, Linux, and Windows via WSL) or PowerShell (native Windows)
- Starship
- zoxide
- Neovim
- Rosé Pine Moon
- modern command-line tools

The configuration is designed for a clean, modern terminal appearance with a
tmux status bar, persistent sessions, transparent Neovim UI, relative line
numbers, fuzzy finding, LSP support, completion, Git integration, and formatting.

On native Windows without WSL there is no tmux build, so WezTerm's own tab
bar and pane-splitting take over that role instead — see
[Windows without WSL](#windows-without-wsl) below.

## Screens and responsibilities

### WezTerm

WezTerm controls:

- font rendering
- window blur and transparency (blur is macOS-only; Linux gets transparency
  without blur, since Wayland/X11 compositors handle blur differently)
- window appearance
- GPU rendering
- URL handling

Its own tab bar is disabled wherever tmux provides the visible top bar
instead (macOS, Linux, and Windows-via-WSL). On native Windows without WSL,
WezTerm's tab bar is enabled instead, since there's no tmux to own that role.

The config file detects the platform at load time (via `wezterm.target_triple`)
and adjusts window decorations (macOS blur, Windows Acrylic backdrop), the
emoji font fallback, and the login shell automatically:

- macOS/Linux: launches zsh, which starts (or attaches to) tmux.
- Windows with WSL installed: launches into the default WSL distro's home
  directory; that distro's own zsh/tmux setup (from the Linux install path,
  run *inside* WSL) takes it from there.
- Windows without WSL: launches PowerShell (`pwsh` if installed, otherwise
  Windows PowerShell) directly, with no tmux involved.

`CMD`-modified keybindings map to Cmd on macOS and the Super/Windows key on
Linux and Windows, courtesy of WezTerm itself. WezTerm also has its own
`Ctrl-Space`-prefixed pane/tab bindings that mirror the tmux table below —
see [Windows without WSL](#windows-without-wsl).

### tmux

tmux controls:

- the top status bar
- window tabs
- username
- date and live clock with seconds
- pane splits and borders
- persistent sessions

### Starship and zsh

Starship displays the working directory, Git branch, Git status, and prompt.
zoxide provides `z` and `zi`.

### Neovim

Neovim includes:

- hybrid relative line numbers
- Rosé Pine Moon transparency
- Snacks dashboard, picker, explorer, notifications, and LazyGit
- blink.cmp completion
- Mason and LSP support
- Treesitter
- Conform formatting
- Gitsigns
- Which-key
- Lualine
- Flash navigation

## New-computer installation

`install.sh` (macOS/Linux/WSL) detects the OS automatically (`macos` or
`linux`) and adapts:

- On macOS, it installs both the cross-platform formulae (`Brewfile`) and the
  macOS-only casks (`Brewfile.mac`: WezTerm, Hack Nerd Font).
- On Linux (including inside WSL), it installs only the cross-platform
  formulae through Homebrew (which supports Linux via Linuxbrew) and skips
  the casks, since Homebrew casks aren't available on Linux. Install WezTerm
  from <https://wezterm.org/installation> and a Nerd Font from
  <https://www.nerdfonts.com> using your distribution's package manager.

`install.ps1` (native Windows, no WSL) uses `winget` instead of Homebrew, and
never touches tmux/zsh since neither exists natively on Windows — see
[Windows without WSL](#windows-without-wsl).

### macOS

Install Apple command-line tools first:

```bash
xcode-select --install
```

Install Homebrew from its official website, then clone this repository:

```bash
git clone YOUR_REPOSITORY_URL ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Linux

Install Homebrew for Linux from <https://brew.sh> (it installs to
`/home/linuxbrew/.linuxbrew` and the managed zsh block picks that prefix up
automatically), then clone this repository:

```bash
git clone YOUR_REPOSITORY_URL ~/dotfiles
cd ~/dotfiles
./install.sh
```

### Windows with WSL (recommended for the full tmux/zsh setup)

Install WSL2 and a distro (Ubuntu is the default) from an elevated PowerShell
prompt:

```powershell
wsl --install
```

Then open that distro and follow the **Linux** instructions above, inside
WSL:

```bash
git clone YOUR_REPOSITORY_URL ~/dotfiles
cd ~/dotfiles
./install.sh
chsh -s $(which zsh)   # if zsh isn't already your WSL login shell
```

Install WezTerm on the **Windows** side (not inside WSL) from
<https://wezterm.org/installation> or `winget install wez.wezterm`, then copy
this repo's WezTerm config to the Windows side too, since that's what
actually runs:

```powershell
mkdir -Force $HOME\.config\wezterm
Copy-Item \\wsl$\Ubuntu\home\YOUR_USER\dotfiles\.config\wezterm\wezterm.lua $HOME\.config\wezterm\wezterm.lua
```

WezTerm detects WSL automatically and launches straight into it — no further
config is needed. Reopen WezTerm after installing.

### Windows without WSL

No WSL, no Linux VM — this uses `install.ps1`, winget, and PowerShell instead
of Homebrew and zsh. Open PowerShell and run:

```powershell
git clone YOUR_REPOSITORY_URL $HOME\dotfiles
cd $HOME\dotfiles
.\install.ps1
```

If script execution is blocked, allow locally-created scripts for your user
first: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

Two things are structurally different here, since neither exists natively on
Windows:

- **No tmux.** `install.ps1` never installs `.tmux.conf`. Instead, WezTerm's
  own tab bar and pane splitting take over, bound to `Ctrl-Space` (WezTerm's
  `LEADER` key) so they don't collide with tmux's `Ctrl-A` on the other
  platforms:

  | Shortcut | Action |
  |---|---|
  | `Ctrl-Space`, `c` | New tab |
  | `Ctrl-Space`, `n` | Next tab |
  | `Ctrl-Space`, `p` | Previous tab |
  | `Ctrl-Space`, `\|` | Split left/right |
  | `Ctrl-Space`, `-` | Split top/bottom |
  | `Ctrl-Space`, `h/j/k/l` | Move between panes |
  | `Ctrl-Space`, `Shift-h/j/k/l` | Resize panes |
  | `Ctrl-Space`, `z` | Zoom pane |
  | `Ctrl-Space`, `r` | Reload WezTerm configuration |

- **No zsh.** `install.ps1` writes a managed block
  (`shell/profile-managed-block.ps1`) into your PowerShell `$PROFILE`
  instead of `~/.zshrc`, aliasing `eza`/`bat` and initializing
  zoxide/Starship. PSReadLine's built-in predictive IntelliSense stands in
  for zsh-autosuggestions.

Homebrew's Nerd Font cask has no winget equivalent, so download Hack Nerd
Font manually from <https://www.nerdfonts.com> and install it yourself.
Neovim clipboard integration uses `win32yank` (installed by `install.ps1`
via winget) when present, and falls back to OSC 52 clipboard forwarding
through WezTerm automatically if it isn't.

### From a downloaded ZIP

```bash
unzip shotu-dotfiles.zip
cd shotu-dotfiles
./install.sh
```

The installer creates timestamped backups in:

```text
~/.dotfiles-backups/
```

It also removes the legacy `~/.wezterm.lua` after backing it up, because that
file overrides `~/.config/wezterm/wezterm.lua`.

## Selective installation

Terminal configuration only:

```bash
./install.sh --terminal-only     # macOS/Linux/WSL
.\install.ps1 -TerminalOnly      # Windows without WSL
```

Neovim configuration only:

```bash
./install.sh --nvim-only         # macOS/Linux/WSL
.\install.ps1 -NvimOnly          # Windows without WSL
```

Skip package installation:

```bash
./install.sh --no-packages       # macOS/Linux/WSL
.\install.ps1 -NoPackages        # Windows without WSL
```

## Updating

After cloning the repository from GitHub:

```bash
cd ~/dotfiles
./update.sh       # macOS/Linux/WSL
.\update.ps1      # Windows without WSL
```

## tmux shortcuts

The prefix is `Ctrl-A`. Press and release it, then press the second key.

| Shortcut | Action |
|---|---|
| `Ctrl-A`, `c` | New window |
| `Ctrl-A`, `n` | Next window |
| `Ctrl-A`, `p` | Previous window |
| `Ctrl-A`, `1–9` | Jump to a window |
| `Ctrl-A`, `|` | Split left/right |
| `Ctrl-A`, `-` | Split top/bottom |
| `Ctrl-A`, `h/j/k/l` | Move between panes |
| `Ctrl-A`, `H/J/K/L` | Resize panes |
| `Ctrl-A`, `z` | Zoom pane |
| `Ctrl-A`, `d` | Detach |
| `Ctrl-A`, `r` | Reload tmux configuration |
| `Ctrl-A`, `[` | Copy mode |

## Neovim shortcuts

The leader key is Space.

| Shortcut | Action |
|---|---|
| `Space f f` | Find files |
| `Space /` | Search project text |
| `Space e` | File explorer |
| `Space g g` | LazyGit |
| `Space c a` | Code action |
| `Space c r` | Rename symbol |
| `Space c f` | Format |
| `g d` | Go to definition |
| `g r` | References |
| `K` | Hover documentation |
| `] d` / `[ d` | Next/previous diagnostic |
| `s` | Flash jump |
| `Shift-H` / `Shift-L` | Previous/next buffer |

## Publishing this as your own Git repository

Create an empty repository on GitHub, GitLab, or another Git host. Then run:

```bash
cd ~/dotfiles
git init
git add .
git commit -m "Initial dotfiles setup"
git branch -M main
git remote add origin YOUR_REPOSITORY_URL
git push -u origin main
```

Do not add private SSH keys, API tokens, passwords, shell-history files, or
machine-specific secrets to this repository.

## Restoring the latest backup

```bash
./scripts/restore-latest-backup.sh     # macOS/Linux/WSL
.\scripts\restore-latest-backup.ps1    # Windows without WSL
```

Review the backup path carefully before confirming.
