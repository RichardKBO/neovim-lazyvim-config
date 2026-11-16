-- Carregador do Roslyn LSP para C#
-- Configuração principal em languages/csharp/init.lua

return {
  {
    "RichardKBO/roslyn.nvim",
    commit = "d75930cc63bd5e3fb0cc9961965351e554e772f5",
    pin = true,

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
