-- ========================================
-- DIAGNOSTICOS GLOBAIS DA IDE
-- Todas as linguagens com suporte LSP
-- ========================================

return {
  {
    "neovim/nvim-lspconfig",

    opts = {
      diagnostics = {
        -- Atualizar diagnosticos durante a digitacao.
        update_in_insert = true,

        -- Exibir erros e avisos junto ao codigo.
        virtual_text = {
          prefix = "●",
          spacing = 2,
          source = "if_many",
        },

        -- Sublinhado dos problemas.
        underline = true,

        -- Manter os icones de diagnostico.
        signs = true,

        -- Preservar a ordenacao por severidade.
        severity_sort = true,

        -- Nao utilizar linhas virtuais adicionais.
        virtual_lines = false,
      },
    },
  },
}
