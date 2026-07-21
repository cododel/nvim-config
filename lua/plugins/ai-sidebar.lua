local options = require("cododel.options")
local ai = options.ai()

require("cododel.deps").need({
  bin = options.ai_bin(),
  level = "error",
  feature = "AI sidebar (" .. ai.name .. ")",
  install = ai.install,
})

return {
  {
    "mikew/nvim-drawer",
    commit = "68421b02e8c1f6ab27dddf41a8642327a80b6747",
    lazy = false,
    config = function()
      local opts = require("cododel.options").get()
      require("cododel.ai_sidebar").setup({
        agent_cmd = vim.deepcopy(opts.ai.cmd),
        agent_name = opts.ai.name,
        sidebar_width = opts.sidebar_width,
        terminal_height = opts.terminal_height,
      })
    end,
  },
}
