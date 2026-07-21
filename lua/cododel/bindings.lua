local M = {}

-- macOS's Russian input source is based on the physical US keyboard. The
-- punctuation is intentionally included: it is part of the same layout
-- translation and keeps Normal-mode commands consistent across the board.
M.layout = {
  russian_to_latin = {
    ["]"] = "`",
    ["["] = "~",
    ["й"] = "q",
    ["ц"] = "w",
    ["у"] = "e",
    ["к"] = "r",
    ["е"] = "t",
    ["н"] = "y",
    ["г"] = "u",
    ["ш"] = "i",
    ["щ"] = "o",
    ["з"] = "p",
    ["х"] = "[",
    ["ъ"] = "]",
    ["ф"] = "a",
    ["ы"] = "s",
    ["в"] = "d",
    ["а"] = "f",
    ["п"] = "g",
    ["р"] = "h",
    ["о"] = "j",
    ["л"] = "k",
    ["д"] = "l",
    ["ж"] = ";",
    ["э"] = "'",
    ["я"] = "z",
    ["ч"] = "x",
    ["с"] = "c",
    ["м"] = "v",
    ["и"] = "b",
    ["т"] = "n",
    ["ь"] = "m",
    ["б"] = ",",
    ["ю"] = ".",
    ["/"] = "/",
    ["Й"] = "Q",
    ["Ц"] = "W",
    ["У"] = "E",
    ["К"] = "R",
    ["Е"] = "T",
    ["Н"] = "Y",
    ["Г"] = "U",
    ["Ш"] = "I",
    ["Щ"] = "O",
    ["З"] = "P",
    ["Х"] = "{",
    ["Ъ"] = "}",
    ["Ф"] = "A",
    ["Ы"] = "S",
    ["В"] = "D",
    ["А"] = "F",
    ["П"] = "G",
    ["Р"] = "H",
    ["О"] = "J",
    ["Л"] = "K",
    ["Д"] = "L",
    ["Ж"] = ":",
    ["Э"] = '"',
    ["Я"] = "Z",
    ["Ч"] = "X",
    ["С"] = "C",
    ["М"] = "V",
    ["И"] = "B",
    ["Т"] = "N",
    ["Ь"] = "M",
    ["Б"] = "<",
    ["Ю"] = ">",
    ["?"] = "?",
  },
}

M.shortcuts = {
  pane_left = {
    latin = "<D-h>",
    russian = "<D-р>",
    terminal = "<Esc>[102~",
  },
  pane_down = {
    latin = "<D-j>",
    russian = "<D-о>",
    terminal = "<Esc>[98~",
  },
  pane_up = {
    latin = "<D-k>",
    russian = "<D-л>",
    terminal = "<Esc>[101~",
  },
  pane_right = {
    latin = "<D-l>",
    russian = "<D-д>",
    terminal = "<Esc>[99~",
  },
  file_palette = {
    latin = "<D-p>",
    russian = "<D-з>",
    terminal = "<Esc>[112~",
  },
  content_search = {
    latin = { "<D-F>", "<S-D-a>", "<D-A>" },
    russian = "<D-А>",
    terminal = "<Esc>[113~",
  },
  tree_hidden = {
    latin = "<D-S-.>",
    russian = "<D-Ю>",
    terminal = "<Esc>[114~",
  },
  maximize_pane = {
    latin = "<S-Esc>",
    terminal = "<Esc>[27;2u",
  },
  git_review = {
    latin = "<C-S-g>",
    russian = "<C-S-п>",
  },
}

local command_aliases = {
  { lhs = "ив", rhs = "bd" },
  { lhs = "ит", rhs = "bn" },
  { lhs = "й", rhs = "q" },
  { lhs = "йф", rhs = "qa" },
  { lhs = "ц", rhs = "w" },
  { lhs = "цй", rhs = "wq" },
  { lhs = "цйф", rhs = "wqa" },
}

local initialized = false

local function as_list(value)
  if value == nil then
    return {}
  end

  if type(value) == "table" then
    return value
  end

  return { value }
end

function M.aliases(spec)
  local aliases = {}
  local seen = {}

  for _, field in ipairs({ "latin", "russian", "terminal" }) do
    for _, lhs in ipairs(as_list(spec[field])) do
      if not seen[lhs] then
        seen[lhs] = true
        aliases[#aliases + 1] = lhs
      end
    end
  end

  return aliases
end

function M.set(modes, spec, rhs, opts)
  for _, lhs in ipairs(M.aliases(spec)) do
    vim.keymap.set(modes, lhs, rhs, opts)
  end
end

function M.add(mapping, spec, value)
  for _, lhs in ipairs(M.aliases(spec)) do
    mapping[lhs] = value
  end
end

local function setup_layout_maps()
  local opts = {
    remap = true,
    silent = true,
    desc = "Use the current Russian keyboard layout for Vim commands",
  }

  local modes = { "n", "x", "s", "o" }
  for russian, latin in pairs(M.layout.russian_to_latin) do
    if russian ~= latin then
      vim.keymap.set(modes, russian, latin, opts)
    end
  end
end

local function setup_command_aliases()
  for _, alias in ipairs(command_aliases) do
    vim.keymap.set("c", alias.lhs, function()
      if vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == alias.lhs then
        return alias.rhs
      end

      return alias.lhs
    end, {
      expr = true,
      silent = true,
      desc = "Russian Ex command alias",
    })
  end
end

function M.setup()
  if initialized then
    return
  end

  initialized = true
  setup_layout_maps()
  setup_command_aliases()
end

M.command_aliases = command_aliases

return M
