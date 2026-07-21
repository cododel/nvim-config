local M = {}

local function default_options()
  local ok, options = pcall(require, "cododel.options")
  if ok then
    local opts = options.get()
    return {
      agent_cmd = vim.deepcopy(opts.ai.cmd),
      agent_name = opts.ai.name,
      sidebar_width = opts.sidebar_width,
      terminal_height = opts.terminal_height,
    }
  end

  return {
    agent_cmd = { "codex" },
    agent_name = "Codex",
    sidebar_width = 42,
    terminal_height = 12,
  }
end

local runtime = {
  initialized = false,
  options = nil,
  pending_session_name = nil,
  pending_session_cwd = nil,
  ai = {
    active = 1,
    sessions = {},
  },
  bottom = {
    bufnr = nil,
  },
  ai_drawer = nil,
  bottom_drawer = nil,
}

M._state = runtime
local scheduled_terminal_modes = {}

local function project_root()
  local root = vim.fs.root(0, { ".git" })
  return root or vim.uv.cwd()
end

local function session_for_buffer(bufnr)
  for index, session in ipairs(runtime.ai.sessions) do
    if session.bufnr == bufnr then
      return index
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
  local index = session_for_buffer(bufnr)
  if index then
    runtime.ai.active = index
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

  local name = runtime.options and runtime.options.agent_name or "AI"
  if #tabs == 0 then
    return " " .. name
  end

  return " " .. table.concat(tabs, "  ") .. "  + :AiNew"
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
  if scheduled_terminal_modes[winid] then
    return
  end

  scheduled_terminal_modes[winid] = true
  vim.schedule(function()
    scheduled_terminal_modes[winid] = nil

    if not vim.api.nvim_win_is_valid(winid) then
      return
    end

    if vim.api.nvim_get_current_win() ~= winid then
      return
    end

    if vim.api.nvim_get_mode().mode ~= "t" then
      vim.api.nvim_win_call(winid, function()
        vim.cmd("startinsert")
      end)
    end
  end)
end

local function set_terminal_options(bufnr, filetype)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].filetype = filetype
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.statuscolumn = ""
end

local function set_bottom_options(bufnr)
  set_terminal_options(bufnr, "project_terminal")
end

local function prepare_terminal_window(event)
  scroll_to_bottom(event.winid)
  enter_terminal_mode(event.winid)
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

local function terminal_keymaps(bufnr)
  local opts = {
    buffer = bufnr,
    noremap = true,
    silent = true,
    nowait = true,
  }

  vim.keymap.set("n", "<S-H>", codex_previous, opts)
  vim.keymap.set("n", "<S-L>", codex_next, opts)

  -- These CSI-u sequences are emitted by the terminal profile for Shift+H/L.
  -- They are intentionally buffer-local to Codex terminals.
  vim.keymap.set("t", "<Esc>[72;2u", codex_previous, opts)
  vim.keymap.set("t", "<Esc>[76;2u", codex_next, opts)
end

local function create_codex_session(bufnr)
  local root = runtime.pending_session_cwd or project_root()
  runtime.pending_session_cwd = nil

  local title = runtime.pending_session_name
  runtime.pending_session_name = nil
  if not title or title == "" then
    local name = runtime.options.agent_name or "AI"
    title = name .. " " .. tostring(#runtime.ai.sessions + 1)
  end

  local session = {
    title = title,
    bufnr = bufnr,
    job_id = nil,
    status = "starting",
    cwd = root,
  }

  runtime.ai.sessions[#runtime.ai.sessions + 1] = session
  runtime.ai.active = #runtime.ai.sessions

  local job_id = vim.fn.termopen(vim.deepcopy(runtime.options.agent_cmd), {
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

      vim.schedule(function()
        if #runtime.ai.sessions == 1
          and runtime.ai_drawer
          and runtime.ai_drawer.get_winid() ~= -1
        then
          runtime.ai_drawer.close()
        end

        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end)
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
        if index < runtime.ai.active then
          runtime.ai.active = runtime.ai.active - 1
        elseif index == runtime.ai.active then
          runtime.ai.active = math.min(runtime.ai.active, #runtime.ai.sessions)
        end

        if #runtime.ai.sessions == 0 then
          runtime.ai.active = 1
        end
      end
      update_ai_winbar()
    end,
  })

  set_terminal_options(bufnr, "codex_terminal")
  terminal_keymaps(bufnr)
end

local function create_bottom_terminal(bufnr)
  local root = project_root()
  runtime.bottom.bufnr = bufnr

  vim.fn.termopen(vim.o.shell, { cwd = root })

  local group = vim.api.nvim_create_augroup(
    "CodexSidebarBottomTerminal" .. bufnr,
    { clear = true }
  )
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    group = group,
    callback = function()
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
      end)
    end,
  })

  set_bottom_options(bufnr)
