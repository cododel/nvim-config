return {
  "hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
  dependencies = {
    "neovim/nvim-lspconfig"
  },
  config = function()
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    local configs = require('lspconfig.configs')

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

    for _, lsp in ipairs(servers) do
      if configs[lsp] then
        configs[lsp].setup({ capabilities = capabilities })
      end
    end

    -- Python (специфичная настройка)
    if configs.basedpyright then
      configs.basedpyright.setup({
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              useLibraryCodeForTypes = true,
            }
          }
        }
      })
    end

    return true
  end
}
