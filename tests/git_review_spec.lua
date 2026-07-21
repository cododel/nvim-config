package.preload["cododel.bindings"] = function()
  return dofile(vim.fn.getcwd() .. "/lua/cododel/bindings.lua")
end

package.preload["cododel.deps"] = function()
  return dofile(vim.fn.getcwd() .. "/lua/cododel/deps.lua")
end

local tree_bufs = {}
local tree_win = nil
local files_open = false
local files_focus_count = 0
local files_hide_count = 0

package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function(bufnr)
        return tree_bufs[bufnr] == true
      end,
      open = function()
        if tree_win and vim.api.nvim_win_is_valid(tree_win) then
          return
        end
        local buf = vim.api.nvim_create_buf(false, true)
        tree_bufs[buf] = true
        tree_win = vim.api.nvim_open_win(buf, false, {
          relative = "editor",
          row = 0,
          col = 0,
          width = 12,
          height = 8,
          style = "minimal",
        })
        files_open = true
      end,
      close = function()
        if tree_win and vim.api.nvim_win_is_valid(tree_win) then
          vim.api.nvim_win_close(tree_win, true)
        end
        tree_win = nil
        files_open = false
      end,
    },
  }
end

package.preload["nvim-drawer"] = function()
  return {
    find_instance_for_winid = function()
      return nil
    end,
  }
end

package.preload["cododel.file_sidebar"] = function()
  return {
    is_open = function()
      return files_open
    end,
    is_focused = function()
      return tree_win ~= nil and vim.api.nvim_get_current_win() == tree_win
    end,
    focus = function()
      files_focus_count = files_focus_count + 1
      require("nvim-tree.api").tree.open()
      if tree_win and vim.api.nvim_win_is_valid(tree_win) then
        vim.api.nvim_set_current_win(tree_win)
      end
    end,
    hide = function()
      files_hide_count = files_hide_count + 1
      require("nvim-tree.api").tree.close()
    end,
    get_winid = function()
      return tree_win
    end,
  }
end

local notifications = {}
local last_termopen = nil
local termopen_job_id = 100
local real_termopen = vim.fn.termopen

local git_review = dofile(vim.fn.getcwd() .. "/lua/cododel/git_review.lua")

