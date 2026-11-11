-- ========================================
-- MUON LSP - MESON BUILD
-- ========================================
-- Servidor de linguagem para arquivos Meson.
--
-- O Muon esta instalado no HDD e disponivel
-- pelo PATH atraves de ~/.local/bin/muon.
--
-- Reutiliza a configuracao nativa do
-- nvim-lspconfig:
--   muon analyze lsp
--   muon analyze root-for
--
-- Nao utiliza o Mason para instalar o Muon.
-- ========================================

return {
  {
    "neovim/nvim-lspconfig",

    opts = {
      servers = {
        muon = {
          mason = false,
        },
      },
    },
  },
}
