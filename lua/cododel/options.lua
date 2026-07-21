-- Central Cododel options. Override early (before config.lazy), e.g. in
-- config/settings.lua:
--
--   require("cododel.options").setup({
--     ai = {
--       name = "Claude",
--       cmd = { "claude" },
--       install = "npm i -g @anthropic-ai/claude-code",
--     },
--   })
--
-- Examples for ai.cmd:
--   { "codex" }
--   { "claude" }
--   { "opencode" }
--   { "cursor-agent" }
--   { "grok" }
--   { "zi" }

local M = {}

local defaults = {
  ai = {
    -- Label in winbar, default session titles, deps feature name.
    name = "Codex",
    -- argv passed to termopen for each AI chat session.
    cmd = { "codex" },
    -- Shown by cododel.deps when the binary is missing (required for deps.need).
    install = "install Codex CLI (https://github.com/openai/codex) and ensure it is in PATH",
  },
  sidebar_width = 42,
  terminal_height = 12,
}

local current = vim.deepcopy(defaults)

local function normalize(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  if type(opts.ai.cmd) == "string" then
    opts.ai.cmd = { opts.ai.cmd }
  end

  if type(opts.ai.cmd) ~= "table" or type(opts.ai.cmd[1]) ~= "string" or opts.ai.cmd[1] == "" then
    error("cododel.options: ai.cmd must be a non-empty string or argv list")
  end

  if type(opts.ai.name) ~= "string" or vim.trim(opts.ai.name) == "" then
    error("cododel.options: ai.name must be a non-empty string")
  end

  if type(opts.ai.install) ~= "string" or vim.trim(opts.ai.install) == "" then
    error("cododel.options: ai.install must be a non-empty install instruction")
  end

  opts.ai.name = vim.trim(opts.ai.name)
  opts.ai.install = vim.trim(opts.ai.install)

  return opts
end

function M.setup(opts)
  current = normalize(opts)
  return current
end

function M.get()
  return current
end

function M.ai()
  return current.ai
end

--- First argv element — binary checked by cododel.deps.
function M.ai_bin()
  return current.ai.cmd[1]
end

function M.defaults()
  return vim.deepcopy(defaults)
end

return M
