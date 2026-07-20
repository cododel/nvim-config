local calls = {}

package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function()
        return true
      end,
      change_root_to_node = function(node)
        calls.enter = node
      end,
    },
    node = {
      navigate = {
        parent_close = function(node)
          calls.collapse = node
        end,
      },
      open = {
        edit = function(node)
          calls.expand = node
        end,
      },
    },
  }
end

local file_sidebar = dofile(vim.fn.getcwd() .. "/lua/cododel/file_sidebar.lua")
file_sidebar.on_attach(0)

local function mapping(lhs)
  for _, item in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  error("mapping not found: " .. lhs)
end

local directory = { type = "directory", absolute_path = "/tmp/project/src" }
mapping("h")(directory)
assert(calls.collapse == directory, "h collapses the selected directory")

mapping("l")(directory)
assert(calls.expand == directory, "l expands the selected directory")

mapping("<CR>")(directory)
assert(calls.enter == directory, "Enter changes root to the selected directory")

print("file_sidebar_spec: ok")
