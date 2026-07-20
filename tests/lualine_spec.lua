local config = dofile(vim.fn.getcwd() .. "/lua/plugins/lualine.lua")
local options = config.opts.options
local filename = config.opts.sections.lualine_c[1]
local lsp = config.opts.sections.lualine_x[1]

assert(options.globalstatus == true, "uses one statusline for the whole workspace")
assert(type(filename.cond) == "function", "filename is conditional")
assert(type(lsp.cond) == "function", "LSP status is conditional")

vim.bo.filetype = "lua"
assert(filename.cond(), "shows editor filename")
assert(lsp.cond(), "shows editor LSP status")

for _, filetype in ipairs({ "codex_terminal", "project_terminal", "NvimTree" }) do
  vim.bo.filetype = filetype
  assert(not filename.cond(), "hides filename in " .. filetype)
  assert(not lsp.cond(), "hides LSP status in " .. filetype)
end

print("lualine_spec: ok")
