return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = function()
    if vim.fn.executable("tree-sitter") == 1 then
      vim.cmd("TSUpdate")
    end
  end,
  config = function()
    local treesitter = require("nvim-treesitter")

    -- The first startup after switching branches can still load the old
    -- checkout until :Lazy sync replaces it with nvim-treesitter/main.
    if type(treesitter.setup) ~= "function" or type(treesitter.install) ~= "function" then
      vim.notify(
        "nvim-treesitter/main is not installed yet; run :Lazy sync and restart Neovim",
        vim.log.levels.WARN
      )
      return
    end

    treesitter.setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    if vim.fn.executable("tree-sitter") == 1 then
      treesitter.install({ "python" })
    else
      vim.notify(
        "tree-sitter CLI is unavailable; skipping Python parser install",
        vim.log.levels.WARN
      )
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "lua", "python", "markdown" },
      callback = function(event)
        vim.treesitter.start(event.buf)
      end,
    })
  end,
}
