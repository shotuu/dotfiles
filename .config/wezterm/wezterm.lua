local wezterm = require("wezterm")
local act = wezterm.action
local mux = wezterm.mux
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

-- True only when handing off into WSL, whose own login shell/profile starts
-- tmux itself (see default_prog below). Local macOS/Linux windows no longer
-- auto-start tmux, so WezTerm's own tab bar and LEADER-key pane bindings
-- take over there instead.
local uses_tmux = is_windows and has_wsl

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

-- tmux owns the top status bar inside WSL, so hide WezTerm's own tab bar
-- there to avoid two bars. Everywhere else, WezTerm's tab bar (plus the
-- LEADER-key bindings below) handles pane/tab visibility and navigation.
config.enable_tab_bar = not uses_tmux

config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 600
config.audible_bell = "Disabled"
config.scrollback_lines = 10000

config.colors = {
  split = rose.highlight_med,
  visual_bell = rose.highlight_med,
  tab_bar = {
    -- One step lighter than the terminal background (rose.base) so the bar
    -- reads as a distinct strip instead of blending into the pane.
    background = rose.surface,
    active_tab = { bg_color = rose.iris, fg_color = rose.base },
    inactive_tab = { bg_color = rose.surface, fg_color = rose.subtle },
    inactive_tab_hover = { bg_color = rose.overlay, fg_color = rose.text },
    new_tab = { bg_color = rose.surface, fg_color = rose.muted },
    new_tab_hover = { bg_color = rose.overlay, fg_color = rose.iris },
  },
}

-- The default "fancy" tab bar (used since window_decorations has no TITLE)
-- draws its surrounding chrome from window_frame, not from color_scheme, so
-- it needs its own Rose Pine colors to avoid falling back to WezTerm's
-- neutral gray/black default.
config.window_frame = {
  font = config.font,
  font_size = 13.0,
  active_titlebar_bg = rose.surface,
  inactive_titlebar_bg = rose.surface,
  active_titlebar_fg = rose.text,
  inactive_titlebar_fg = rose.muted,
  active_titlebar_border_bottom = rose.iris,
  inactive_titlebar_border_bottom = rose.highlight_med,
  button_fg = rose.text,
  button_bg = rose.surface,
  button_hover_fg = rose.text,
  button_hover_bg = rose.overlay,
}

config.tab_max_width = 28

