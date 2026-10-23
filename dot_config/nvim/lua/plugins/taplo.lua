return {
  {
    "neovim/nvim-lspconfig",
    dependencies = { "b0o/SchemaStore.nvim" },
    opts = function(_, opts)
      -- Taplo 0.10 requires SchemaStore's old catalog identifier.
      -- Reuse the installed catalog so it follows SchemaStore.nvim updates.
      local path = vim.fn.stdpath("cache") .. "/taplo-schemastore.json"
      local catalog = vim.json.encode({
        ["$schema"] = "https://json.schemastore.org/schema-catalog.json",
        schemas = require("schemastore").json.schemas(),
      })
      vim.fn.mkdir(vim.fn.stdpath("cache"), "p")
      if vim.fn.filereadable(path) == 0 or vim.fn.readfile(path)[1] ~= catalog then
        vim.fn.writefile({ catalog }, path)
      end
      opts.servers.taplo = vim.tbl_deep_extend("force", opts.servers.taplo or {}, {
        settings = {
          evenBetterToml = {
            schema = { catalogs = { vim.uri_from_fname(path) } },
          },
        },
      })
    end,
  },
}
