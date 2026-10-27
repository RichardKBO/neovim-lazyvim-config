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
      -- KITTY: STATUSLINE TOTALMENTE TRANSPARENTE
      if vim.env.NVIM_STATUSLINE_STYLE == "bubbles_lego" then
        local texto = cor("Normal", "fg", "#d0d0d0")

        local cores_modo = {
          normal = cor("Function", "fg", "#80a0ff"),
          insert = cor("String", "fg", "#00e676"),
          visual = cor("Constant", "fg", "#d183e8"),
          replace = "#ff5189",
          command = "#e5c07b",
          terminal = "#79dac8",
          inactive = "#888888",
        }

        -- Remover o fundo de todas as secoes e modos.
        local tema = {}

        for modo, destaque in pairs(cores_modo) do
          tema[modo] = {}

          for _, secao in ipairs({ "a", "b", "c", "x", "y", "z" }) do
            tema[modo][secao] = {
              fg = secao == "a" and destaque or texto,
              bg = "NONE",
            }
          end
        end

        opts.options.theme = tema
        opts.options.component_separators = ""
        opts.options.section_separators = ""

        -- Preservar o indicador colorido do modo, sem fundo.
        opts.sections.lualine_a[1].color = function()
          return {
            fg = cor_modo(),
            bg = "NONE",
            gui = "bold",
          }
        end

        -- Componentes personalizados podem sobrescrever o tema.
        -- Preservar suas cores, mas retirar os fundos.
        local function sem_fundo(original)
          if type(original) == "table" then
            return vim.tbl_extend("force", original, { bg = "NONE" })
          end

          if type(original) == "function" then
            return function(...)
              local resultado = original(...)

              if type(resultado) == "table" then
                local copia = vim.deepcopy(resultado)
                copia.bg = "NONE"
                return copia
              end

              if type(resultado) == "string" then
                local ok, hl = pcall(
                  vim.api.nvim_get_hl,
                  0,
                  { name = resultado, link = false }
                )

                return {
                  fg = ok and hl.fg
                      and string.format("#%06x", hl.fg)
                      or texto,
                  bg = "NONE",
                }
              end

              return { fg = texto, bg = "NONE" }
            end
          end

          if type(original) == "string" then
            return sem_fundo(function()
              return original
            end)
          end

          return nil
        end

        for _, conjunto in ipairs({
          opts.sections,
          opts.inactive_sections or {},
        }) do
          for _, componentes in pairs(conjunto) do
            if type(componentes) == "table" then
              for _, componente in ipairs(componentes) do
                if type(componente) == "table" then
                  componente.separator = ""

                  if componente.color ~= nil then
                    componente.color = sem_fundo(componente.color)
                  end
                end
              end
            end
          end
        end
      end

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
