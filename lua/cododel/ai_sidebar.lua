local M = {}

local DEFAULTS = {
  codex_cmd = { "codex" },
  sidebar_width = 42,
  terminal_height = 12,
}

local runtime = {
  initialized = false,
  options = nil,
  root = nil,
  known_roots = {},
  pending_session_name = nil,
  next_session_number = 1,
  ai = {
    active = 1,
    sessions = {},
  },
  bottom = {
    bufnr = nil,
    job_id = nil,
    status = "stopped",
    cwd = nil,
  },
  last_editor_win = nil,
  ai_drawer = nil,
  bottom_drawer = nil,
}

M._state = runtime

local function project_root()
  local root = vim.fs.root(0, { ".git" })
  return root or vim.uv.cwd()
end

local function remember_root(root)
  runtime.known_roots[root] = true
end

local function state_directory()
  return vim.fs.normalize(vim.fn.stdpath("state") .. "/codex-sidebar")
end

local function state_path(root)
  return state_directory() .. "/" .. vim.fn.sha256(root) .. ".json"
end

local function json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end

  return vim.fn.json_encode(value)
end

local function save_state(root)
  local sessions = {}
  local active_id = nil

  for index, session in ipairs(runtime.ai.sessions) do
    if session.cwd == root then
      sessions[#sessions + 1] = {
        id = session.id,
        title = session.title,
        status = session.status,
        cwd = session.cwd,
      }

      if index == runtime.ai.active then
        active_id = session.id
      end
    end
  end

  local payload = {
    version = 1,
    root = root,
    ai = {
      active_id = active_id,
      sessions = sessions,
    },
  }

  vim.fn.mkdir(state_directory(), "p")
  vim.fn.writefile({ json_encode(payload) }, state_path(root))
end

local function save_all_states()
  for root in pairs(runtime.known_roots) do
    save_state(root)
  end
end

local function session_for_buffer(bufnr)
  for _, session in ipairs(runtime.ai.sessions) do
    if session.bufnr == bufnr then
      return session
    end
  end
end

local function session_index(session)
  for index, candidate in ipairs(runtime.ai.sessions) do
    if candidate == session then
      return index
    end
  end

  return nil
end

local function session_status_icon(status)
  if status == "running" then
    return "●"
  end

  if status == "starting" then
    return "◌"
  end

  return "○"
end

local function update_ai_active(bufnr)
  local session = session_for_buffer(bufnr)
  if session then
    runtime.ai.active = session_index(session)
  end
end

local function ai_winbar()
  local tabs = {}

  for index, session in ipairs(runtime.ai.sessions) do
    local marker = index == runtime.ai.active and "*" or " "
    tabs[#tabs + 1] = string.format(
      "%s%d %s %s",
      marker,
      index,
      session.title,
      session_status_icon(session.status)
    )
  end

  if #tabs == 0 then
    return " Codex"
  end

  return " " .. table.concat(tabs, "  ") .. "  + :CodexNew"
end

local function update_ai_winbar()
  local drawer = runtime.ai_drawer
  if not drawer then
    return
  end

  local winid = drawer.get_winid()
  if winid == -1 or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  vim.wo[winid].winbar = ai_winbar()
end

local function scroll_to_bottom(winid)
  if winid == -1 or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local last_line = math.max(vim.api.nvim_buf_line_count(bufnr), 1)
  pcall(vim.api.nvim_win_set_cursor, winid, { last_line, 0 })
end

local function enter_terminal_mode(winid)
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end

    if vim.api.nvim_get_current_win() ~= winid then
      return
    end

    vim.api.nvim_win_call(winid, function()
      vim.cmd("startinsert")
    end)
  end)
end

local function set_terminal_options(bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].filetype = "codex_terminal"
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.statuscolumn = ""
end

local function set_bottom_options(bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].filetype = "project_terminal"
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.statuscolumn = ""
end

local function stop_job(job_id)
  if job_id and job_id > 0 then
    vim.fn.jobstop(job_id)
  end
end

local function codex_previous()
  if runtime.ai_drawer then
    runtime.ai_drawer.go(-1)
  end
end

local function codex_next()
  if runtime.ai_drawer then
    runtime.ai_drawer.go(1)
  end
end

local focus_editor_window

