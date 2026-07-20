return {
  "nvim-treesitter/nvim-treesitter",
  build = ':TSUpdate',
  config = function()
    require 'nvim-treesitter.configs'.setup {
      ensure_installed = { "python" }, -- добавь другие языки, если нужно
      highlight = {
        enable = true,                 -- Включить подсветку синтаксиса
      },
    }
  end
}