git_review.setup({
  executable = function(name)
    if name == "lazygit" then
      return true
    end
    return vim.fn.executable(name) == 1
  end,
  termopen = function(cmd, opts)
    last_termopen = { cmd = cmd, opts = opts }
    -- Real PTY so buftype becomes terminal; long sleep keeps process alive.
    local job = real_termopen({ "sleep", "100" }, {
      cwd = opts and opts.cwd or nil,
      on_exit = opts and opts.on_exit or nil,
    })
    return job > 0 and job or termopen_job_id
  end,
  notify = function(msg, level)
    notifications[#notifications + 1] = { msg = msg, level = level }
  end,
})

local function mapping(lhs, mode)
  for _, item in ipairs(vim.api.nvim_get_keymap(mode or "n")) do
    if item.lhs == lhs or item.lhsraw == lhs then
      return item.callback
    end
  end
  -- Fallback: normalized lhs comparison
  for _, item in ipairs(vim.api.nvim_get_keymap(mode or "n")) do
    if item.lhs:lower() == lhs:lower() then
      return item.callback
    end
  end
  error("mapping not found: " .. lhs)
end

local toggle = mapping("<C-S-g>")
for _, mode in ipairs({ "n", "i", "t" }) do
  assert(mapping("<C-S-g>", mode) == toggle, "Ctrl+Shift+G bound in " .. mode)
  assert(mapping("<C-S-п>", mode) == toggle, "Ctrl+Shift+п bound in " .. mode)
end

-- Stable editor column
local editor_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(editor_buf, 0, -1, false, { "line-one", "line-two", "line-three" })
local editor_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(editor_win, editor_buf)
vim.api.nvim_win_set_cursor(editor_win, { 2, 3 })
local saved_view = vim.api.nvim_win_call(editor_win, function()
  return vim.fn.winsaveview()
end)

-- AI drawer stub window (must remain untouched)
local ai_buf = vim.api.nvim_create_buf(false, true)
local ai_win = vim.api.nvim_open_win(ai_buf, false, {
  relative = "editor",
  row = 0,
  col = 40,
  width = 15,
  height = 8,
  style = "minimal",
})
local ai_buf_before = ai_buf

-- Open files sidebar
require("nvim-tree.api").tree.open()
assert(files_open, "files start open")
files_hide_count = 0
files_focus_count = 0
notifications = {}
last_termopen = nil

-- Enter review
git_review.open()
assert(git_review.is_active(), "open activates review mode")
assert(files_hide_count == 1, "enter hides files")
assert(not files_open, "files are closed after enter")
assert(vim.api.nvim_win_is_valid(ai_win), "AI window remains valid")
assert(vim.api.nvim_win_get_buf(ai_win) == ai_buf_before, "AI buffer is untouched")
assert(last_termopen ~= nil, "lazygit termopen was called")
assert(type(last_termopen.cmd) == "table", "lazygit is launched as a command list")
assert(last_termopen.cmd[1] == "lazygit", "first arg is lazygit")

local review_win = git_review.get_winid()
assert(review_win ~= -1, "review has a window")
assert(vim.api.nvim_win_is_valid(review_win), "review window is valid")
assert(review_win == editor_win, "review reuses the editor content window")
local review_buf = vim.api.nvim_win_get_buf(review_win)
assert(review_buf ~= editor_buf, "review replaces the editor buffer")
assert(git_review.is_review_win(review_win), "content win is the review win")
assert(git_review.is_focused() or vim.api.nvim_get_current_win() == review_win, "review is focused")

-- Exit restores editor + files
git_review.close()
assert(not git_review.is_active(), "close deactivates review mode")
assert(vim.api.nvim_win_is_valid(editor_win), "editor window still valid")
assert(vim.api.nvim_win_get_buf(editor_win) == editor_buf, "editor buffer restored")
local restored_view = vim.api.nvim_win_call(editor_win, function()
  return vim.fn.winsaveview()
end)
assert(restored_view.lnum == saved_view.lnum, "editor cursor line restored")
assert(files_open, "files restored when they were open")
assert(files_focus_count >= 1, "files focus called on restore")
assert(vim.api.nvim_win_is_valid(ai_win), "AI still valid after exit")
assert(vim.api.nvim_win_get_buf(ai_win) == ai_buf_before, "AI buffer still untouched after exit")

-- Files closed before enter stay closed
require("nvim-tree.api").tree.close()
files_hide_count = 0
files_focus_count = 0
git_review.open()
assert(git_review.is_active(), "re-open works")
assert(files_hide_count == 0, "hide not called when files already closed")
git_review.close()
assert(not files_open, "files stay closed when they were closed")
assert(files_focus_count == 0, "files not focused when they were closed")
assert(vim.api.nvim_win_get_buf(editor_win) == editor_buf, "editor restored again")

-- Toggle while active exits
git_review.open()
assert(git_review.is_active(), "toggle open")
git_review.toggle()
assert(not git_review.is_active(), "toggle closes when active")
assert(vim.api.nvim_win_get_buf(editor_win) == editor_buf, "toggle exit restores editor")

-- on_exit path restores the same way
git_review.open()
assert(git_review.is_active(), "open for on_exit test")
local on_exit = last_termopen and last_termopen.opts and last_termopen.opts.on_exit
assert(type(on_exit) == "function", "termopen received on_exit")
on_exit(0, 0, 0)
-- on_exit is scheduled; flush
vim.wait(200, function()
  return not git_review.is_active()
end)
assert(not git_review.is_active(), "on_exit deactivates review")
assert(vim.api.nvim_win_get_buf(editor_win) == editor_buf, "on_exit restores editor buffer")

-- No real editor before enter (content win with non-empty buftype): do not
-- force-restore that buffer as the editor after exit.
local non_editor_buf = vim.api.nvim_create_buf(false, true)
vim.bo[non_editor_buf].buftype = "nofile"
vim.api.nvim_win_set_buf(editor_win, non_editor_buf)
require("nvim-tree.api").tree.open()
assert(files_open, "files open without a real editor")
files_focus_count = 0

git_review.open()
assert(git_review.is_active(), "open without prior editor")
local review_only_win = git_review.get_winid()
assert(review_only_win ~= -1, "review uses a content window")
assert(vim.api.nvim_win_get_buf(review_only_win) ~= non_editor_buf, "review replaces non-editor content")
git_review.close()
assert(not git_review.is_active(), "closed after no-editor session")
assert(files_open, "files restored after no-editor session")
assert(files_focus_count >= 1, "files focused after no-editor exit")
if vim.api.nvim_win_is_valid(editor_win) then
  assert(
    vim.api.nvim_win_get_buf(editor_win) ~= non_editor_buf,
    "no-editor exit must not restore the previous non-editor buffer as the session"
  )
  assert(
    vim.api.nvim_win_get_buf(editor_win) ~= editor_buf,
    "no-editor exit must not resurrect an earlier file buffer"
  )
end

-- Missing lazygit
local git_review_missing = dofile(vim.fn.getcwd() .. "/lua/cododel/git_review.lua")
-- Module is a singleton; re-setup overrides deps
notifications = {}
git_review.setup({
  executable = function()
    return false
  end,
  termopen = function()
    error("termopen must not run when lazygit is missing")
  end,
  notify = function(msg, level)
    notifications[#notifications + 1] = { msg = msg, level = level }
  end,
})
-- Force inactive after previous tests
if git_review.is_active() then
  git_review.close()
end
git_review.open()
assert(not git_review.is_active(), "missing lazygit does not activate")
assert(#notifications >= 1, "missing lazygit notifies the user")
assert(tostring(notifications[1].msg):lower():find("lazygit", 1, true), "notify mentions lazygit")

print("git_review_spec: ok")
