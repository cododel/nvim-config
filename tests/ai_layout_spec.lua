-- Layout regressions: tree-only → open AI → open file must keep AI as a
-- right sidebar. No placeholder editor buffers.

local tree_bufs = {}

package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function(bufnr)
        return tree_bufs[bufnr] == true
      end,
    },
  }
end

local drawer_wins = {}

package.preload["nvim-drawer"] = function()
  local module = {}

  function module.setup() end

  function module.find_instance_for_winid(winid)
    return drawer_wins[winid]
  end

  function module.create_drawer(options)
    local instance = { winid = -1, opts = options }

    function instance.get_winid()
      if instance.winid ~= -1 and vim.api.nvim_win_is_valid(instance.winid) then
        return instance.winid
      end
      return -1
    end

    function instance.is_focused()
      return instance.get_winid() ~= -1
        and vim.api.nvim_get_current_win() == instance.winid
    end

    function instance.open(open_options)
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.bo[bufnr].buftype = "nofile"
      vim.bo[bufnr].filetype = "codex_terminal"

      if instance.winid == -1 or not vim.api.nvim_win_is_valid(instance.winid) then
        instance.winid = vim.api.nvim_open_win(bufnr, false, {
          split = options.position == "below" and "below" or "right",
          win = -1,
          width = options.size,
          height = options.size,
        })
        drawer_wins[instance.winid] = instance
      else
        vim.api.nvim_win_set_buf(instance.winid, bufnr)
      end

      if options.on_did_create_buffer then
        options.on_did_create_buffer({
          instance = instance,
          winid = instance.winid,
          bufnr = bufnr,
        })
      end

      if options.on_did_open_buffer then
        options.on_did_open_buffer({
          instance = instance,
          winid = instance.winid,
          bufnr = bufnr,
        })
      end

      if open_options and open_options.focus then
        vim.api.nvim_set_current_win(instance.winid)
      end

      if options.on_did_open then
        options.on_did_open({
          instance = instance,
          winid = instance.winid,
          bufnr = bufnr,
        })
      end
    end

    function instance.focus()
      if instance.get_winid() ~= -1 then
        vim.api.nvim_set_current_win(instance.winid)
      end
    end

    function instance.close()
      local winid = instance.get_winid()
      if winid ~= -1 then
        drawer_wins[winid] = nil
        pcall(vim.api.nvim_win_close, winid, true)
      end
      instance.winid = -1
    end

    function instance.go() end
    function instance.focus_or_toggle() end

    return instance
  end

  return module
end

local function window_is_rightmost(winid)
  local rightmost
  local rightmost_col = -1

  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == "" then
      local col = vim.api.nvim_win_get_position(w)[2]
      if col >= rightmost_col then
        rightmost_col = col
        rightmost = w
      end
    end
  end

  return rightmost == winid
end

local function count_listed_bufs()
  local n = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      n = n + 1
    end
  end
  return n
end

-- Start from a single tree-like window (no editor column).
local tree_buf = vim.api.nvim_create_buf(false, true)
vim.bo[tree_buf].buftype = "nofile"
vim.bo[tree_buf].buflisted = false
vim.bo[tree_buf].filetype = "NvimTree"
tree_bufs[tree_buf] = true
local tree_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(tree_win, tree_buf)

local listed_before = count_listed_bufs()

local ai = dofile(vim.fn.getcwd() .. "/lua/cododel/ai_sidebar.lua")
ai.setup({
  codex_cmd = { "sleep", "100" },
  sidebar_width = 42,
  terminal_height = 12,
})

ai.panels.ai.focus()
vim.wait(50, function()
  return false
end)

assert(
  count_listed_bufs() == listed_before,
  "opening AI must not create a listed placeholder editor buffer"
)
assert(
  #vim.api.nvim_tabpage_list_wins(0) == 2,
  "tree + AI only — no phantom content column"
)

local ai_win = ai.panels.ai.get_winid()
assert(ai_win ~= -1, "AI drawer is open")
assert(window_is_rightmost(ai_win), "AI is rightmost after open")

-- Simulate file open: insert a middle column between tree and AI, then
-- equalalways-style width theft.
vim.api.nvim_set_current_win(tree_win)
vim.cmd("belowright vsplit")
local file_win = vim.api.nvim_get_current_win()
local file_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(file_buf, "/tmp/ai_layout_spec.lua")
vim.api.nvim_win_set_buf(file_win, file_buf)

ai_win = ai.panels.ai.get_winid()
pcall(vim.api.nvim_win_set_width, ai_win, 20)
pcall(vim.api.nvim_win_set_width, file_win, 40)

ai._normalize_panel_layout()

ai_win = ai.panels.ai.get_winid()
assert(ai_win ~= -1, "AI still open after normalize")
assert(window_is_rightmost(ai_win), "AI stays rightmost after file open")
assert(
  vim.api.nvim_win_get_width(ai_win) == 42,
  "AI recovers sidebar width after normalize, got "
    .. tostring(vim.api.nvim_win_get_width(ai_win))
)

-- Closing the file window lands on AI; WinEnter should request terminal mode
-- (startinsert is scheduled — we only assert the helper path is wired).
vim.api.nvim_set_current_win(file_win)
pcall(vim.api.nvim_win_close, file_win, true)
vim.wait(50, function()
  return false
end)

assert(
  vim.api.nvim_get_current_win() == ai.panels.ai.get_winid()
    or vim.api.nvim_get_current_win() == tree_win,
  "after closing the file, focus stays on tree or AI"
)

for _, session in ipairs(ai._state.ai.sessions) do
  if session.job_id then
    vim.fn.jobstop(session.job_id)
  end
end

print("ai_layout_spec: ok")
