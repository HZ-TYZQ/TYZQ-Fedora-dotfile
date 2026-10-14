return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = false,
        virtual_lines = false,
        underline = true,
        signs = true,
        severity_sort = true,
        update_in_insert = false,
      },
    },
  },

  {
    "folke/trouble.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        diagnostics = {
          auto_open = true,
          auto_close = true,
          focus = false,
          win = {
            position = "bottom",
          },
        },
      },
    },
  },
}