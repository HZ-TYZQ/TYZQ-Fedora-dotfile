return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("user_terminal_statusline", { clear = true }),
        callback = function()
          vim.api.nvim_set_hl(0, "StatusLine", { fg = "NONE", bg = "NONE" })
          vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "NONE", bg = "NONE" })
        end,
      })

      vim.api.nvim_set_hl(0, "StatusLine", { fg = "NONE", bg = "NONE" })
      vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "NONE", bg = "NONE" })
    end,
  },
}