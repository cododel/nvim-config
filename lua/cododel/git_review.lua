local M = {}
local bindings = require("cododel.bindings")
local cododel_deps = require("cododel.deps")

cododel_deps.need({
  bin = "lazygit",
  level = "error",
  feature = "Git review",
  install = "brew install lazygit",
})
cododel_deps.need({
  bin = "delta",
  level = "warn",
  feature = "Git review pager (Delta)",
  install = "brew install git-delta",
})

local state = {
  initialized = false,
  active = false,
  snapshot = nil,
  review_bufnr = nil,
  review_win = nil,
  created_content_win = false,
  job_id = nil,
  deps = nil,
}

local function deps()
  return state.deps
end

local function project_root()
  local root = vim.fs.root(0, { ".git" })
  return root or vim.uv.cwd()
end

local function config_path()
  local candidates = {
    vim.fn.stdpath("config") .. "/lazygit/config.yml",
  }

  for _, path in ipairs(candidates) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
end

local function is_tree_buffer(bufnr)
  local ok, tree_api = pcall(require, "nvim-tree.api")
  return ok and tree_api.tree.is_tree_buf(bufnr)
end

local function is_drawer_window(winid)
  local ok, drawer = pcall(require, "nvim-drawer")
  if not ok or not drawer.find_instance_for_winid then
    return false
  end

  return drawer.find_instance_for_winid(winid) ~= nil
end