end

local function normalize_ai_layout()
  local drawer = runtime.ai_drawer
  if not drawer then
    return
  end

  local winid = drawer.get_winid()
  if winid == -1 or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  -- Pin to the far right so a later file split cannot leave AI in the middle.
  pcall(vim.api.nvim_win_call, winid, function()
    vim.cmd("wincmd L")
  end)

  local max_width = math.max(1, vim.o.columns - 1)
  local width = math.min(runtime.options.sidebar_width, max_width)
  pcall(vim.api.nvim_win_set_width, winid, width)
end

local function normalize_bottom_layout()
  local drawer = runtime.bottom_drawer
  if not drawer then
    return
  end

  local winid = drawer.get_winid()
  if winid == -1 or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  -- A below-split inherits the width of the window it was opened from. Move
  -- it to the bottom of the root layout so it spans the whole editor, even
  -- when the file or AI sidebar was opened first.
  if vim.api.nvim_win_get_width(winid) < vim.o.columns then
    pcall(vim.api.nvim_win_call, winid, function()
      vim.cmd("wincmd J")
    end)
  end

  local max_height = math.max(1, vim.o.lines - vim.o.cmdheight - 1)
  local height = math.min(runtime.options.terminal_height, max_height)
  pcall(vim.api.nvim_win_set_height, winid, height)
end

-- AI first (right), then bottom (full width) — order matters for winlayout.
local function normalize_panel_layout()
  normalize_ai_layout()
  normalize_bottom_layout()
end

local function schedule_normalize_panel_layout()
  vim.schedule(normalize_panel_layout)
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
      set_terminal_options(event.bufnr, "codex_terminal")
      terminal_keymaps(event.bufnr)
      update_ai_active(event.bufnr)
      update_ai_winbar()
      prepare_terminal_window(event)
    end,
    on_did_open = function(event)
      update_ai_active(event.bufnr)
      update_ai_winbar()
      prepare_terminal_window(event)
      schedule_normalize_panel_layout()
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
      prepare_terminal_window(event)
    end,
    on_did_open = function(event)
      prepare_terminal_window(event)
      schedule_normalize_panel_layout()
    end,
  })
end

local function drawer_is_open(drawer)
  return drawer ~= nil and drawer.get_winid() ~= -1
end

local function drawer_is_focused(drawer)
  return drawer_is_open(drawer) and drawer.is_focused()
end

local function focus_drawer(drawer)
  if not drawer then
    return
  end

  if not drawer_is_open(drawer) then
    drawer.open({ focus = true })
  else
    drawer.focus()
  end

  local winid = drawer.get_winid()
  if winid ~= -1 and drawer.is_focused() then
    enter_terminal_mode(winid)
  end

  schedule_normalize_panel_layout()
end

local function focus_ai_with_cwd(cwd)
  if cwd and #runtime.ai.sessions == 0 then
    runtime.pending_session_cwd = cwd
  end

  focus_drawer(runtime.ai_drawer)
end

local function hide_drawer(drawer)
  if drawer_is_open(drawer) then
    drawer.close()
  end
end

local function toggle_drawer(drawer)
  if drawer_is_focused(drawer) then
    hide_drawer(drawer)
  else
    focus_drawer(drawer)
  end
end

local function make_panel_controller(get_drawer)
  return {
    get_winid = function()
      local drawer = get_drawer()
      return drawer and drawer.get_winid() or -1
    end,
    is_open = function()
      return drawer_is_open(get_drawer())
    end,
    is_focused = function()
      return drawer_is_focused(get_drawer())
    end,
    focus = function()
      focus_drawer(get_drawer())
    end,
    hide = function()
      hide_drawer(get_drawer())
    end,
    toggle = function()
      toggle_drawer(get_drawer())
    end,
  }
end

M.panels = {
  ai = make_panel_controller(function()
    return runtime.ai_drawer
  end),
  bottom = make_panel_controller(function()
    return runtime.bottom_drawer
  end),
}

M.panels.ai.focus_with_cwd = focus_ai_with_cwd

local function open_new_codex(name)
  runtime.pending_session_name = name and vim.trim(name) or nil
  runtime.ai_drawer.open({ mode = "new", focus = true })
end

local function agent_label()
  return (runtime.options and runtime.options.agent_name) or "AI"
