return {
  -- CMP completion engine
  "hrsh7th/nvim-cmp",
  dependencies = {
    -- "onsails/lspkind-nvim",     -- Icons on the popups
    "zbirenbaum/copilot.lua",
    "neovim/nvim-lspconfig",
    "hrsh7th/cmp-nvim-lsp", -- LSP source for nvim-cmp
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",     -- File path completion
    'hrsh7th/cmp-cmdline',

    -- Snippets
    {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      dependencies = { "rafamadriz/friendly-snippets" },
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
    "saadparwaiz1/cmp_luasnip", -- Snippets source
  },

  opts = function()
    local cmp = require("cmp")         -- The complete engine
    local luasnip = require("luasnip") -- The snippet engine
    local compare = require("cmp.config.compare")

    -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
    cmp.setup.cmdline({ '/', '?' }, {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = 'buffer' }
      },
    })

    -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
    cmp.setup.cmdline(':', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = 'path' }
      }, {
        { name = 'cmdline' }
      }),
      matching = { disallow_symbol_nonprefix_matching = false },
    })



    return {
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = {
        -- -- Navigate the dropdown list snippet
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ["<C-Space>"] = cmp.mapping.complete(),
        -- ["<C-e>"] = cmp.mapping.close(),

        -- Enter select the item
        ["<CR>"] = cmp.mapping.confirm({
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        }),

        -- Use <Tab> as the automplete trigger
        ["<Tab>"] = function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end,
        ["<S-Tab>"] = function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end,
      },

      -- Where to look for auto-complete items.
      sources = {
        { name = "luasnip",  priority = 10 },
        { name = "nvim_lsp", priority = 8 },
        { name = "copilot",  priority = 8 },
        { name = "buffer",   priority = 7 },
        { name = 'path' },
        --
        -- { name = "nvim_lsp" },
        -- { name = "luasnip" },
        -- { name = "buffer" },
        -- { name = "path",    group_index = 2 },
        -- { name = "copilot", group_index = 2 },
      },
      sorting = {
        priority_weight = 1.0,
        comparators = {
          -- compare.score_offset, -- not good at all
          compare.offset,
          compare.exact,
          compare.recently_used,
          compare.locality,
          compare.score, -- based on :  score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)
          -- https://github.com/lukas-reineke/cmp-under-comparator
          function(entry1, entry2)
            local _, entry1_under = entry1.completion_item.label:find("^_+")
            local _, entry2_under = entry2.completion_item.label:find("^_+")
            entry1_under = entry1_under or 0
            entry2_under = entry2_under or 0
            if entry1_under > entry2_under then
              return false
            elseif entry1_under < entry2_under then
              return true
            end
          end,

          compare.order,
          -- compare.scopes, -- what?
          compare.sort_text,
          -- compare.kind,
          -- compare.length, -- useless
        },
      },
    }
  end
}
