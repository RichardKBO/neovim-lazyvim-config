-- ========================================
-- LUALINE - COSMICINK + LEGO
-- Cores dinamicas conforme o tema ativo
-- ========================================

-- Obter cores do tema atual.
local function cor(grupo, campo, alternativa)
  local ok, destaque = pcall(vim.api.nvim_get_hl, 0, { name = grupo, link = false })

  if ok and type(destaque[campo]) == "number" then
    return string.format("#%06x", destaque[campo])
  end

  return alternativa
end

-- ========================================
-- COR DO INDICADOR DE MODO
-- ========================================

local function cor_modo()
  local modo = vim.api.nvim_get_mode().mode

  if modo:match("^i") then
    return cor("String", "fg", "#00e676")
  elseif modo:match("^[vV\22]") then
    return cor("Constant", "fg", "#ff3344")
  elseif modo:match("^R") then
    return cor("DiagnosticError", "fg", "#ff7733")
  elseif modo:match("^c") then
    return cor("Keyword", "fg", "#d360aa")
  end

  return cor("Function", "fg", "#00bcd4")
end

-- ========================================
-- CONFIGURACAO DA LUALINE
-- ========================================

return {
  {
    "nvim-lualine/lualine.nvim",

    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.sections = opts.sections or {}

      -- ====================================
      -- TEMA E ICONES
      -- ====================================

      -- Acompanhar o tema ativo do Neovim.
      opts.options.theme = "auto"
      opts.options.icons_enabled = true

      -- ====================================
      -- SEPARADORES LEGO
      -- Powerline Extra Symbols
      -- ====================================

      -- Sem separadores extras entre
      -- componentes da mesma secao.
      opts.options.component_separators = ""

      -- Separadores LEGO entre secoes.
      opts.options.section_separators = {
        left = "",
        right = "",
      }

      -- ====================================
      -- MODO
      -- ====================================

      opts.sections.lualine_a = {
        {
          "mode",

          fmt = function(texto)
            return texto:sub(1, 1)
          end,

          color = function()
            return {
              fg = cor("Normal", "bg", "#16181b"),
              bg = cor_modo(),
              gui = "bold",
            }
          end,

          -- Separador LEGO do modo.
          separator = {
            right = "",
          },

          padding = {
            left = 1,
            right = 1,
          },
        },
      }

      -- ====================================
      -- AREA CENTRAL ESQUERDA
      -- ====================================

      opts.sections.lualine_c = opts.sections.lualine_c or {}

      -- Pasta do projeto atual.
      table.insert(opts.sections.lualine_c, 1, {
        function()
          return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        end,

        icon = "󰉋",

        color = function()
          return {
            fg = cor_modo(),
            gui = "bold",
          }
        end,
      })

      -- ====================================
      -- AREA CENTRAL DIREITA
      -- ====================================

      opts.sections.lualine_x = opts.sections.lualine_x or {}

      -- Preservar os componentes existentes,
      -- incluindo a statusline do Java.

      -- Nenhuma decoracao cosmica adicional.

      -- ====================================
      -- INFORMACOES PRESERVADAS
      -- ====================================

      -- lualine_b:
      -- Git e diagnosticos.

      -- lualine_c:
      -- Projeto, arquivo e componentes atuais.

      -- lualine_x:
      -- Java, LSP e indicadores existentes.

      -- lualine_y:
      -- Progresso no arquivo.

      -- lualine_z:
      -- Linha, coluna e demais informacoes.
    end,
  },
}
