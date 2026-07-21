local bindings = dofile(vim.fn.getcwd() .. "/lua/cododel/bindings.lua")

assert(bindings.layout.russian_to_latin["р"] == "h", "mac Russian р follows h")
assert(bindings.layout.russian_to_latin["д"] == "l", "mac Russian д follows l")
assert(bindings.layout.russian_to_latin["Ю"] == ">", "mac Russian Ю follows >")
assert(bindings.layout.russian_to_latin["ъ"] == "]", "mac Russian ъ follows ]")

bindings.setup()
bindings.setup()

local function mapping(mode, lhs)
  for _, item in ipairs(vim.api.nvim_get_keymap(mode)) do
    if item.lhs == lhs then
      return item
    end
  end
end

for _, mode in ipairs({ "n", "x", "s", "o" }) do
  local russian = mapping(mode, "р")
  assert(russian and russian.rhs == "h", "Russian commands are available in " .. mode)
  assert(russian.noremap == 0, "Russian command mapping remains recursive in " .. mode)
end

assert(vim.fn.maparg("р", "i") == "", "Russian commands do not affect Insert mode")
assert(vim.fn.maparg("р", "t") == "", "Russian commands do not affect Terminal mode")
assert(vim.fn.maparg("ив", "c", false, true).expr == 1, "Russian Ex aliases are expression mappings")

local aliases = bindings.aliases({
  latin = { "<D-p>", "<D-p>" },
  russian = "<D-з>",
  terminal = "<Esc>[112~",
})
assert(#aliases == 3, "binding aliases are deduplicated")
assert(bindings.shortcuts.file_palette.russian == "<D-з>", "file palette has a Russian alias")

local maximize_aliases = bindings.aliases(bindings.shortcuts.maximize_pane)
assert(#maximize_aliases == 2, "maximize pane exposes latin and terminal aliases")
assert(maximize_aliases[1] == "<S-Esc>", "maximize pane latin alias is Shift+Esc")
assert(maximize_aliases[2] == "<Esc>[27;2u", "maximize pane terminal alias is CSI-u Shift+Esc")

print("bindings_spec: ok")
