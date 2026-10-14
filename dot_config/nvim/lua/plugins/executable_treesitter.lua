return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      highlight = { enable = true },
      indent = { enable = true },
      folds = { enable = true },
      ensure_installed = {
        "cpp",
        "css",
        "scss",
        "powershell",
        "go",
        "rust",
        "java",
        "c_sharp",
        "cmake",
        "make",
        "gitignore",
        "git_config",
        "dockerfile",
      },
    },
  },
}