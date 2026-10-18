-- ========================================
-- SWIFT - SOURCEKIT-LSP
-- Toolchain oficial gerenciada pelo Swiftly
-- ========================================

local M = {}

function M.setup()
  vim.lsp.config("sourcekit", {
    cmd = { "sourcekit-lsp" },

    filetypes = {
      "swift",
    },

    root_markers = {
      "Package.swift",
      ".git",
    },
  })

  vim.lsp.enable("sourcekit")
end

return M
