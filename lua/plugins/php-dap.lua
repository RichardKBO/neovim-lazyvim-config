-- ========================================
-- PHP - CARREGADOR DO DEBUGGER F8
-- ========================================
-- Integra o modulo PHP ao nvim-dap existente.

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      opts = opts or {}

      require("languages.php.dap").setup()

      return opts
    end,
  },
}
