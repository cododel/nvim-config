local function format_hint(hint)
  hint = string.gsub(hint, "(_._:?)", " %1 ")
  hint = string.gsub(hint, ":  ([^%s]+)", ": %1 ")
  return hint
end

local function windows(Hydra)
  local cmd = require('hydra.keymap-util').cmd
  local map = vim.api.nvim_set_keymap

  map("n", "<C-w>", "false", { noremap = true, silent = true })
  Hydra({
    mode = "n",
    body = "<C-w>",
    heads = {
      -- Move focus
      { "h",     "<C-w>h" },
      { "j",     "<C-w>j" },
      { "k",     "<C-w>k" },
      { "l",     "<C-w>l" },
      -- Move window
      { "H",     "<Cmd>WinShift left<CR>" },
      { "J",     "<Cmd>WinShift down<CR>" },
      { "K",     "<Cmd>WinShift up<CR>" },
      { "L",     "<Cmd>WinShift right<CR>" },
      -- Split
      { "s",     ":split<CR>" },
      { "v",     ":vsplit<CR>" },
      -- Size
      { "+",     "<C-w>+" },
      { "-",     "<C-w>-" },
      { ">",     "2<C-w>>" },
      { "<",     "2<C-w><" },
      { "=",     "<C-w>=",                 { desc = "Equalize" } },
      --
      { 'w',     cmd ':bd<CR>:bp<CR>',            { desc = "Close Tab" } },
      { "<Esc>", nil,                      { exit = true } }
    },
    hint = format_hint [[
^  Move focus   |  Move window  |      Split       |      Size      ^
^---------------|---------------|------------------|----------------^
^               |               |                  |    Vertical    ^
^      _k_      |      _K_      | _s_: Horizontal  |  _-_      _+_  ^
^  _h_     _l_  |  _H_     _L_  |                  |                ^
^      _j_      |      _J_      | _v_: Vertical    |   Horizontal   ^
^               |               |                  |  _<_      _>_  ^
^-------------------------------------------------------------------^
]],
    config = {
      timeout = 4000,
      invoke_on_body = false,
      hint = {
        type = "window",
        position = "bottom-right",
        float_opts = {
          border = "rounded",
        },
      }
    },
    desc = "Window management"
  })
end


local function telescope(Hydra)
  local cmd = require('hydra.keymap-util').cmd
  Hydra({
    name = 'Telescope',
    hint = [[
  _f_:  files                                        ^
  _o_:  old files          _g_: live grep            ^
  _bb_: buffers contents   _/_: search in file       ^
  _bn_: buffers by names   _y_: clipboard registers  ^
                                                     ^
  _r_: resume              _u_: undotree             ^
  _h_: vim help            _c_: execute command      ^
  _k_: keymaps             _;_: commands history     ^
  _O_: options             _?_: search history       ^
                                                     ^
  _<Enter>_: Telescope             _<Esc>_           ^
]],
    config = {
      color = 'teal',
      invoke_on_body = true,
      hint = {
        type = 'window',
        position = 'middle',
        float_opts = {
          border = "rounded",
        },
      },
    },
    mode = 'n',
    body = '<F4>',
    heads = {
      { 'f', cmd 'Telescope find_files' },
      { 'g', cmd 'Telescope live_grep' },
      { 'o', cmd 'Telescope oldfiles', {
        desc =
        'recently opened files'
      } },
      { 'h', cmd 'Telescope help_tags', {
        desc =
        'vim help'
      } },
      { 'k',  cmd 'Telescope keymaps' },
      { 'O',  cmd 'Telescope vim_options' },
      { 'r',  cmd 'Telescope resume' },
      { 'bb', cmd 'lua require("telescope.builtin").live_grep({grep_open_files=true})' },
      { 'bn', cmd 'Telescope buffers' },
      { '/', cmd 'Telescope current_buffer_fuzzy_find', {
        desc =
        'search in file'
      } },
      { '?', cmd 'Telescope search_history', {
        desc =
        'search history'
      } },
      { ';', cmd 'Telescope command_history', {
        desc =
        'command-line history'
      } },
      { 'c', cmd 'Telescope commands',                  { desc = 'execute command' } },
      { 'u', cmd 'silent! %foldopen! | UndotreeToggle', { desc = 'undotree' } },
      { 'y', cmd 'Telescope registers',                 { desc = 'clipboard register' } },
      { '<Enter>', cmd 'Telescope', {
        exit = true,
        desc = 'list all pickers'
      } },
      { '<Esc>', nil, { exit = true, nowait = true } },
    }
  })
end

return {
  "nvimtools/hydra.nvim",
  -- cond = false,
  config = function()
    local Hydra = require("hydra")

    windows(Hydra)
    telescope(Hydra)
    return true
  end
}
