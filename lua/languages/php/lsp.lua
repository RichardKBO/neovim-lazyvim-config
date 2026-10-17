-- ========================================
-- PHP - INTELEPHENSE LSP
-- ========================================
-- Servidor principal: Intelephense
-- Instalado via npm, gerenciado pelo mise.
-- Nao utiliza caminhos ou versoes fixas.

local M = {}

function M.setup()
  vim.lsp.config("intelephense", {
    cmd = {
      "intelephense",
      "--stdio",
    },

    filetypes = {
      "php",
    },

    root_markers = {
      "composer.json",
      ".git",
    },
  })

  vim.lsp.enable("intelephense")
end

return M
