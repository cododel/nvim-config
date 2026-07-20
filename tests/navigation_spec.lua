package.preload["nvim-drawer"] = function()
  return {
    find_instance_for_winid = function()
      return nil
    end,
  }
end

package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function()
        return false
      end,
    },
  }
end

local editor_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_option(editor_buf, "buftype", "")
local editor_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(editor_win, editor_buf)

local function panel()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 0,
    col = 45,
    width = 10,
    height = 5,
    style = "minimal",
  })

  return {
    win = win,
    focus = function()
      vim.api.nvim_set_current_win(win)
    end,
    hide = function()
      if vim.api.nvim_get_current_win() == win then
        vim.api.nvim_set_current_win(editor_win)
      end
    end,
    is_focused = function()
      return vim.api.nvim_get_current_win() == win
    end,
    is_open = function()
      return true
    end,
  }
end

local files = panel()
files.get_ai_cwd = function()
  return "/tmp/project/src"
end
local ai = panel()
local ai_cwd
ai.focus_with_cwd = function(cwd)
  ai_cwd = cwd
  ai.focus()
end
local bottom = panel()
local navigation = dofile(vim.fn.getcwd() .. "/lua/cododel/navigation.lua")
navigation.setup({
  file_sidebar = files,
  panels = { ai = ai, bottom = bottom },
})

local function mapping(lhs)
  for _, item in ipairs(vim.api.nvim_get_keymap("n")) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  error("mapping not found: " .. lhs)
end

local h = mapping("<D-h>")
local j = mapping("<D-j>")
local k = mapping("<D-k>")
local l = mapping("<D-l>")

local function assert_current(win, message)
  assert(vim.api.nvim_get_current_win() == win, message)
end

assert_current(editor_win, "starts in editor")

l()
assert_current(ai.win, "editor -> ai")
h()
assert_current(editor_win, "ai -> editor")

j()
local bottom_win = vim.api.nvim_get_current_win()
assert(bottom_win ~= editor_win, "editor -> bottom")
h()
assert_current(files.win, "bottom -> files")
j()
assert_current(bottom_win, "files -> bottom")
j()
assert_current(files.win, "bottom -> files source")

l()
assert_current(editor_win, "files -> editor")
l()
assert_current(ai.win, "editor -> ai again")
assert(ai_cwd == "/tmp/project/src", "files selection is passed to AI on the next focus")
j()
assert_current(bottom_win, "ai -> bottom")
j()
assert_current(ai.win, "bottom -> ai source")

l()
assert_current(editor_win, "ai -> editor after return")
k()
assert_current(editor_win, "cmd+k outside bottom is a no-op")
j()
assert_current(bottom_win, "editor -> bottom again")
k()
assert_current(editor_win, "cmd+k from bottom -> editor")

print("navigation_spec: ok")
