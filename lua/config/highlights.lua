local transparent_groups = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "EndOfBuffer",
  "SignColumn",
}

local function clear_backgrounds()
  for _, group in ipairs(transparent_groups) do
    local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
    highlight.bg = "NONE"
    highlight.ctermbg = "NONE"
    vim.api.nvim_set_hl(0, group, highlight)
  end
end

clear_backgrounds()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("CododelTransparentBackground", { clear = true }),
  callback = clear_backgrounds,
})