local function terminal_keymaps(bufnr)
  local opts = {
    buffer = bufnr,
    noremap = true,
    silent = true,
    nowait = true,
  }

  vim.keymap.set("n", "<S-H>", codex_previous, opts)
  vim.keymap.set("n", "<S-L>", codex_next, opts)

  -- These CSI-u sequences are emitted by the terminal profile for Shift+H/L
  -- and Cmd+H. They are intentionally buffer-local to Codex terminals.
  vim.keymap.set("t", "<Esc>[72;2u", codex_previous, opts)
  vim.keymap.set("t", "<Esc>[76;2u", codex_next, opts)
  vim.keymap.set("t", "<Esc>[102~", focus_editor_window, opts)
  vim.keymap.set("t", "<D-h>", focus_editor_window, opts)
end

local function create_codex_session(bufnr)
  local root = project_root()
  remember_root(root)

  local title = runtime.pending_session_name
  runtime.pending_session_name = nil
  if not title or title == "" then
    title = "Codex " .. tostring(#runtime.ai.sessions + 1)
  end

  local session = {
    id = string.format("session-%d", runtime.next_session_number),
    title = title,
    bufnr = bufnr,
    job_id = nil,
    status = "starting",
    cwd = root,
  }
  runtime.next_session_number = runtime.next_session_number + 1

  runtime.ai.sessions[#runtime.ai.sessions + 1] = session
  runtime.ai.active = #runtime.ai.sessions

  local job_id = vim.fn.termopen(vim.deepcopy(runtime.options.codex_cmd), {
    cwd = root,
  })
  session.job_id = job_id
  session.status = job_id > 0 and "running" or "exited"

  local group = vim.api.nvim_create_augroup(
    "CodexSidebarSession" .. bufnr,
    { clear = true }
  )
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    group = group,
    callback = function()
      session.status = "exited"
      session.job_id = nil
      update_ai_active(bufnr)
      update_ai_winbar()
      save_state(session.cwd)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    group = group,
    callback = function()
      stop_job(session.job_id)
      local index = session_index(session)
      if index then
        table.remove(runtime.ai.sessions, index)
        runtime.ai.active = math.min(runtime.ai.active, #runtime.ai.sessions)
        if runtime.ai.active < 1 then
          runtime.ai.active = 1
        end
      end
      update_ai_winbar()
      save_state(session.cwd)
    end,
  })

  set_terminal_options(bufnr)
  terminal_keymaps(bufnr)
  save_state(root)
end

local function create_bottom_terminal(bufnr)
  local root = project_root()
  remember_root(root)
  runtime.bottom.bufnr = bufnr
  runtime.bottom.cwd = root
  runtime.bottom.status = "starting"

  local job_id = vim.fn.termopen(vim.o.shell, { cwd = root })
  runtime.bottom.job_id = job_id
  runtime.bottom.status = job_id > 0 and "running" or "exited"

  local group = vim.api.nvim_create_augroup(
    "CodexSidebarBottomTerminal" .. bufnr,
    { clear = true }
  )
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    group = group,
    callback = function()
      runtime.bottom.status = "exited"
      runtime.bottom.job_id = nil

      vim.schedule(function()
        if runtime.bottom.bufnr ~= bufnr then
          return
        end

        if runtime.bottom_drawer and runtime.bottom_drawer.get_winid() ~= -1 then
          runtime.bottom_drawer.close()
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end

        runtime.bottom.bufnr = nil
        runtime.bottom.cwd = nil
      end)
    end,
  })

  set_bottom_options(bufnr)
end

local function setup_drawers()
  local drawer = require("nvim-drawer")
  drawer.setup()

  runtime.ai_drawer = drawer.create_drawer({
    position = "right",
    size = runtime.options.sidebar_width,
    should_close_on_bufwipeout = true,
    on_did_create_buffer = function(event)
      create_codex_session(event.bufnr)
    end,
    on_did_open_buffer = function(event)
      set_terminal_options(event.bufnr)
      terminal_keymaps(event.bufnr)
      update_ai_active(event.bufnr)
      update_ai_winbar()
      scroll_to_bottom(event.winid)
      enter_terminal_mode(event.winid)
    end,
    on_did_open = function(event)
      update_ai_active(event.bufnr)
      update_ai_winbar()
      scroll_to_bottom(event.winid)
      enter_terminal_mode(event.winid)
    end,
    on_did_close = function()
      save_all_states()
    end,
  })

  runtime.bottom_drawer = drawer.create_drawer({
    position = "below",
    size = runtime.options.terminal_height,
    should_close_on_bufwipeout = false,
    on_did_create_buffer = function(event)
      create_bottom_terminal(event.bufnr)
    end,
    on_did_open_buffer = function(event)
      set_bottom_options(event.bufnr)
      scroll_to_bottom(event.winid)
      enter_terminal_mode(event.winid)
    end,
    on_did_open = function(event)
      scroll_to_bottom(event.winid)
      enter_terminal_mode(event.winid)
    end,
  })
