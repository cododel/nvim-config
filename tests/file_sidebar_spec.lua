local calls = {}
local current_node

package.preload["nvim-tree.api"] = function()
  return {
    tree = {
      is_tree_buf = function()
        return true
      end,
      get_node_under_cursor = function()
        return current_node
      end,
      change_root_to_node = function(node)
        calls.enter = node
      end,
    },
    node = {
      expand = function(node)
        calls.recursive_expand = (calls.recursive_expand or 0) + 1
        node.expanded = true
      end,
      open = {
        edit = function(node)
          if node.type == "file" then
            calls.open = node
          else
            calls.expand = (calls.expand or 0) + 1
            node.expanded = true
          end
        end,
        preview = function(node)
          calls.preview = node
        end,
      },
      navigate = {
        parent_close = function(node)
          calls.collapse = node
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

local directory = { type = "directory", absolute_path = "/tmp/project/src", nodes = {} }
mapping("h")(directory)
assert(calls.collapse == directory, "h collapses the selected directory")

current_node = directory
mapping("l")()
mapping("l")()
assert(directory.expanded, "l expands the selected directory")
assert(calls.expand == 2, "repeated l does not collapse the directory")
assert(calls.recursive_expand == nil, "l does not recursively expand the directory")

current_node = { type = "file", absolute_path = "/tmp/project/README.md" }
mapping("l")()
assert(calls.preview == current_node, "l previews the selected file")
assert(calls.expand == 2, "l does not expand a selected file")

current_node = directory
mapping("<CR>")()
assert(calls.enter == directory, "Enter changes root to the selected directory")

local file = { type = "file", absolute_path = "/tmp/project/README.md" }
current_node = file
mapping("<CR>")()
assert(calls.open == file, "Enter opens the selected file")

current_node = directory
assert(
  file_sidebar.get_ai_cwd() == directory.absolute_path,
  "selected directory is used as the AI cwd"
)

current_node = { type = "file", absolute_path = "/tmp/project/src/main.lua" }
assert(
  file_sidebar.get_ai_cwd() == "/tmp/project/src",
  "selected file uses its parent directory as the AI cwd"
)

current_node = nil
assert(file_sidebar.get_ai_cwd() == nil, "missing tree node keeps the AI cwd unset")

print("file_sidebar_spec: ok")
