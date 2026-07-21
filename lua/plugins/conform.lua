local deps = require("cododel.deps")
deps.need({
  bin = "stylua",
  level = "warn",
  feature = "Format Lua",
  install = "brew install stylua",
})
deps.need({
  bin = "ruff",
  level = "warn",
  feature = "Format/lint Python",
  install = "brew install ruff",
})
deps.need({
  bin = "prettier",
  level = "warn",
  feature = "Format web/docs",
  install = "brew install prettier  # or: npm i -g prettier",
})

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      python = { "ruff_format", "ruff_fix" },
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      css = { "prettier" },
      html = { "prettier" },
      json = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
    },
    -- Если нужно форматирование при сохранении:
    -- format_on_save = { timeout_ms = 500, lsp_fallback = true },
  },
}
