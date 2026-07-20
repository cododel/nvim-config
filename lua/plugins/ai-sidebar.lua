return {
  {
    "mikew/nvim-drawer",
    commit = "68421b02e8c1f6ab27dddf41a8642327a80b6747",
    lazy = false,
    config = function()
      require("cododel.ai_sidebar").setup({
        codex_cmd = { "codex" },
        sidebar_width = 42,
        terminal_height = 12,
      })
    end,
  },
}
