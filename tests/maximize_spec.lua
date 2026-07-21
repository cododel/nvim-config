package.preload["cododel.bindings"] = function()
  return dofile(vim.fn.getcwd() .. "/lua/cododel/bindings.lua")
end

local maximize = dofile(vim.fn.getcwd() .. "/lua/cododel/maximize.lua")
maximize.setup()

local function mapping(lhs, mode)
  for _, item in ipairs(vim.api.nvim_get_keymap(mode or "n")) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  error("mapping not found: " .. lhs)
end

local source_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, { "maximize-me", "line-two" })
local source_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(source_win, source_buf)

local toggle = mapping("<S-Esc>")
for _, mode in ipairs({ "n", "i", "t" }) do
  assert(mapping("<S-Esc>", mode) == toggle, "Shift+Esc is bound in " .. mode)
  assert(
    mapping("<Esc>[27;2u", mode) == toggle,
    "CSI-u Shift+Esc is bound in " .. mode
  )
end

local expected = maximize.geometry()
assert(expected.relative == "editor", "geometry is editor-relative")
assert(expected.row == 1, "geometry uses top margin 1")
assert(expected.col == 1, "geometry uses left margin 1")
assert(expected.width == math.max(vim.o.columns - 2, 1), "geometry width leaves 1-cell sides")
assert(
  expected.height == math.max(vim.o.lines - vim.o.cmdheight - 2, 1),
  "geometry height leaves 1-cell top/bottom"
)
assert(expected.border == "single", "geometry uses a single border")
assert(expected.style == "minimal", "geometry uses minimal style")

toggle()
local float_win = vim.api.nvim_get_current_win()
assert(float_win ~= source_win, "toggle opens a different window")
assert(vim.api.nvim_win_get_buf(float_win) == source_buf, "float shows the source buffer")

local config = vim.api.nvim_win_get_config(float_win)
assert(config.relative == "editor", "float is editor-relative")
assert(config.row == expected.row or config.row == expected.row + 0.0, "float row matches geometry")
assert(config.col == expected.col or config.col == expected.col + 0.0, "float col matches geometry")
assert(config.width == expected.width, "float width matches geometry")
assert(config.height == expected.height, "float height matches geometry")

toggle()
assert(not vim.api.nvim_win_is_valid(float_win), "second toggle closes the float")
assert(vim.api.nvim_get_current_win() == source_win, "close restores source focus")

toggle()
local second_float = vim.api.nvim_get_current_win()
assert(second_float ~= source_win, "toggle reopens after close")
assert(vim.api.nvim_win_get_buf(second_float) == source_buf, "reopened float shows source buffer")
toggle()
assert(not vim.api.nvim_win_is_valid(second_float), "final toggle closes the reopened float")
assert(vim.api.nvim_get_current_win() == source_win, "final close restores source focus")

print("maximize_spec: ok")
