local cmd = vim.cmd            -- execute Vim commands
local exec = vim.api.nvim_exec -- execute Vimscript
local g = vim.g                -- global variables
local opt = vim.opt            -- global/buffer/windows-scoped options

-- AI sidebar agent (codex / claude / opencode / cursor / grok / …).
-- Override here — single source of truth for cmd, deps check, and UI label.
-- require("cododel.options").setup({
--   ai = {
--     name = "Claude",
--     cmd = { "claude" },
--     install = "npm i -g @anthropic-ai/claude-code",
--   },
-- })

cmd('set nobackup')
cmd('set nowritebackup')


opt.termguicolors = true
opt.swapfile = false
opt.number = true
opt.relativenumber = true
opt.mousescroll = "ver:3,hor:0"

-- Tabs
opt.tabstop = 2
opt.shiftwidth = 2
cmd('au FileType python set tabstop=4')
cmd('au FileType python set shiftwidth=4')
opt.expandtab = true


-- Compact mode for tag bar
g.tagbar_compact = 1
g.tagbar_sort = 0
