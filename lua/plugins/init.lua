return {
  { "kylechui/nvim-surround",  version = "*", event = "VeryLazy", config = true },
  { "akinsho/bufferline.nvim", config = true },
  "nvim-telescope/telescope.nvim",
  "mbbill/undotree",
  {
    "kyazdani42/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
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
  "nvim-treesitter/nvim-treesitter",
  "powerman/vim-plugin-ruscmd",
  "sindrets/winshift.nvim",
  "tpope/vim-repeat",
  "goolord/alpha-nvim",
  { 'windwp/nvim-autopairs',   event = "InsertEnter", config = true },
  { "windwp/nvim-ts-autotag", config = true },
}
