local group = vim.api.nvim_create_augroup("user_config", { clear = true })

-- Highlight copied text.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Keep relative numbers while editing, but show normal numbers when unfocused.
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  group = group,
  callback = function()
    vim.opt_local.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  group = group,
  callback = function()
    if vim.wo.number then
      vim.opt_local.relativenumber = true
    end
  end,
})

-- Return to the last cursor position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(event.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain utility windows with q.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "help", "qf", "checkhealth", "man", "notify" },
  callback = function(event)
    vim.keymap.set("n", "q", "<cmd>close<CR>", {
      buffer = event.buf,
      silent = true,
    })
  end,
})
