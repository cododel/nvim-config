local map = vim.api.nvim_set_keymap
local default_opts = { noremap = true, silent = true }
local cmd = vim.cmd -- execute Vim commands

-- Shortcut jj for Esq
map("i", "jj", "<Esc>", { noremap = true })

-- Force : on semicolon in normal mode
map("n", ";", ":", { noremap = true })

-- Working with "+" clipboard
map("v", "<S-Y>", '"+y', {})
map("n", "<S-P>", '"+p', {})

-- Автоформат + сохранение по CTRL-s , как в нормальном, так и в insert режиме
local conform = "lua require('conform').format({async=false, lsp_fallback=true})"
local lsp_buf = "<Cmd>lua vim.lsp.buf"
map("n", "<C-s>", "<Cmd>" .. conform .. "<CR>:w<CR>", default_opts)
map("i", "<C-s>", "<Esc><Cmd>" .. conform .. "<CR>:w<CR>", default_opts)
map("n", "<F2>", lsp_buf .. ".rename()<CR>", default_opts)

map('n', 'gd', lsp_buf .. ".definition()<CR>", default_opts)
map('n', 'gr', lsp_buf .. ".references()<CR>", default_opts)
map('n', 'gD', lsp_buf .. ".declaration()<CR>", default_opts)
map('n', 'K', lsp_buf .. ".hover()<CR>", default_opts)
map('n', '<C-k>', lsp_buf .. ".signature_help()<CR>", default_opts)

-- Bufferline
map("n", "<Leader>1", "<Cmd>BufferLineGoToBuffer 1<CR>", default_opts)
map("n", "<Leader>2", "<Cmd>BufferLineGoToBuffer 2<CR>", default_opts)
map("n", "<Leader>3", "<Cmd>BufferLineGoToBuffer 3<CR>", default_opts)
map("n", "<Leader>4", "<Cmd>BufferLineGoToBuffer 4<CR>", default_opts)
map("n", "<Leader>5", "<Cmd>BufferLineGoToBuffer 5<CR>", default_opts)
map("n", "<Leader>6", "<Cmd>BufferLineGoToBuffer 6<CR>", default_opts)
map("n", "<Leader>7", "<Cmd>BufferLineGoToBuffer 7<CR>", default_opts)
map("n", "<Leader>8", "<Cmd>BufferLineGoToBuffer 8<CR>", default_opts)
map("n", "<Leader>9", "<Cmd>BufferLineGoToBuffer 9<CR>", default_opts)
map("n", "<Leader>$", "<Cmd>BufferLineGoToBuffer -1<CR>", default_opts)
map("n", "H", "<Cmd>BufferLineCyclePrev<CR>", default_opts)
map("n", "L", "<Cmd>BufferLineCycleNext<CR>", default_opts)

-- By F1 clear the last search with highlighting
map("n", "<F1>", ":nohl<CR>", default_opts)
-- Shift + F1 = remove empty lines
map("n", "<F13>", ":g/^$/d<CR>", default_opts)

-- <F5> Side numbers mode toggle
map("n", "<F5>", ':exec &nu==&rnu? "se nu!" : "se rnu!"<CR>', default_opts)

-- <F6> files tree
map("n", "<C-b>", ":NvimTreeRefresh<CR>:NvimTreeToggle<CR>", default_opts)
