return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            win = {
              list = {
                keys = {
                  ["<Right>"] = "confirm",
                  ["<Left>"] = "explorer_close",
                },
              },
            },
          },
        },
      },
    },
  },
}