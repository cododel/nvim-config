local M = {}
local bindings = require("cododel.bindings")

local MARGIN = 1
local ZINDEX = 50

local state = {
  initialized = false,
  float_win = nil,
  source_win = nil,
  augroup = nil,
}

function M.geometry()
  local cols = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight

  return {
    relative = "editor",
    row = MARGIN,
    col = MARGIN,
    width = math.max(cols - MARGIN * 2, 1),
    height = math.max(lines - MARGIN * 2, 1),
    style = "minimal",
    border = "single",
    zindex = ZINDEX,
  }
end

local function clear_autocmds()
  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end
end

local function reset_state()
  state.float_win = nil
  state.source_win = nil
  clear_autocmds()
end

local function is_float_open()
  return state.float_win ~= nil and vim.api.nvim_win_is_valid(state.float_win)
end

local function enter_terminal_mode(winid)
  vim.schedule(function()
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

local function apply_geometry()
  if not is_float_open() then
    return
  end

  vim.api.nvim_win_set_config(state.float_win, M.geometry())
end

local function close()
  local float_win = state.float_win
  local source_win = state.source_win
  reset_state()

  if float_win and vim.api.nvim_win_is_valid(float_win) then
    vim.api.nvim_win_close(float_win, true)
  end

  if source_win and vim.api.nvim_win_is_valid(source_win) then
    vim.api.nvim_set_current_win(source_win)
  end
end

local function open()
  local source_win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(source_win) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(source_win)
  local view = vim.api.nvim_win_call(source_win, function()
    return vim.fn.winsaveview()
  end)

  local float_win = vim.api.nvim_open_win(bufnr, true, M.geometry())
  state.float_win = float_win
  state.source_win = source_win

  pcall(vim.api.nvim_win_call, float_win, function()
    vim.fn.winrestview(view)
  end)

  state.augroup = vim.api.nvim_create_augroup("CododelMaximize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = apply_geometry,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    pattern = tostring(float_win),
    callback = function()
      if state.float_win ~= float_win then
        return
      end

      local source = state.source_win
      reset_state()
      if source and vim.api.nvim_win_is_valid(source) then
        pcall(vim.api.nvim_set_current_win, source)
      end
    end,
  })

  if vim.bo[bufnr].buftype == "terminal" then
    enter_terminal_mode(float_win)
  end
end

function M.toggle()
  if is_float_open() then
    close()
  else
    open()
  end
end

function M.setup()
  if state.initialized then
    return
  end

  state.initialized = true

  bindings.set({ "n", "i", "t" }, bindings.shortcuts.maximize_pane, M.toggle, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = "Maximize current pane as float",
  })
end

return M
