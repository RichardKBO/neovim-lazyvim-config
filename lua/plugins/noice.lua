-- ========================================
-- NOICE - JANELAS DE DOCUMENTACAO
-- ========================================

return {
  {
    "folke/noice.nvim",

    opts = {
      lsp = {
        signature = {
          enabled = true,

          -- Preservar ajuda automatica.
          auto_open = {
            enabled = true,
          },

          -- Limitar somente a janela
          -- de assinatura dos metodos.
          opts = {
            size = {
              width = "auto",
              height = "auto",
              max_width = 55,
              max_height = 10,
            },
          },
        },
      },
    },
  },
}