end

local function focus_or_toggle(drawer)
  if drawer then
    drawer.focus_or_toggle()

    local winid = drawer.get_winid()
    if winid ~= -1 and drawer.is_focused() then
      enter_terminal_mode(winid)
    end
  end
end

local function is_drawer_window(winid)
  return (runtime.ai_drawer and runtime.ai_drawer.does_own_window(winid))
    or (runtime.bottom_drawer and runtime.bottom_drawer.does_own_window(winid))
end

local function is_editor_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(winid)
  local win_config = vim.api.nvim_win_get_config(winid)
  local is_tree = false
  local ok, tree_api = pcall(require, "nvim-tree.api")
  if ok then
    is_tree = tree_api.tree.is_tree_buf(bufnr)
  end

  return win_config.relative == ""
    and not is_tree
    and not is_drawer_window(winid)
    and vim.bo[bufnr].buftype == ""
end

local function remember_editor_window()
  local winid = vim.api.nvim_get_current_win()
  if is_editor_window(winid) then
    runtime.last_editor_win = winid
  end
end

focus_editor_window = function()
  local target = runtime.last_editor_win
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

local function toggle_bottom_terminal()
  remember_editor_window()
  focus_or_toggle(runtime.bottom_drawer)
end

local function open_new_codex(name)
  runtime.pending_session_name = name and vim.trim(name) or nil
  runtime.ai_drawer.open({ mode = "new", focus = true })
end

local function close_active_codex()
  local session = runtime.ai.sessions[runtime.ai.active]
  if not session then
    vim.notify("No active Codex session", vim.log.levels.INFO)
    return
  end

  stop_job(session.job_id)
  if vim.api.nvim_buf_is_valid(session.bufnr) then
    vim.api.nvim_buf_delete(session.bufnr, { force = true })
  end
end

local function rename_active_codex(name)
  local session = runtime.ai.sessions[runtime.ai.active]
  if not session then
    vim.notify("No active Codex session", vim.log.levels.INFO)
    return
  end

  local function apply_name(value)
    value = vim.trim(value or "")
    if value == "" then
      return
    end

    session.title = value
    update_ai_winbar()
    save_state(session.cwd)
  end

  if name and vim.trim(name) ~= "" then
    apply_name(name)
    return
  end

  vim.ui.input({ prompt = "Codex name: ", default = session.title }, apply_name)
end

local function create_commands()
  vim.api.nvim_create_user_command("CodexSidebarToggle", function()
    focus_or_toggle(runtime.ai_drawer)
  end, { desc = "Focus or toggle the Codex sidebar" })

  vim.api.nvim_create_user_command("CodexNew", function(command)
    open_new_codex(command.args)
  end, { nargs = "?", desc = "Create a Codex session" })

  vim.api.nvim_create_user_command("CodexClose", close_active_codex, {
    desc = "Close the active Codex session",
  })

  vim.api.nvim_create_user_command("CodexRename", function(command)
    rename_active_codex(command.args)
  end, { nargs = "?", desc = "Rename the active Codex session" })

  vim.api.nvim_create_user_command("CodexNext", codex_next, {
    desc = "Select the next Codex session",
  })
  vim.api.nvim_create_user_command("CodexPrev", codex_previous, {
    desc = "Select the previous Codex session",
  })
  vim.api.nvim_create_user_command("ProjectTerminalToggle", function()
    toggle_bottom_terminal()
  end, { desc = "Focus or toggle the project terminal" })
end

local function create_global_mappings()
  local opts = { noremap = true, silent = true, nowait = true }

  local toggle_sidebar = function()
    focus_or_toggle(runtime.ai_drawer)
  end
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[99~", toggle_sidebar, opts)
  vim.keymap.set({ "n", "i", "t" }, "<D-l>", toggle_sidebar, opts)
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[98~", toggle_bottom_terminal, opts)
  vim.keymap.set({ "n", "i", "t" }, "<D-j>", toggle_bottom_terminal, opts)
  vim.keymap.set("t", "<Esc>[101~", focus_editor_window, opts)
  vim.keymap.set("t", "<D-k>", focus_editor_window, opts)
end

function M.setup(options)
  if runtime.initialized then
    return
  end

  runtime.initialized = true
  runtime.options = vim.tbl_deep_extend("force", DEFAULTS, options or {})
  runtime.root = project_root()
  remember_root(runtime.root)

  setup_drawers()
  create_commands()
  create_global_mappings()

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("CodexSidebarPersistence", { clear = true }),
    callback = save_all_states,
    desc = "Save Codex sidebar metadata",
  })
end

return M
