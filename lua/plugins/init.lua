return {
  { "kylechui/nvim-surround",  version = "*", event = "VeryLazy", config = true },
  { "akinsho/bufferline.nvim", config = true },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- palette registers `rg` at module load; require early so deps.run sees it
    init = function()
      require("cododel.palette")
    end,
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "center",
          layout_config = {
            width = 0.82,
            height = 0.72,
          },
          sorting_strategy = "ascending",
        },
      })
      require("cododel.palette").setup()
    end,
  },
  "mbbill/undotree",
  {
    "kyazdani42/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local api = require("nvim-tree.api")
      local bindings = require("cododel.bindings")
      local file_sidebar = require("cododel.file_sidebar")

      require("nvim-tree").setup({
        on_attach = function(bufnr)
          api.config.mappings.default_on_attach(bufnr)
          file_sidebar.on_attach(bufnr)
          bindings.set("n", bindings.shortcuts.tree_hidden, api.tree.toggle_hidden_filter, {
            buffer = bufnr,
            desc = "nvim-tree: Toggle Filter: Dotfiles",
            noremap = true,
            silent = true,
            nowait = true,
          })
        end,
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
        filters = {
          custom = { "^\\.git$" },
        },
        renderer = {
          highlight_git = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
      })
    end,
  },
  "nvim-tree/nvim-web-devicons",
  "folke/trouble.nvim",
  "sindrets/winshift.nvim",
  "tpope/vim-repeat",
  "goolord/alpha-nvim",
  { 'windwp/nvim-autopairs',   event = "InsertEnter", config = true },
  { "windwp/nvim-ts-autotag", config = true },
}
