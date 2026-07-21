local calls = {}

local builtin = setmetatable({}, {
  __index = function(_, picker_name)
    return function(opts)
      calls[#calls + 1] = {
        name = picker_name,
        opts = opts,
      }
    end
  end,
})

package.preload["telescope.builtin"] = function()
  return builtin
end

package.preload["telescope.actions"] = function()
  return {
    close = function() end,
    move_selection_next = function() end,
    move_selection_previous = function() end,
  }
end

local palette = dofile(vim.fn.getcwd() .. "/lua/cododel/palette.lua")
palette.setup({ builtin = builtin })

local function mapping(lhs, mode)
  for _, item in ipairs(vim.api.nvim_get_keymap(mode or "n")) do
    if item.lhs == lhs then
      return item.callback
    end
  end
  error("mapping not found: " .. lhs)
end

local function has_value(items, expected)
  for _, value in ipairs(items) do
    if value == expected then
      return true
    end
  end

  return false
end

mapping("<D-p>")()
assert(calls[1].name == "find_files", "Cmd+P opens file search by default")
assert(calls[1].opts.layout_strategy == "center", "file search uses a centered popup")
local find_command = calls[1].opts.find_command(calls[1].opts)
assert(find_command[1] == "rg", "file search uses ripgrep")
assert(has_value(find_command, "!.git/**"), "file search excludes .git")
assert(
  has_value(find_command, "!**/*.{7z,a,apk,avi,avif,bin,bmp,class,crx,deb,dmg,dll,dylib,exe,flac,gif,gz,heic,ico,ipa,iso,jar,jpeg,jpg,lz4,m4a,m4v,mkv,mov,mp3,mp4,msi,o,otf,pak,pdf,png,psd,pyc,rar,rpm,so,sqlite,sqlite3,swf,tar,tiff,ttf,wav,wasm,webm,webp,woff,woff2,xz,zip,zst}"),
  "file search excludes binary extensions"
)
for _, mode in ipairs({ "n", "i", "t" }) do
  assert(mapping("<D-з>", mode) == mapping("<D-p>", mode), "Cmd+з follows Cmd+P in " .. mode)
end

mapping("<D-F>")()
assert(calls[2].name == "live_grep", "Cmd+Shift+F opens project content search")
assert(calls[2].opts.layout_strategy == "center", "content search uses the palette popup")
for _, mode in ipairs({ "n", "i", "t" }) do
  assert(
    mapping("<D-А>", mode) == mapping("<D-F>", mode),
    "Cmd+Shift+А follows Cmd+Shift+F in " .. mode
  )
  assert(
    vim.fn.maparg("<S-D-a>", mode, false, true).callback == mapping("<D-F>", mode),
    "terminal Cmd+Shift+F keycode opens content search in " .. mode
  )
end
mapping("<Esc>[113~", "t")()
assert(calls[3].name == "live_grep", "terminal CSI Cmd+Shift+F opens content search")

local picker_mappings = {}
local map = function(mode, lhs, rhs, opts)
  picker_mappings[mode .. lhs] = {
    callback = rhs,
    opts = opts,
  }
end

local attach_mappings = calls[1].opts.attach_mappings
assert(attach_mappings(101, map) == true, "palette keeps Telescope mappings")
assert(picker_mappings["i<Tab>"].callback == require("telescope.actions").move_selection_next, "Tab moves without selecting multiple files")
assert(picker_mappings["n<Tab>"].callback == require("telescope.actions").move_selection_next, "Normal-mode Tab moves without selecting multiple files")
assert(picker_mappings["i<S-Tab>"].callback == require("telescope.actions").move_selection_previous, "Shift+Tab moves up without selecting multiple files")
assert(picker_mappings["n<S-Tab>"].callback == require("telescope.actions").move_selection_previous, "Normal-mode Shift+Tab moves up without selecting multiple files")
assert(picker_mappings["i<Esc>"].callback == require("telescope.actions").close, "Escape closes the palette from insert mode")
assert(picker_mappings["i<C-[>"].callback == require("telescope.actions").close, "Ctrl-[ closes the palette")
assert(type(picker_mappings["ijj"].callback) == "function", "jj remains available as search input")
assert(picker_mappings["ijj"].callback ~= require("telescope.actions").close, "jj does not close the palette")
assert(picker_mappings["i<Esc>"].opts.nowait == true, "Escape does not wait for a terminal sequence")
picker_mappings["i<C-g>"].callback()
vim.wait(100, function()
  return #calls >= 4
end)

assert(calls[4].name == "live_grep", "Ctrl+G switches to live grep")
assert(calls[4].opts.prompt_title == "Grep project", "grep mode has a visible title")

print("palette_spec: ok")