-- Every process falls back to WezTerm's default tab title, which is either
-- an OSC-set title (some programs set one, some don't) or the bare
-- foreground process name -- hence tabs inconsistently reading "node" vs
-- "zsh" vs a program's own title. This normalizes every tab to an icon plus
-- a short, relevant label: shells show their working directory, dev tools
-- get a proper name instead of a raw binary name.
local nf = wezterm.nerdfonts
local ICON_SHELL = nf.md_console or nf.dev_terminal or ""
local ICON_VIM = nf.custom_vim or nf.dev_vim or ""
local ICON_NODE = nf.dev_nodejs_small or nf.md_nodejs or ""
local ICON_GIT = nf.dev_git or nf.md_git or ""
local ICON_PYTHON = nf.md_language_python or nf.dev_python or ""
local ICON_SSH = nf.md_ssh or nf.cod_remote or ICON_SHELL
local ICON_CLAUDE = nf.md_robot or nf.md_robot_outline or ""
local ICON_DOCKER = nf.dev_docker or nf.md_docker or ""
local ICON_MULTIPLEX = nf.cod_multiple_windows or nf.md_view_grid or ICON_SHELL
local ICON_MONITOR = nf.md_speedometer or nf.md_chart_line or ICON_SHELL
local ICON_FILES = nf.md_folder or nf.oct_file_directory or ICON_SHELL
local ICON_SEARCH = nf.md_magnify or nf.oct_search or ICON_SHELL
local ICON_NPM = nf.dev_npm or ICON_NODE
local ICON_YARN = nf.dev_yarn or ICON_NODE
local ICON_RUST = nf.dev_rust or nf.md_language_rust or ICON_SHELL
local ICON_GO = nf.md_language_go or nf.dev_go or ICON_SHELL
local ICON_RUBY = nf.dev_ruby or nf.md_language_ruby or ICON_SHELL
local ICON_JAVA = nf.dev_java or nf.md_language_java or ICON_SHELL
local ICON_PHP = nf.dev_php or nf.md_language_php or ICON_SHELL
local ICON_BUILD = nf.md_hammer_wrench or nf.oct_tools or ICON_SHELL
local ICON_NET = nf.md_web or nf.oct_globe or ICON_SHELL
local ICON_DB = nf.md_database or nf.oct_database or ICON_SHELL
local ICON_K8S = nf.md_kubernetes or ICON_SHELL
local ICON_CLOUD = nf.md_cloud or nf.oct_cloud or ICON_SHELL
local ICON_SHIELD = nf.md_shield_lock or nf.md_shield or ICON_SHELL
local ICON_PACKAGE = nf.md_package_variant or nf.oct_package or ICON_SHELL

-- Static icon/label pairs for tools whose title doesn't need to be dynamic.
-- Covers everything in this repo's Brewfile (tmux, lazygit, btop, yazi, bat,
-- fd, ripgrep, fzf, git, neovim, stylua) plus common language toolchains,
-- package managers, build tools, and ops CLIs likely to run in this
-- terminal. zsh/bash/nvim/node/ssh are handled separately below since their
-- labels depend on cwd or an OSC title rather than being fixed.
local TOOL_ICONS = {
  git = { icon = ICON_GIT, label = "Git" },
  lazygit = { icon = ICON_GIT, label = "Lazygit" },
  gh = { icon = ICON_GIT, label = "GitHub CLI" },
  tmux = { icon = ICON_MULTIPLEX, label = "tmux" },
  btop = { icon = ICON_MONITOR, label = "btop" },
  htop = { icon = ICON_MONITOR, label = "htop" },
  top = { icon = ICON_MONITOR, label = "top" },
  yazi = { icon = ICON_FILES, label = "Yazi" },
  bat = { icon = ICON_FILES, label = "bat" },
  less = { icon = ICON_FILES, label = "less" },
  man = { icon = ICON_FILES, label = "man" },
  rg = { icon = ICON_SEARCH, label = "ripgrep" },
  fd = { icon = ICON_SEARCH, label = "fd" },
  fzf = { icon = ICON_SEARCH, label = "fzf" },
  zoxide = { icon = ICON_SEARCH, label = "zoxide" },
  eza = { icon = ICON_FILES, label = "eza" },
  claude = { icon = ICON_CLAUDE, label = "Claude" },
  python = { icon = ICON_PYTHON, label = "Python" },
  python3 = { icon = ICON_PYTHON, label = "Python" },
  npm = { icon = ICON_NPM, label = "npm" },
  pnpm = { icon = ICON_NODE, label = "pnpm" },
  yarn = { icon = ICON_YARN, label = "Yarn" },
  deno = { icon = ICON_NODE, label = "Deno" },
  bun = { icon = ICON_NODE, label = "Bun" },
  cargo = { icon = ICON_RUST, label = "Cargo" },
  rustc = { icon = ICON_RUST, label = "Rust" },
  go = { icon = ICON_GO, label = "Go" },
  ruby = { icon = ICON_RUBY, label = "Ruby" },
  java = { icon = ICON_JAVA, label = "Java" },
  php = { icon = ICON_PHP, label = "PHP" },
  make = { icon = ICON_BUILD, label = "make" },
  cmake = { icon = ICON_BUILD, label = "cmake" },
  gcc = { icon = ICON_BUILD, label = "gcc" },
  clang = { icon = ICON_BUILD, label = "clang" },
  stylua = { icon = ICON_BUILD, label = "Stylua" },
  curl = { icon = ICON_NET, label = "curl" },
  wget = { icon = ICON_NET, label = "wget" },
  ping = { icon = ICON_NET, label = "ping" },
  docker = { icon = ICON_DOCKER, label = "Docker" },
  ["docker-compose"] = { icon = ICON_DOCKER, label = "Docker Compose" },
  podman = { icon = ICON_DOCKER, label = "Podman" },
  kubectl = { icon = ICON_K8S, label = "kubectl" },
  terraform = { icon = ICON_CLOUD, label = "Terraform" },
  aws = { icon = ICON_CLOUD, label = "AWS" },
  gcloud = { icon = ICON_CLOUD, label = "gcloud" },
  az = { icon = ICON_CLOUD, label = "Azure" },
  mysql = { icon = ICON_DB, label = "MySQL" },
  psql = { icon = ICON_DB, label = "Postgres" },
  ["redis-cli"] = { icon = ICON_DB, label = "Redis" },
  mongosh = { icon = ICON_DB, label = "Mongo" },
  sqlite3 = { icon = ICON_DB, label = "SQLite" },
  sudo = { icon = ICON_SHIELD, label = "sudo" },
  brew = { icon = ICON_PACKAGE, label = "Homebrew" },
}

