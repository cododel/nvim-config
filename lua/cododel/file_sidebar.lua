local M = {}

local function mapping_options(bufnr, description)
  return {
    buffer = bufnr,
    desc = "file sidebar: " .. description,
    noremap = true,
    silent = true,
    nowait = true,
  }
end

local function expand_directory()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()

  if node and node.nodes then
    api.node.open.edit(node)
  end
end

local function open_selected()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()

  if not node then
    return
  end

  if node.type == "directory" or node.nodes ~= nil then
    api.tree.change_root_to_node(node)
  else
    api.node.open.edit(node)
  end
end

local function get_ai_cwd()
  local api = require("nvim-tree.api")
  local node = api.tree.get_node_under_cursor()

  if not node or not node.absolute_path then
    return nil
  end

  if node.type == "directory" or node.nodes ~= nil then
    return node.absolute_path
  end

  return vim.fn.fnamemodify(node.absolute_path, ":h")
end

function M.on_attach(bufnr)
  local api = require("nvim-tree.api")

  vim.keymap.set("n", "h", api.node.navigate.parent_close, mapping_options(bufnr, "Collapse"))
  vim.keymap.set("n", "l", expand_directory, mapping_options(bufnr, "Expand directory"))
  vim.keymap.set(
    "n",
    "<CR>",
    open_selected,
    mapping_options(bufnr, "Open file or enter directory")
  )
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
M.get_ai_cwd = get_ai_cwd
M.focus = focus_tree
M.hide = hide_tree

return M
