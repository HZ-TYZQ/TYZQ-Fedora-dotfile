return {
  -- 沿用 LazyVim 的 Markdown extra，只覆盖需要调整的选项。
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      render_modes = { "n", "c" }, -- 插入、选择文本时显示源码
      heading = {
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        width = "block",
        right_pad = 2,
      },
      code = { width = "block", left_pad = 1, right_pad = 1 },
      checkbox = { enabled = true },
    },
  },
  {
    "iamcco/markdown-preview.nvim",
    init = function()
      -- 在多个 Markdown 文件之间共用预览页，切换缓冲区时不关闭。
      vim.g.mkdp_auto_close = 0
      vim.g.mkdp_combine_preview = 1
      vim.g.mkdp_combine_preview_auto_refresh = 1
      vim.g.mkdp_echo_preview_url = 1
      vim.g.mkdp_page_title = "${name} · Markdown"
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "prettier" } },
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- 保留目录标记触发的自动更新；不再运行已关闭诊断的 markdownlint。
      opts.formatters_by_ft.markdown = { "prettier", "markdown-toc" }
      opts.formatters_by_ft["markdown.mdx"] = { "prettier", "markdown-toc" }
    end,
  },
  -- 关闭 lang.markdown extra 自带的 markdownlint 诊断（Markdown 里红色波浪线的来源）
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft.markdown = {}
      opts.linters_by_ft["markdown.mdx"] = {}
    end,
  },
}
