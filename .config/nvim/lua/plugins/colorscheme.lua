return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "moon",
      dark_variant = "moon",
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      enable = {
        terminal = true,
        legacy_highlights = true,
        migrations = true,
      },
      styles = {
        bold = true,
        italic = true,
        transparency = true,
      },
      highlight_groups = {
        CursorLine = { bg = "highlight_low" },
        CursorLineNr = { fg = "gold", bold = true },
        LineNr = { fg = "muted" },
        WinSeparator = { fg = "highlight_med" },
        NormalFloat = { bg = "base" },
        FloatBorder = { fg = "iris", bg = "base" },
      },
    },
    config = function(_, opts)
      require("rose-pine").setup(opts)
      vim.cmd.colorscheme("rose-pine")
    end,
  },
}
