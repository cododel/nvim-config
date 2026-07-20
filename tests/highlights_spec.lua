local groups = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "EndOfBuffer",
  "SignColumn",
}

local function assert_transparent(group)
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  assert(highlight.bg == nil, group .. " has no background")
end

dofile(vim.fn.getcwd() .. "/lua/config/highlights.lua")

for _, group in ipairs(groups) do
  assert_transparent(group)
end

vim.api.nvim_set_hl(0, "Normal", { bg = "#111111" })
vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "default" })
assert_transparent("Normal")

print("highlights_spec: ok")
