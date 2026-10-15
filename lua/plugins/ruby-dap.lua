-- Carregador do debugger Ruby
-- Configuracao principal em languages/ruby/dap.lua

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      -- Preservar as opcoes compartilhadas.
      opts = opts or {}

      -- Carregar o debugger especifico do Ruby.
      require("languages.ruby.dap").setup()

      return opts
    end,
  },
}
