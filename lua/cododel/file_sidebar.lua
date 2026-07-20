local M = {}

local function tree_window()
  local api = require("nvim-tree.api")

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if api.tree.is_tree_buf(bufnr) then
        return winid
      end
    end
  end
end

local function focus_tree()
  local api = require("nvim-tree.api")
  local winid = tree_window()

  if winid then
    vim.api.nvim_set_current_win(winid)
  else
    api.tree.open()
  end
end

local function hide_tree()
  local api = require("nvim-tree.api")
  if tree_window() then
    api.tree.close()
  end
end

local function is_open()
  return tree_window() ~= nil
end

local function is_focused()
  return tree_window() == vim.api.nvim_get_current_win()
end

M.get_winid = tree_window
M.is_open = is_open
M.is_focused = is_focused
M.focus = focus_tree
M.hide = hide_tree

return M
