return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- Список серверов для стандартной настройки
    local servers = {
      "emmet_ls",
      "eslint",
      "ts_ls",
      "svelte",
      "jsonls",
      "lua_ls",
      "phpactor",
      "ruff",
    }

    for _, server in ipairs(servers) do
      vim.lsp.config(server, { capabilities = capabilities })
      vim.lsp.enable(server)
    end

    -- Python (специфичная настройка)
    vim.lsp.config("basedpyright", {
      capabilities = capabilities,
      settings = {
        basedpyright = {
          analysis = {
            autoSearchPaths = true,
            diagnosticMode = "openFilesOnly",
            useLibraryCodeForTypes = true,
          },
        },
      },
    })
    vim.lsp.enable("basedpyright")
  end
}
