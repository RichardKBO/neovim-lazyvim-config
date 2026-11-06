-- Carregar filtros modulares
local filtros = require("config.snacks.filters")

-- Acao modular de criacao de arquivos
local explorer_add = require("config.snacks.explorer_add")

-- Filtros exclusivos do Picker
-- Preservar os filtros existentes de C++, C#, Python e Rust
local filtros_picker = vim.deepcopy(filtros.exclude)

vim.list_extend(filtros_picker, {
  -- Dependencias JavaScript e TypeScript
  "node_modules",
  "**/node_modules",
  "**/node_modules/**",

  -- Diretorios de compilacao
  "dist",
  "**/dist",
  "**/dist/**",
  "build",
  "**/build",
  "**/build/**",

  -- Relatorios de cobertura
  "coverage",
  "**/coverage",
  "**/coverage/**",

  -- Cache de frameworks
  ".next",
  "**/.next",
  "**/.next/**",

  -- Metadados internos do Git
  ".git",
  "**/.git",
  "**/.git/**",
})

return {
  {
    "folke/snacks.nvim",

    opts = {
      -- Dashboard original do LazyVim
      dashboard = {
        enabled = true,
      },

      -- Configuracoes do Picker e Explorer
      picker = {
        sources = {
          -- Pesquisa de arquivos
          files = {
            exclude = vim.deepcopy(filtros_picker),
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
