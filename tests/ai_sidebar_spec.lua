package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function()
        return false
      end,
    },
  }
end

package.preload["nvim-drawer"] = function()
  local module = {}

  function module.setup() end

  function module.find_instance_for_winid()
    return nil
  end

  function module.create_drawer(options)
    local instance = {
      winid = -1,
    }

    function instance.get_winid()
      return instance.winid
    end

    function instance.is_focused()
      return instance.winid ~= -1
        and vim.api.nvim_get_current_win() == instance.winid
    end

    function instance.open(open_options)
      local bufnr = vim.api.nvim_create_buf(false, true)
      if instance.winid == -1 then
        instance.winid = vim.api.nvim_open_win(bufnr, false, {
          relative = "editor",
          row = 0,
          col = 0,
          width = 20,
          height = 8,
          style = "minimal",
        })
      else
        vim.api.nvim_win_set_buf(instance.winid, bufnr)
      end

      vim.api.nvim_win_call(instance.winid, function()
        if options.on_did_open_buffer then
          options.on_did_open_buffer({
            instance = instance,
            winid = instance.winid,
            bufnr = bufnr,
          })
        end

        if options.on_did_create_buffer then
          options.on_did_create_buffer({
            instance = instance,
            winid = instance.winid,
            bufnr = bufnr,
          })
        end
      end)

      if open_options and open_options.focus then
        vim.api.nvim_set_current_win(instance.winid)
      end

      vim.api.nvim_win_call(instance.winid, function()
        if options.on_did_open then
          options.on_did_open({
            instance = instance,
            winid = instance.winid,
            bufnr = bufnr,
          })
        end
      end)
    end

    function instance.focus()
      vim.api.nvim_set_current_win(instance.winid)
    end

    function instance.close()
      if instance.winid ~= -1 and vim.api.nvim_win_is_valid(instance.winid) then
        vim.api.nvim_win_close(instance.winid, true)
      end
      instance.winid = -1
    end

    function instance.go() end
    function instance.focus_or_toggle() end

    return instance
  end

  return module
end

local ai = dofile(vim.fn.getcwd() .. "/lua/cododel/ai_sidebar.lua")
ai.setup({ codex_cmd = { "sleep", "100" } })

local state = ai._state
local drawer = state.ai_drawer
for _ = 1, 4 do
  drawer.open({ mode = "new", focus = true })
end

assert(#state.ai.sessions == 4, "creates four Codex sessions")
state.ai.active = 3

local removed_bufnr = state.ai.sessions[1].bufnr
vim.api.nvim_buf_delete(removed_bufnr, { force = true })

assert(#state.ai.sessions == 3, "removes the closed session")
assert(
  state.ai.active == 2,
  "keeps the same active session after an earlier session exits"
)

for _, session in ipairs(state.ai.sessions) do
  if session.job_id then
    vim.fn.jobstop(session.job_id)
  end
end

print("ai_sidebar_spec: ok")
