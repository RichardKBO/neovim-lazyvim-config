-- ========================================
-- SWIFT - INTEGRACAO NVIM-DAP
-- Configuracao principal em languages/swift/dap.lua
-- Utiliza LLDB-DAP oficial + SwiftPM
-- ========================================

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      -- Preservar configuracoes compartilhadas.
      opts = opts or {}

      -- Registrar o debugger especifico do Swift.
      require("languages.swift.dap").setup()

      return opts
    end,
  },
}
