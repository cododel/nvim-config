local options = dofile(vim.fn.getcwd() .. "/lua/cododel/options.lua")

local defaults = options.get()
assert(defaults.ai.name == "Codex", "default AI name is Codex")
assert(defaults.ai.cmd[1] == "codex", "default AI cmd is codex")
assert(options.ai_bin() == "codex", "ai_bin is first argv")
assert(type(defaults.ai.install) == "string" and defaults.ai.install ~= "", "default install set")

options.setup({
  ai = {
    name = "Claude",
    cmd = { "claude", "--dangerously-skip-permissions" },
    install = "npm i -g @anthropic-ai/claude-code",
  },
})

assert(options.ai().name == "Claude", "name override")
assert(options.ai_bin() == "claude", "bin from cmd[1]")
assert(#options.ai().cmd == 2, "cmd keeps extra args")
assert(options.ai().install:find("claude-code", 1, true), "install override")

options.setup({
  ai = {
    name = "Grok",
    cmd = "grok",
    install = "install grok CLI",
  },
})
assert(type(options.ai().cmd) == "table", "string cmd normalized to list")
assert(options.ai().cmd[1] == "grok", "string cmd becomes { grok }")

local ok_empty, err = pcall(function()
  options.setup({
    ai = {
      name = "X",
      cmd = { "x" },
      install = "",
    },
  })
end)
assert(not ok_empty, "empty install rejected")
assert(tostring(err):find("install", 1, true), "error mentions install")

-- restore defaults for any subsequent dofile consumers in same process
options.setup(options.defaults())

print("options_spec: ok")
