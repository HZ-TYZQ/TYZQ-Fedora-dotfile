return {
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      keymap = {
        preset = "super-tab",

        -- Enter 始终保持正常换行
        ["<CR>"] = { "fallback" },
      },
    },
  },
}