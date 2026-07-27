local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Kun-style hybrid line numbers:
-- current line = absolute number; surrounding lines = relative distance.
opt.number = true
opt.relativenumber = true

opt.mouse = "a"
opt.clipboard = "unnamedplus"

-- Fall back to OSC 52 (terminal-forwarded clipboard) when no native
-- clipboard tool is on PATH: this covers WSL without win32yank, and native
-- Windows without win32yank. WezTerm supports OSC 52 on every platform, so
-- copy/paste keeps working without extra tooling.
do
  local has_native_clipboard = false
  for _, tool in ipairs({ "pbcopy", "wl-copy", "xclip", "xsel", "win32yank.exe" }) do
    if vim.fn.executable(tool) == 1 then
      has_native_clipboard = true
      break
    end
  end

  if not has_native_clipboard then
    local osc52 = require("vim.ui.clipboard.osc52")
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end

opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.completeopt = { "menu", "menuone", "noselect" }
opt.termguicolors = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.cursorline = true
opt.splitright = true
opt.splitbelow = true
opt.confirm = true

opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}

opt.fillchars = {
  eob = " ",
  fold = " ",
  foldopen = "",
  foldclose = "",
  foldsep = " ",
  diff = "╱",
}

opt.winborder = "rounded"
opt.laststatus = 3
opt.showmode = false
