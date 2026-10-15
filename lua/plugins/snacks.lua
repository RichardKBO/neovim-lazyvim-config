-- Carregar filtros modulares
local filtros = require("config.snacks.filters")

return {
  {
    "folke/snacks.nvim",

    opts = {
      -- Dashboard do LazyVim
      dashboard = {
        enabled = true,
      },

      -- Configuracoes do Picker e Explorer
      picker = {
        sources = {
          -- Pesquisa de arquivos
          files = {
            exclude = vim.deepcopy(filtros.exclude),
          },

          -- Explorador lateral
          explorer = {
            exclude = vim.deepcopy(filtros.exclude),
          },
        },
      },
    },
  },
}
