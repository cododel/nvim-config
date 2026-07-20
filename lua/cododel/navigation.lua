local M = {}

local state = {
  initialized = false,
  last_editor_win = {},
  file_sidebar = nil,
  panels = nil,
  bottom_return_zone = "editor",
  pending_ai_cwd = nil,
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

local function current_tabpage()
  return vim.api.nvim_get_current_tabpage()
end

local function remember_editor_window()
  local winid = vim.api.nvim_get_current_win()
  if is_editor_window(winid) then
    state.last_editor_win[current_tabpage()] = winid
  end
end

local function find_editor_window()
  local tabpage = current_tabpage()
  local last_win = state.last_editor_win[tabpage]

  if last_win and is_editor_window(last_win) then
    return last_win
  end

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if is_editor_window(winid) then
      state.last_editor_win[tabpage] = winid
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
    state.file_sidebar.focus()
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

local function panel_for_zone(zone)
  if zone == "files" then
    return state.file_sidebar
  end

  return state.panels[zone]
end

local function focus_zone(zone, options)
  if zone == "editor" then
    focus_editor()
    return
  end

  local panel = panel_for_zone(zone)
  if panel then
    if zone == "ai" and panel.focus_with_cwd then
      panel.focus_with_cwd(options and options.cwd)
    else
      panel.focus()
    end
  end
end

local horizontal_targets = {
  left = {
    editor = "files",
    files = "editor",
    bottom = "files",
    ai = "editor",
  },
  right = {
    editor = "ai",
    files = "editor",
    bottom = "ai",
    ai = "editor",
  },
}

local hide_on_horizontal_move = {
  left = { files = true },
  right = { ai = true },
}

local function move_horizontal(direction)
  local zone = current_zone()
  local target = zone and horizontal_targets[direction][zone]
  if not target then
    return
  end

  if zone == "files" and state.file_sidebar.get_ai_cwd then
    state.pending_ai_cwd = state.file_sidebar.get_ai_cwd()
  end

  if hide_on_horizontal_move[direction][zone] then
    panel_for_zone(zone).hide()
  end

  local options
  if target == "ai" then
    options = { cwd = state.pending_ai_cwd }
    state.pending_ai_cwd = nil
  end

  focus_zone(target, options)
end

local function move_left()
  move_horizontal("left")
end

local function move_right()
  move_horizontal("right")
end

local function move_down()
  local zone = current_zone()

  if zone == "bottom" then
    state.panels.bottom.hide()
    focus_zone(state.bottom_return_zone)
  elseif zone then
    state.bottom_return_zone = zone
    if zone == "files" and state.file_sidebar.get_ai_cwd then
      state.pending_ai_cwd = state.file_sidebar.get_ai_cwd()
    end
    state.panels.bottom.focus()
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
    { "<D-h>", "<Esc>[102~", move_left },
    { "<D-j>", "<Esc>[98~", move_down },
    { "<D-k>", "<Esc>[101~", move_up },
    { "<D-l>", "<Esc>[99~", move_right },
  }

  for _, mapping in ipairs(mappings) do
    vim.keymap.set({ "n", "i", "t" }, mapping[1], mapping[3], opts)
    vim.keymap.set({ "n", "i", "t" }, mapping[2], mapping[3], opts)
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

M.toggle_bottom = move_down

return M