local function cwd_basename(pane)
  local cwd = pane.current_working_dir
  if not cwd then
    return nil
  end
  local path = type(cwd) == "string" and cwd or cwd.file_path
  if not path then
    return nil
  end
  path = tostring(path):gsub("^file://[^/]*", ""):gsub("/$", "")
  return path:match("([^/\\]+)$")
end

local function tab_icon_and_label(pane)
  local process = pane.foreground_process_name or ""
  local basename = (process:match("([^/\\]+)$") or process):gsub("%.exe$", ""):lower()
  local title = pane.title or ""

  -- claude's own launcher is a symlink (~/.local/bin/claude) into a
  -- versioned binary (~/.local/share/claude/versions/2.1.234), and WezTerm
  -- reports the resolved path's basename -- the version number -- rather
  -- than the symlink name. Catch that by path shape instead of by name.
  if process:find("/claude/versions/", 1, true) then
    return ICON_CLAUDE, "Claude"
  end

  if basename == "zsh" or basename == "bash" or basename == "fish" or basename == "sh" then
    return ICON_SHELL, cwd_basename(pane) or "shell"
  elseif basename == "nvim" or basename == "vim" then
    return ICON_VIM, (title ~= "" and title ~= basename) and title or "Neovim"
  elseif basename == "node" or basename == "npx" then
    return ICON_NODE, (title ~= "" and title:lower() ~= basename) and title or "Node"
  elseif basename == "ssh" then
    return ICON_SSH, (title ~= "" and title) or "SSH"
  end

  local known = TOOL_ICONS[basename]
  if known then
    return known.icon, known.label
  end

  if basename ~= "" then
    return ICON_SHELL, basename:sub(1, 1):upper() .. basename:sub(2)
  end
  return ICON_SHELL, "shell"
end

wezterm.on("format-tab-title", function(tab, _tabs, _panes, _config, hover, max_width)
  local ok, icon, label = pcall(function()
    return tab_icon_and_label(tab.active_pane)
  end)
  if not ok then
    icon, label = ICON_SHELL, "shell"
  end

  local text = string.format(" %d %s %s ", tab.tab_index + 1, icon, label)
  if #text > max_width then
    text = wezterm.truncate_right(text, max_width - 1) .. "…"
  end

  local bg, fg
  if tab.is_active then
    bg, fg = rose.iris, rose.base
  elseif hover then
    bg, fg = rose.overlay, rose.text
  else
    bg, fg = rose.surface, rose.subtle
  end

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = text },
  }
end)

-- Right-status: LEADER indicator, git branch, username, and a live clock
-- accurate to the second. status_update_interval controls how often
-- update-status fires; 1000ms keeps the seconds digit ticking in real time
-- (it also matches the LEADER timeout, so that indicator stays responsive).
config.status_update_interval = 1000

local ICON_USER = nf.md_account or nf.fa_user or ""
local ICON_CLOCK = nf.md_clock_outline or nf.fa_clock_o or ""
local ICON_BRANCH = nf.oct_git_branch or nf.dev_git_branch or ICON_GIT
local username = os.getenv(is_windows and "USERNAME" or "USER") or "user"

-- The update-status event hands us a full Pane object (get_current_working_dir
-- is a method here), unlike format-tab-title's lightweight PaneInformation
-- table used above -- hence a separate cwd getter.
local function status_pane_cwd_path(pane)
  local ok, cwd = pcall(function()
    return pane:get_current_working_dir()
  end)
  if not ok or not cwd then
    return nil
  end
  local path = type(cwd) == "string" and cwd or cwd.file_path
  if not path or path == "" then
    return nil
  end
  path = tostring(path):gsub("^file://[^/]*", ""):gsub("/$", "")
  return path ~= "" and path or nil
end

