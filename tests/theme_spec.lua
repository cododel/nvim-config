local setup_options
local colorscheme

package.preload["tokyonight"] = function()
  return {
    setup = function(options)
      setup_options = options
    end,
  }
end

local original_cmd = vim.cmd
vim.cmd = {
  colorscheme = function(name)
    colorscheme = name
  end,
}

local plugin = dofile(vim.fn.getcwd() .. "/lua/plugins/theme.lua")
assert(plugin[1] == "folke/tokyonight.nvim", "uses TokyoNight")
assert(plugin.opts.style == "moon", "uses TokyoNight Moon")
assert(plugin.opts.transparent, "keeps the Ghostty background visible")
assert(plugin.opts.terminal_colors == false, "preserves terminal ANSI colors")
assert(plugin.opts.styles.sidebars == "transparent", "keeps sidebars transparent")
assert(plugin.opts.styles.floats == "transparent", "keeps floats transparent")
plugin.config(nil, plugin.opts)
assert(setup_options == plugin.opts, "configures TokyoNight before loading it")
assert(colorscheme == "tokyonight-moon", "loads TokyoNight Moon")

vim.cmd = original_cmd
print("theme_spec: ok")
