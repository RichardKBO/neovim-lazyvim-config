-- Carregador do Roslyn LSP para C#
-- Configuração principal em languages/csharp/init.lua

return {
  {
    "seblyng/roslyn.nvim",

    ft = { "cs" },

    opts = {
      args = {
        "--stdio",
      },
    },

    config = function(_, opts)
      -- Inicializar o plugin Roslyn.
      require("roslyn").setup(opts)

      -- Carregar a configuração modular do C#.
      require("languages.csharp").setup()
    end,
  },
}
