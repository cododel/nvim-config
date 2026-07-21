local deps = require("cododel.deps")

-- server id → PATH binary (nvim-lspconfig does not install these)
local lsp_bins = {
  {
    id = "emmet_ls",
    bin = "emmet-ls",
    feature = "LSP Emmet",
    install = "npm i -g emmet-ls",
  },
  {
    id = "eslint",
    bin = "vscode-eslint-language-server",
    feature = "LSP ESLint",
    install = "npm i -g vscode-langservers-extracted",
  },
  {
    id = "ts_ls",
    bin = "typescript-language-server",
    feature = "LSP TypeScript",
    install = "npm i -g typescript typescript-language-server",
  },
  {
    id = "jsonls",
    bin = "vscode-json-language-server",
    feature = "LSP JSON",
    install = "npm i -g vscode-langservers-extracted",
  },
  {
    id = "lua_ls",
    bin = "lua-language-server",
    feature = "LSP Lua",
    install = "brew install lua-language-server",
  },
  {
    id = "phpactor",
    bin = "phpactor",
    feature = "LSP PHP",
    install = "composer global require phpactor/phpactor  # ensure ~/.composer/vendor/bin in PATH",
  },
  {
    id = "ruff",
    bin = "ruff",
    feature = "LSP Ruff",
    install = "brew install ruff",
  },
  {
    id = "basedpyright",
    bin = "basedpyright-langserver",
    feature = "LSP Python (basedpyright)",
    install = "brew install basedpyright",
  },
}

for _, item in ipairs(lsp_bins) do
  deps.need({
    id = item.id,
    bin = item.bin,
    level = "warn",
    feature = item.feature,
    install = item.install,
  })
end

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
