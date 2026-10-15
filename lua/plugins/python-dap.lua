-- Carregador do debugger Python
-- Configuracao principal em languages/python/dap.lua
-- Utiliza nvim-dap + debugpy

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      -- Preservar as opcoes compartilhadas do nvim-dap.
      opts = opts or {}

      -- Carregar o debugger especifico do Python.
      require("languages.python.dap").setup()

      return opts
    end,
  },
}
