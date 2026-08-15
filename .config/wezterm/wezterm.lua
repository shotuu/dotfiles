local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

local is_macos = wezterm.target_triple:find("darwin") ~= nil
local is_windows = wezterm.target_triple:find("windows") ~= nil

-- Find zsh across common install locations instead of assuming macOS's
-- fixed /bin/zsh path, since Linux distributions vary (and Linuxbrew has
-- its own prefix). Only used on macOS/Linux; native Windows uses PowerShell
-- instead (see below).
local function find_zsh()
  for _, path in ipairs({
    "/bin/zsh",
    "/usr/bin/zsh",
    "/usr/local/bin/zsh",
    "/opt/homebrew/bin/zsh",
    "/home/linuxbrew/.linuxbrew/bin/zsh",
  }) do
    if #wezterm.glob(path) > 0 then
      return path
    end
  end
  return os.getenv("SHELL") or "/bin/sh"
end

local zsh = not is_windows and find_zsh() or nil

-- Best-effort "does this command exist" check that never throws, since
-- wsl.exe/pwsh.exe may simply not be installed.
local function command_succeeds(args)
  local ok, success = pcall(wezterm.run_child_process, args)
  return ok and success == true
end

local has_wsl = is_windows and command_succeeds({ "wsl.exe", "-l", "-q" })
local has_pwsh = is_windows and command_succeeds({ "where", "pwsh.exe" })

-- True when the default shell this config launches will itself start tmux
-- (macOS/Linux, and Windows when handing off into WSL). False only for
-- native Windows without WSL, where there is no tmux build, so WezTerm's
-- own tab bar and LEADER-key pane bindings take over instead.
local uses_tmux = not is_windows or has_wsl

local rose = {
  base = "#232136",
  surface = "#2a273f",
  overlay = "#393552",
  muted = "#6e6a86",
  subtle = "#908caa",
  text = "#e0def4",
  love = "#eb6f92",
  gold = "#f6c177",
  rose = "#ea9a97",
  pine = "#3e8fb0",
  foam = "#9ccfd8",
  iris = "#c4a7e7",
  highlight_med = "#44415a",
}

local emoji_font = "Noto Color Emoji"
if is_macos then
  emoji_font = "Apple Color Emoji"
elseif is_windows then
  emoji_font = "Segoe UI Emoji"
end

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font_with_fallback({
  { family = "Hack Nerd Font", weight = "Regular" },
  emoji_font,
})
config.font_size = 15.0
config.line_height = 1.05

config.window_background_opacity = 0.88
if is_macos then
  config.macos_window_background_blur = 35
  config.window_decorations = "RESIZE | MACOS_FORCE_ENABLE_SHADOW"
elseif is_windows then
  -- Closest Windows equivalent of macOS's blur; requires
  -- window_background_opacity < 1.0, which is already set above.
  config.win32_system_backdrop = "Acrylic"
  config.window_decorations = "RESIZE"
else
  config.window_decorations = "RESIZE"
end
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }
config.initial_cols = 120
config.initial_rows = 34
config.adjust_window_size_when_changing_font_size = false
config.enable_scroll_bar = false
config.window_close_confirmation = "NeverPrompt"
config.term = "xterm-256color"

config.front_end = "WebGpu"
config.webgpu_power_preference = "HighPerformance"
config.max_fps = 120
config.animation_fps = 60

-- tmux owns the top status bar wherever it's available, so hide WezTerm's
-- own tab bar to avoid two bars. On native Windows without WSL there is no
-- tmux build, so WezTerm's tab bar (plus the LEADER-key bindings below)
-- takes over pane/tab visibility and navigation instead.
config.enable_tab_bar = not uses_tmux

config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
config.audible_bell = "Disabled"
config.scrollback_lines = 10000

config.colors = {
  split = rose.highlight_med,
  visual_bell = rose.highlight_med,
}

if is_windows then
  if has_wsl then
    -- Hand off into the default WSL distro's home directory. That distro's
    -- own login shell and profile (set up via this repo's Linux install
    -- path, run *inside* WSL) is responsible for starting zsh and tmux,
    -- exactly as on native Linux.
    config.default_prog = { "wsl.exe", "--cd", "~" }
  else
    -- No WSL: fall back to PowerShell. Prefer PowerShell 7+ (pwsh) when
    -- installed, otherwise the Windows PowerShell that ships with Windows.
    config.default_prog = { has_pwsh and "pwsh.exe" or "powershell.exe", "-NoLogo" }
  end
else
  -- Start tmux automatically only for a fresh local window.
  -- Inside an existing tmux session, start a normal zsh shell instead.
  config.default_prog = {
    zsh,
    "-lc",
    ([=[
      if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]]; then
        exec tmux new-session -A -s main
      else
        exec %s -l
      fi
    ]=]):format(zsh),
  }
end

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
  { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
  { key = "t", mods = "CMD", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },
  { key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
  { key = "=", mods = "CMD", action = act.IncreaseFontSize },
  { key = "-", mods = "CMD", action = act.DecreaseFontSize },
  { key = "0", mods = "CMD", action = act.ResetFontSize },
  { key = "Enter", mods = "CMD", action = act.ToggleFullScreen },

  -- Pane/tab multiplexing built into WezTerm itself, mirroring the tmux
  -- bindings documented in the README (split, navigate, resize, zoom, new
  -- window). These use LEADER (Ctrl-Space) rather than tmux's Ctrl-A, so
  -- they coexist safely when tmux is also running. They matter most on
  -- native Windows without WSL, where no tmux build exists at all.
  { key = "|", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "h", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "j", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "k", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "l", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CMD",
    action = act.OpenLinkAtMouseCursor,
  },
}

return config
