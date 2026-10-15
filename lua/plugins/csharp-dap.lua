-- Carregador do debugger C#
-- Configuração principal em languages/csharp/dap.lua

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      -- Preservar as opções compartilhadas do nvim-dap.
      opts = opts or {}

      -- Configurar o debugger específico do C#.
      require("languages.csharp.dap").setup()

      return opts
    end,
  },
}
