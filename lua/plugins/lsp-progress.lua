-- ========================================
-- LSP PROGRESS - INTEGRACAO GLOBAL
-- Issue #25
-- ========================================

return {
  {
    "linrongbin16/lsp-progress.nvim",
    lazy = false,

    config = function()
      require("lsp-progress").setup()

      local grupo = vim.api.nvim_create_augroup(
        "LspProgressStatusline",
        { clear = true }
      )

      vim.api.nvim_create_autocmd("User", {
        group = grupo,
        pattern = "LspProgressStatusUpdated",
        callback = function()
          vim.cmd("redrawstatus")
        end,
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",

    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, {
        function()
          local ok, progresso = pcall(require, "lsp-progress")

          if not ok then
            return ""
          end

          return progresso.progress()
        end,
      })
    end,
  },

  {
    "folke/noice.nvim",

    opts = {
      lsp = {
        progress = {
          enabled = false,
        },
      },
    },
  },
}
