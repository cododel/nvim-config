local panel_filetypes = {
  codex_terminal = true,
  project_terminal = true,
  NvimTree = true,
}

local function has_editor_context()
  return not panel_filetypes[vim.bo.filetype]
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    'nvim-tree/nvim-web-devicons'
  },
  opts = {
    options = {
      theme = 'auto',
      globalstatus = true,
      component_separators = { left = '', right = '' },
      section_separators = { left = '', right = '' },
    },
    sections = {
      lualine_a = { 'mode' },
      lualine_b = { 'branch', 'diff', 'diagnostics' },
      lualine_c = { { 'filename', path = 1, cond = has_editor_context } },
      lualine_x = {
        {
          function()
            local msg = 'No LSP'
            local buf_ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if next(clients) == nil then
              return msg
            end
            for _, client in ipairs(clients) do
              local filetypes = client.config.filetypes
              if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
                return client.name
              end
            end
            return msg
          end,
          icon = ' LSP:',
          color = { fg = '#ffffff', gui = 'bold' },
          cond = has_editor_context,
        },
      },
      lualine_y = { 'filetype' },
      lualine_z = { 'progress', 'location' }
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { 'filename' },
      lualine_x = { 'location' },
      lualine_y = {},
      lualine_z = {}
    },
    tabline = {},
    extensions = {}
  }
}
