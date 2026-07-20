return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    plugins = {
      registers = false,
      spelling = {
        enabled = false,
      },
      presets = {
        windows = false,
        nav = false,
      }
    }
  },
}
