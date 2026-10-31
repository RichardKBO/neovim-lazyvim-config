-- Carregar filtros modulares
local filtros = require("config.snacks.filters")

-- Acao modular de criacao de arquivos
local explorer_add = require("config.snacks.explorer_add")

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

            -- Preservar a tecla "a" com automacao modular
            actions = {
              explorer_add = explorer_add.adicionar,
            },
          },
        },
      },
    },
  },
}
