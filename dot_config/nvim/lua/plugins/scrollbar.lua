return {
  {
    "kevinhwang91/nvim-hlslens",
    lazy = false,
    opts = {},
  },

  {
    "petertriho/nvim-scrollbar",
    dependencies = {
      "kevinhwang91/nvim-hlslens",
      "lewis6991/gitsigns.nvim",
    },

    opts = {
      show = true,
      show_in_active_only = true,

      handle = {
        text = " ",
        blend = 40,
        hide_if_all_visible = true,
      },

      handlers = {
        cursor = true,
        diagnostic = true,
        gitsigns = true,
        handle = true,
        search = true,
        ale = false,
      },
    },

    config = function(_, opts)
      require("scrollbar").setup(opts)
    end,
  },
}
