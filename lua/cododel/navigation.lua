local M = {}

local state = {
  initialized = false,
  last_editor_win = nil,
  file_sidebar = nil,
  panels = nil,
}

local function is_drawer_window(winid)
  local ok, drawer = pcall(require, "nvim-drawer")
  if not ok or not drawer.find_instance_for_winid then
    return false
  end

  return drawer.find_instance_for_winid(winid) ~= nil
end

local function is_tree_buffer(bufnr)
  local ok, tree_api = pcall(require, "nvim-tree.api")
  return ok and tree_api.tree.is_tree_buf(bufnr)
end

local function is_editor_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local win_config = vim.api.nvim_win_get_config(winid)

  return win_config.relative == ""
    and not is_tree_buffer(bufnr)
    and not is_drawer_window(winid)
    and vim.bo[bufnr].buftype == ""
end

local function remember_editor_window()
  local winid = vim.api.nvim_get_current_win()
  if is_editor_window(winid) then
    state.last_editor_win = winid
  end
end

local function find_editor_window()
  if state.last_editor_win and is_editor_window(state.last_editor_win) then
    return state.last_editor_win
  end

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor_window(winid) then
      state.last_editor_win = winid
      return winid
    end
  end
end

local function focus_editor()
  local target = find_editor_window()
  if target then
    vim.api.nvim_set_current_win(target)
    return true
  end

  -- There may be no editor pane after the last file window was closed.
  -- The file sidebar is the stable navigation target in that state.
  if state.file_sidebar then
    state.file_sidebar.focus_or_open()
  end

  return false
end

local function current_zone()
  local current_win = vim.api.nvim_get_current_win()
  local panels = state.panels

  if panels.ai.is_focused() then
    return "ai"
  end

  if panels.bottom.is_focused() then
    return "bottom"
  end

  if state.file_sidebar.is_focused() then
    return "files"
  end

  if is_editor_window(current_win) then
    remember_editor_window()
    return "editor"
  end
end

local function focus_or_open(panel)
  panel.focus_or_open()
end

local function hide_then_focus_editor(panel)
  panel.hide()
  focus_editor()
end

local function move_left()
  local zone = current_zone()

  if zone == "editor" then
    focus_or_open(state.file_sidebar)
  elseif zone == "files" then
    hide_then_focus_editor(state.file_sidebar)
  elseif zone == "ai" then
    focus_editor()
  end
end

local function move_right()
  local zone = current_zone()

  if zone == "editor" then
    focus_or_open(state.panels.ai)
  elseif zone == "files" then
    focus_editor()
  elseif zone == "ai" then
    hide_then_focus_editor(state.panels.ai)
  end
end

local function move_down()
  local zone = current_zone()

  if zone == "editor" then
    focus_or_open(state.panels.bottom)
  elseif zone == "bottom" then
    hide_then_focus_editor(state.panels.bottom)
  end
end

local function move_up()
  if current_zone() == "bottom" then
    focus_editor()
  end
end

local function create_mappings()
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
  }

  local mappings = {
    { "h", "<D-h>", "<Esc>[102~", move_left },
    { "j", "<D-j>", "<Esc>[98~", move_down },
    { "k", "<D-k>", "<Esc>[101~", move_up },
    { "l", "<D-l>", "<Esc>[99~", move_right },
  }

  for _, mapping in ipairs(mappings) do
    vim.keymap.set({ "n", "i", "t" }, mapping[2], mapping[4], opts)
    vim.keymap.set({ "n", "i", "t" }, mapping[3], mapping[4], opts)
  end
end

function M.setup(options)
  if state.initialized then
    return
  end

  state.file_sidebar = assert(options.file_sidebar, "file sidebar is required")
  state.panels = assert(options.panels, "navigation panels are required")
  state.initialized = true

  create_mappings()
end

return M