-- Runs `git status` for the active pane's directory; returns nil when it's
-- not a git repo (or git/the path isn't available) rather than erroring, so
-- a non-repo directory just omits the segment.
local function git_status_for_pane(pane)
  local dir = status_pane_cwd_path(pane)
  if not dir then
    return nil
  end

  local ok, stdout = wezterm.run_child_process({
    "git",
    "-C",
    dir,
    "status",
    "--porcelain=v2",
    "--branch",
    "--untracked-files=normal",
  })
  if not ok or not stdout then
    return nil
  end

  local branch, oid, dirty = nil, nil, false
  for line in stdout:gmatch("[^\n]+") do
    local head = line:match("^# branch%.head (.+)$")
    local commit = line:match("^# branch%.oid (%x+)")
    if head then
      branch = head
    elseif commit then
      oid = commit
    elseif line:sub(1, 1) ~= "#" then
      dirty = true
    end
  end

  if not branch then
    return nil
  end
  if branch == "(detached)" then
    branch = oid and oid:sub(1, 7) or "detached"
  end
  return branch, dirty
end

wezterm.on("update-status", function(window, pane)
  local ok, formatted = pcall(function()
    local elements = {}

    if window:leader_is_active() then
      table.insert(elements, { Foreground = { Color = rose.base } })
      table.insert(elements, { Background = { Color = rose.gold } })
      table.insert(elements, { Text = " LEADER " })
      table.insert(elements, { Background = { Color = rose.surface } })
      table.insert(elements, { Text = "  " })
    end

    local branch, dirty = git_status_for_pane(pane)
    if branch then
      table.insert(elements, { Foreground = { Color = dirty and rose.gold or rose.foam } })
      table.insert(elements, { Text = ICON_BRANCH .. " " .. branch .. (dirty and " *" or "") .. "  " })
      table.insert(elements, { Foreground = { Color = rose.highlight_med } })
      table.insert(elements, { Text = "|  " })
    end

    table.insert(elements, { Foreground = { Color = rose.subtle } })
    table.insert(elements, { Text = ICON_USER .. " " .. username .. "  " })
    table.insert(elements, { Foreground = { Color = rose.highlight_med } })
    table.insert(elements, { Text = "|  " })
    table.insert(elements, { Foreground = { Color = rose.subtle } })
    table.insert(elements, { Text = ICON_CLOCK .. " " .. wezterm.strftime("%Y-%m-%d %H:%M:%S") .. "  " })

    return wezterm.format(elements)
  end)
  window:set_right_status(ok and formatted or "")
end)

-- Cmd-T and LEADER-c (below) set WEZTERM_NEW_TAB to trigger the welcome
-- banner, but neither fires for the window WezTerm opens on launch -- that
-- one is spawned by gui-startup instead, so it needs the same treatment or
-- the banner never shows up on a fresh launch. args is set explicitly
-- (mirroring config.default_prog) rather than left for SpawnCommand to
-- infer, because leaving it nil silently drops set_environment_variables
-- on some WezTerm builds when falling back to the default program.
wezterm.on("gui-startup", function(cmd)
  local args = cmd or {}
  args.args = args.args or config.default_prog
  args.cwd = args.cwd or wezterm.home_dir
  args.set_environment_variables = args.set_environment_variables or {}
  args.set_environment_variables.WEZTERM_NEW_TAB = "1"
  mux.spawn_window(args)
end)

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
  -- Plain login shell; tmux is no longer started automatically.
  config.default_prog = { zsh, "-l" }
end

config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
  { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
  -- New tabs always start at $HOME, unlike splits (below), which inherit
  -- the current pane's working directory -- that's the whole point of a
  -- split versus a fresh tab. WEZTERM_NEW_TAB tells .zshrc's welcome
  -- banner (shell/wezterm-welcome.zsh) this pane is an actual new tab, not
  -- a split or a nested shell, so it only shows there.
  {
    key = "t",
    mods = "CMD",
    action = act.SpawnCommandInNewTab({
      args = config.default_prog,
      cwd = wezterm.home_dir,
      domain = "CurrentPaneDomain",
      set_environment_variables = { WEZTERM_NEW_TAB = "1" },
    }),
  },
  { key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },
  { key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
  { key = "=", mods = "CMD", action = act.IncreaseFontSize },
  { key = "-", mods = "CMD", action = act.DecreaseFontSize },
  { key = "0", mods = "CMD", action = act.ResetFontSize },
  { key = "Enter", mods = "CMD", action = act.ToggleFullScreen },

  -- iTerm2-style split shortcuts (not WezTerm defaults) for muscle memory;
  -- mirrors the LEADER | and LEADER - bindings below.
  { key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

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
  {
    key = "c",
    mods = "LEADER",
    action = act.SpawnCommandInNewTab({
      args = config.default_prog,
      cwd = wezterm.home_dir,
      domain = "CurrentPaneDomain",
      set_environment_variables = { WEZTERM_NEW_TAB = "1" },
    }),
  },
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
