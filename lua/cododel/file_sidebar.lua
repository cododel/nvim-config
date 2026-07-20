local M = {}

local state = {
  initialized = false,
  last_editor_win = nil,
}

local function is_drawer_window(winid)
  local ok, drawer = pcall(require, "nvim-drawer")
  if not ok or not drawer.find_instance_for_winid then
    return false
  end

  return drawer.find_instance_for_winid(winid) ~= nil
end

local function is_editor_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local api = require("nvim-tree.api")
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local win_config = vim.api.nvim_win_get_config(winid)

  return win_config.relative == ""
    and not api.tree.is_tree_buf(bufnr)
    and not is_drawer_window(winid)
    and vim.bo[bufnr].buftype == ""
end

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

local function remember_editor_window()
  local winid = vim.api.nvim_get_current_win()
  if is_editor_window(winid) then
    state.last_editor_win = winid
  end
end

local function focus_editor_window()
  local target = state.last_editor_win
  if not target or not is_editor_window(target) then
    target = nil
    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if is_editor_window(winid) then
        target = winid
        break
      end
    end
  end

  if target then
    vim.api.nvim_set_current_win(target)
  end
end

local function open_tree()
  remember_editor_window()
  require("nvim-tree.api").tree.open()
end

local function focus_or_leave_tree()
  local api = require("nvim-tree.api")
  local winid = tree_window()

  if not winid then
    open_tree()
  elseif vim.api.nvim_get_current_win() == winid then
    focus_editor_window()
  else
    api.tree.open()
  end
end

local function open_or_hide_tree()
  local api = require("nvim-tree.api")
  local winid = tree_window()

  if not winid then
    open_tree()
  elseif vim.api.nvim_get_current_win() == winid then
    api.tree.close()
  else
    api.tree.open()
  end
end

M.focus_or_leave_tree = focus_or_leave_tree
M.open_or_hide_tree = open_or_hide_tree

function M.setup()
  if state.initialized then
    return
  end

  state.initialized = true

  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
  }

  vim.keymap.set({ "n", "i", "t" }, "<D-b>", M.focus_or_leave_tree, opts)
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[103~", M.focus_or_leave_tree, opts)
  vim.keymap.set({ "n", "i", "t" }, "<D-S-b>", M.open_or_hide_tree, opts)
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[104~", M.open_or_hide_tree, opts)
end

return M
