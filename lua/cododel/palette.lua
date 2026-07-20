local M = {}

local state = {
  initialized = false,
  builtin = nil,
}

local modes = {
  files = {
    picker = "find_files",
    title = "Files",
  },
  grep = {
    picker = "live_grep",
    title = "Grep project",
  },
  buffers = {
    picker = "buffers",
    title = "Open buffers",
  },
  recent = {
    picker = "oldfiles",
    title = "Recent files",
  },
  commands = {
    picker = "commands",
    title = "Commands",
  },
  keymaps = {
    picker = "keymaps",
    title = "Keymaps",
  },
}

local mode_keys = {
  ["<C-1>"] = "files",
  ["<C-g>"] = "grep",
  ["<C-b>"] = "buffers",
  ["<C-o>"] = "recent",
  ["<C-;>"] = "commands",
  ["<C-y>"] = "keymaps",
}

local binary_extensions = {
  "7z",
  "a",
  "apk",
  "avi",
  "avif",
  "bin",
  "bmp",
  "class",
  "crx",
  "deb",
  "dmg",
  "dll",
  "dylib",
  "exe",
  "flac",
  "gif",
  "gz",
  "heic",
  "ico",
  "ipa",
  "iso",
  "jar",
  "jpeg",
  "jpg",
  "lz4",
  "m4a",
  "m4v",
  "mkv",
  "mov",
  "mp3",
  "mp4",
  "msi",
  "o",
  "otf",
  "pak",
  "pdf",
  "png",
  "psd",
  "pyc",
  "rar",
  "rpm",
  "so",
  "sqlite",
  "sqlite3",
  "swf",
  "tar",
  "tiff",
  "ttf",
  "wav",
  "wasm",
  "webm",
  "webp",
  "woff",
  "woff2",
  "xz",
  "zip",
  "zst",
}

local binary_glob = "!**/*.{" .. table.concat(binary_extensions, ",") .. "}"

local function file_find_command()
  return {
    "rg",
    "--files",
    "--color",
    "never",
    "--hidden",
    "--glob-case-insensitive",
    "--glob",
    "!.git/**",
    "--glob",
    binary_glob,
  }
end

local function layout_options()
  return {
    layout_strategy = "center",
    layout_config = {
      width = 0.82,
      height = 0.72,
    },
    sorting_strategy = "ascending",
  }
end

local function switch_mode(prompt_bufnr, mode)
  local actions = require("telescope.actions")
  actions.close(prompt_bufnr)

  vim.schedule(function()
    M.open(mode)
  end)
end

local function insert_literal_jj()
  vim.api.nvim_put({ "jj" }, "c", true, true)
end

local function attach_mappings(_, map)
  local actions = require("telescope.actions")
  local immediate = { nowait = true }

  map("i", "<Tab>", actions.move_selection_next, immediate)
  map("n", "<Tab>", actions.move_selection_next, immediate)
  map("i", "<Esc>", actions.close, immediate)
  map("i", "<C-[>", actions.close, immediate)
  map("i", "jj", insert_literal_jj, immediate)

  for lhs, mode in pairs(mode_keys) do
    map("i", lhs, function(prompt_bufnr)
      switch_mode(prompt_bufnr, mode)
    end)
    map("n", lhs, function(prompt_bufnr)
      switch_mode(prompt_bufnr, mode)
    end)
  end

  return true
end

local function picker_options(mode)
  local spec = assert(modes[mode], "unknown palette mode: " .. mode)
  local options = vim.tbl_extend("force", layout_options(), {
    prompt_title = spec.title,
    attach_mappings = attach_mappings,
  })

  if mode == "files" then
    options.find_command = file_find_command
  end

  return options
end

function M.open(mode)
  mode = mode or "files"
  local spec = assert(modes[mode], "unknown palette mode: " .. tostring(mode))
  local builtin = state.builtin or require("telescope.builtin")
  builtin[spec.picker](picker_options(mode))
end

local function create_commands()
  local commands = {
    CododelPalette = "files",
    CododelFiles = "files",
    CododelGrep = "grep",
    CododelBuffers = "buffers",
    CododelRecent = "recent",
    CododelCommands = "commands",
    CododelKeymaps = "keymaps",
  }

  for command_name, mode in pairs(commands) do
    vim.api.nvim_create_user_command(command_name, function()
      M.open(mode)
    end, { desc = "Open Cododel " .. modes[mode].title .. " picker" })
  end
end

function M.setup(options)
  if state.initialized then
    return
  end

  options = options or {}
  state.builtin = options.builtin
  state.initialized = true

  local keymap_options = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = "Open Cododel file palette",
  }

  local open_files = function()
    M.open("files")
  end

  local open_grep = function()
    M.open("grep")
  end

  vim.keymap.set({ "n", "i", "t" }, "<D-p>", open_files, keymap_options)
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[112~", open_files, keymap_options)
  vim.keymap.set({ "n", "i", "t" }, "<D-F>", open_grep, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = "Open Cododel content palette",
  })
  vim.keymap.set({ "n", "i", "t" }, "<Esc>[113~", open_grep, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = "Open Cododel content palette",
  })
  create_commands()
end

M._modes = modes
M._mode_keys = mode_keys
M._state = state

return M