local function is_normal_window(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  return vim.api.nvim_win_get_config(winid).relative == ""
end

-- Non-tree, non-drawer normal split — the editor / content column.
local function find_content_window()
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_normal_window(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if not is_tree_buffer(bufnr) and not is_drawer_window(winid) then
        return winid
      end
    end
  end
end

local function count_non_drawer_windows()
  local count = 0
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_normal_window(winid) and not is_drawer_window(winid) then
      count = count + 1
    end
  end
  return count
end

local function ensure_content_window()
  local existing = find_content_window()
  if existing then
    return existing, false
  end

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_normal_window(winid) and is_tree_buffer(vim.api.nvim_win_get_buf(winid)) then
      vim.api.nvim_set_current_win(winid)
      break
    end
  end

  vim.cmd("belowright vsplit")
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(0, buf)
  return vim.api.nvim_get_current_win(), true
end

local function set_review_window_options(winid, bufnr)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].bufhidden = "hide"
  pcall(function()
    vim.bo[bufnr].filetype = "lazygit"
  end)

  if vim.api.nvim_win_is_valid(winid) then
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = "no"
    vim.wo[winid].statuscolumn = ""
  end
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

local function file_sidebar()
  return deps().file_sidebar
end

local function clear_review_handles()
  state.review_bufnr = nil
  state.review_win = nil
  state.job_id = nil
  state.created_content_win = false
  state.snapshot = nil
end

local function wipe_review_buffer()
  local bufnr = state.review_bufnr
  local job_id = state.job_id
  state.review_bufnr = nil
  state.job_id = nil

  if job_id and job_id > 0 then
    pcall(vim.fn.jobstop, job_id)
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
end

local function place_empty_scratch(winid)
  if not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_win_set_buf(winid, buf)
end

local function restore_after_exit()
  local snapshot = state.snapshot
  local review_win = state.review_win
  local created = state.created_content_win

  wipe_review_buffer()

  if not snapshot then
    clear_review_handles()
    return
  end

  local content_win = review_win
  if not content_win or not vim.api.nvim_win_is_valid(content_win) then
    content_win = find_content_window()
  end

  if snapshot.editor_present and snapshot.editor_bufnr and vim.api.nvim_buf_is_valid(snapshot.editor_bufnr) then
    if content_win and vim.api.nvim_win_is_valid(content_win) then
      vim.api.nvim_win_set_buf(content_win, snapshot.editor_bufnr)
      if snapshot.editor_view then
        pcall(vim.api.nvim_win_call, content_win, function()
          vim.fn.winrestview(snapshot.editor_view)
        end)
      end
      vim.api.nvim_set_current_win(content_win)
    end
  else
    -- No prior editor: never force the previous file buffer back.
    if snapshot.files_open then
      file_sidebar().focus()
      if created and content_win and vim.api.nvim_win_is_valid(content_win) then
        -- Tree is a non-drawer window, so closing content is safe.
        if count_non_drawer_windows() > 1 then
          pcall(vim.api.nvim_win_close, content_win, true)
        else
          place_empty_scratch(content_win)
        end
      elseif content_win and vim.api.nvim_win_is_valid(content_win) then
        place_empty_scratch(content_win)
      end
    else
      if content_win and vim.api.nvim_win_is_valid(content_win) then
        if created and count_non_drawer_windows() > 1 then
          pcall(vim.api.nvim_win_close, content_win, true)
        else
          -- Keep a non-drawer column so nvim-drawer does not :qa.
          place_empty_scratch(content_win)
        end
      end
    end
  end

  if snapshot.files_open and not file_sidebar().is_open() then
    if snapshot.editor_present then
      -- Re-open files without stealing focus from the restored editor.
      local current = vim.api.nvim_get_current_win()
      file_sidebar().focus()
      if vim.api.nvim_win_is_valid(current) then
        vim.api.nvim_set_current_win(current)
      end
    else
      file_sidebar().focus()
    end
  end

  clear_review_handles()
end

function M.is_active()
  return state.active
end

function M.is_review_win(winid)
  return state.active
    and state.review_win ~= nil
    and winid == state.review_win
    and vim.api.nvim_win_is_valid(winid)
end

function M.is_focused()
  return M.is_review_win(vim.api.nvim_get_current_win())
end

function M.get_winid()
  if state.review_win and vim.api.nvim_win_is_valid(state.review_win) then
    return state.review_win
  end
  return -1
end

function M.close()
  if not state.active then
    -- Still clean stray handles if any.
    if state.review_bufnr then
      wipe_review_buffer()
      clear_review_handles()
    end
    return
  end

  state.active = false
  restore_after_exit()
end

local function on_job_exit()
  vim.schedule(function()
    if not state.active then
      return
    end
    M.close()
  end)
end

function M.open()
  if state.active then
    return
  end

  local d = deps()
  -- Uses setup-injected executable in tests; production default goes through cododel.deps.
  if not d.executable("lazygit") then
    d.notify("lazygit is not installed or not in PATH", vim.log.levels.ERROR)
    return
  end

  local sidebar = file_sidebar()
  local content_win = find_content_window()
  local editor_present = false
  local editor_bufnr = nil
  local editor_view = nil

  if content_win then
    local bufnr = vim.api.nvim_win_get_buf(content_win)
    if vim.bo[bufnr].buftype == "" then
      editor_present = true
      editor_bufnr = bufnr
      editor_view = vim.api.nvim_win_call(content_win, function()
        return vim.fn.winsaveview()
      end)
    end
  end

  local files_open = sidebar.is_open()
  state.snapshot = {
    files_open = files_open,
    editor_present = editor_present,
    editor_bufnr = editor_bufnr,
    editor_view = editor_view,
  }

  if files_open then
    sidebar.hide()
  end

  local created = false
  if not content_win then
    content_win, created = ensure_content_window()
  end
  state.created_content_win = created
  state.review_win = content_win

  local bufnr = vim.api.nvim_create_buf(false, true)
  state.review_bufnr = bufnr
  vim.api.nvim_win_set_buf(content_win, bufnr)
  vim.api.nvim_set_current_win(content_win)
  set_review_window_options(content_win, bufnr)

  if not vim.v.servername or vim.v.servername == "" then
    pcall(vim.fn.serverstart, "cododel-git-review")
  end

  local cmd = { "lazygit" }
  local cfg = config_path()
  if cfg then
    cmd[#cmd + 1] = "--use-config-file"
    cmd[#cmd + 1] = cfg
  end

  local env = nil
  if vim.v.servername and vim.v.servername ~= "" then
    env = vim.fn.environ()
    env.NVIM = vim.v.servername
  end

  local job_id
  vim.api.nvim_win_call(content_win, function()
    job_id = d.termopen(cmd, {
      cwd = project_root(),
      env = env,
      on_exit = function()
        on_job_exit()
      end,
    })
  end)

  state.job_id = job_id
  state.active = true

  if not job_id or job_id <= 0 then
    state.active = false
    wipe_review_buffer()
    -- Best-effort restore of snapshot without full close path re-entry.
    if state.snapshot and state.snapshot.editor_present and state.snapshot.editor_bufnr then
      if vim.api.nvim_win_is_valid(content_win) and vim.api.nvim_buf_is_valid(state.snapshot.editor_bufnr) then
        vim.api.nvim_win_set_buf(content_win, state.snapshot.editor_bufnr)
      end
    end
    if state.snapshot and state.snapshot.files_open then
      sidebar.focus()
    end
    clear_review_handles()
    d.notify("failed to start lazygit", vim.log.levels.ERROR)
    return
  end

  enter_terminal_mode(content_win)
end

function M.toggle()
  if state.active then
    M.close()
  else
    M.open()
  end
end

local function default_deps(options)
  options = options or {}
  return {
    executable = options.executable or function(name)
      return cododel_deps.ensure(name)
    end,
    termopen = options.termopen or function(cmd, opts)
      return vim.fn.termopen(cmd, opts)
    end,
    notify = options.notify or vim.notify,
    file_sidebar = options.file_sidebar or require("cododel.file_sidebar"),
  }
end

function M.setup(options)
  state.deps = default_deps(options)

  if state.initialized then
    return
  end

  state.initialized = true

  bindings.set({ "n", "i", "t" }, bindings.shortcuts.git_review, M.toggle, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = "Toggle LazyGit review mode",
  })

  vim.api.nvim_create_user_command("CododelGitReview", function()
    M.toggle()
  end, { desc = "Toggle LazyGit review mode in the editor column" })
end

return M
