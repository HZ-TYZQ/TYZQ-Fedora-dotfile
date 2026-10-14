return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local python = vim.fn.stdpath("data")
        .. "/mason/packages/debugpy/venv/bin/python"

      if vim.fn.filereadable(python) ~= 1 then
        vim.notify(
          "Mason debugpy Python not found: " .. python,
          vim.log.levels.ERROR
        )
        return
      end

      require("dap-python").setup(python)
    end,
  },
}