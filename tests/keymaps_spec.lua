local keymaps = dofile(vim.fn.getcwd() .. "/lua/config/keymaps.lua")

local function mapping(mode, lhs)
  for _, item in ipairs(vim.api.nvim_get_keymap(mode)) do
    if item.lhs == lhs then
      return item.rhs
    end
  end

  error(string.format("mapping not found: %s in %s mode", lhs, mode))
end

for _, mode in ipairs({ "n", "x", "o" }) do
  assert(mapping(mode, "р") == "h", "Russian р follows h")
  assert(mapping(mode, "о") == "j", "Russian о follows j")
  assert(mapping(mode, "л") == "k", "Russian л follows k")
  assert(mapping(mode, "д") == "l", "Russian д follows l")
  assert(mapping(mode, "Р") == "H", "Russian Р follows H")
  assert(mapping(mode, "О") == "J", "Russian О follows J")
  assert(mapping(mode, "Л") == "K", "Russian Л follows K")
  assert(mapping(mode, "Д") == "L", "Russian Д follows L")
end

assert(vim.fn.maparg("р", "i") == "", "Russian motion keys do not affect insert mode")
assert(vim.fn.maparg("р", "t") == "", "Russian motion keys do not affect terminal mode")
assert(vim.fn.maparg("<C-ы>", "n") == vim.fn.maparg("<C-s>", "n"), "Russian Ctrl+Ы follows Ctrl+S")
assert(vim.fn.maparg("<C-л>", "n") == vim.fn.maparg("<C-k>", "n"), "Russian Ctrl+Л follows Ctrl+K")

print("keymaps_spec: ok")
