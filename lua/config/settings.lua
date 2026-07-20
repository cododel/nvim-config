local cmd = vim.cmd            -- execute Vim commands
local exec = vim.api.nvim_exec -- execute Vimscript
local g = vim.g                -- global variables
local opt = vim.opt            -- global/buffer/windows-scoped options

cmd('set nobackup')
cmd('set nowritebackup')


opt.termguicolors = true
opt.swapfile = false
opt.number = true
opt.relativenumber = true

-- Tabs
opt.tabstop = 2
opt.shiftwidth = 2
cmd('au FileType py set tabstop=4')
cmd('au FileType py set shiftwidth=4')
opt.expandtab = true


-- Compact mode for tag bar
g.tagbar_compact = 1
g.tagbar_sort = 0