end

local function close_active_codex()
  local session = runtime.ai.sessions[runtime.ai.active]
  if not session then
    vim.notify("No active " .. agent_label() .. " session", vim.log.levels.INFO)
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
    vim.notify("No active " .. agent_label() .. " session", vim.log.levels.INFO)
    return
  end

  local function apply_name(value)
    value = vim.trim(value or "")
    if value == "" then
      return
    end

    session.title = value
    update_ai_winbar()
  end

  if name and vim.trim(name) ~= "" then
    apply_name(name)
    return
  end

  vim.ui.input({
    prompt = agent_label() .. " name: ",
    default = session.title,
  }, apply_name)
end

local function create_commands()
  local label = agent_label()

  local function define(name, fn, opts)
    vim.api.nvim_create_user_command(name, fn, opts)
  end

  define("AiSidebarToggle", function()
    M.panels.ai.toggle()
  end, { desc = "Focus or toggle the AI sidebar" })

  define("AiNew", function(command)
    open_new_codex(command.args)
  end, { nargs = "?", desc = "Create an AI session (" .. label .. ")" })

  define("AiClose", close_active_codex, {
    desc = "Close the active AI session",
  })

  define("AiRename", function(command)
    rename_active_codex(command.args)
  end, { nargs = "?", desc = "Rename the active AI session" })

  define("AiNext", codex_next, {
    desc = "Select the next AI session",
  })
  define("AiPrev", codex_previous, {
    desc = "Select the previous AI session",
  })

  -- Backward-compatible aliases (Codex-era names).
  define("CodexSidebarToggle", function()
    M.panels.ai.toggle()
  end, { desc = "Alias for :AiSidebarToggle" })
  define("CodexNew", function(command)
    open_new_codex(command.args)
  end, { nargs = "?", desc = "Alias for :AiNew" })
  define("CodexClose", close_active_codex, { desc = "Alias for :AiClose" })
  define("CodexRename", function(command)
    rename_active_codex(command.args)
  end, { nargs = "?", desc = "Alias for :AiRename" })
  define("CodexNext", codex_next, { desc = "Alias for :AiNext" })
  define("CodexPrev", codex_previous, { desc = "Alias for :AiPrev" })

  define("ProjectTerminalToggle", function()
    require("cododel.navigation").toggle_bottom()
  end, { desc = "Focus or toggle the project terminal" })
end

local function is_panel_terminal_win(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local ft = vim.bo[vim.api.nvim_win_get_buf(winid)].filetype
  return ft == "codex_terminal" or ft == "project_terminal"
end

local function setup_layout_autocmds()
  local group = vim.api.nvim_create_augroup("CododelPanelLayout", { clear = true })

  -- File opens and other splits redistribute widths; re-pin drawers after.
  vim.api.nvim_create_autocmd({ "WinNew", "VimResized" }, {
    group = group,
    callback = function()
      if not drawer_is_open(runtime.ai_drawer) and not drawer_is_open(runtime.bottom_drawer) then
        return
      end

      schedule_normalize_panel_layout()
    end,
  })

  -- :bd / window closes often land focus on the AI split in Normal mode.
  -- Entering a panel terminal always resumes insert (terminal) mode.
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local winid = vim.api.nvim_get_current_win()
      if not is_panel_terminal_win(winid) then
        return
      end

      if runtime.ai_drawer and runtime.ai_drawer.get_winid() == winid then
        enter_terminal_mode(winid)
        return
      end

      if runtime.bottom_drawer and runtime.bottom_drawer.get_winid() == winid then
        enter_terminal_mode(winid)
      end
    end,
  })
end

function M.setup(options)
  if runtime.initialized then
    return
  end

  runtime.initialized = true
  options = options or {}
  -- Legacy test/setup key: codex_cmd → agent_cmd
  if options.codex_cmd and not options.agent_cmd then
    options.agent_cmd = options.codex_cmd
  end
  runtime.options = vim.tbl_deep_extend("force", default_options(), options)

  if type(runtime.options.agent_cmd) == "string" then
    runtime.options.agent_cmd = { runtime.options.agent_cmd }
  end

  setup_drawers()
  setup_layout_autocmds()
  create_commands()
  require("cododel.navigation").setup({
    file_sidebar = require("cododel.file_sidebar"),
    panels = M.panels,
  })
end

-- Test seam for layout helpers (tree-only → AI → file regressions).
M._normalize_panel_layout = normalize_panel_layout
M._enter_terminal_mode = enter_terminal_mode

return M
