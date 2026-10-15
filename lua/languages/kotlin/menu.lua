local M = {}

-- Modulos Kotlin.
local projetos = require("languages.kotlin.projects")
local gradle = require("languages.kotlin.gradle_commands")
local tipos = require("languages.kotlin.types")

-- Abrir o menu de gerenciamento Kotlin.
function M.abrir()
  -- Capturar o arquivo original antes de abrir o menu.
  local arquivo = vim.api.nvim_buf_get_name(0)

  -- Identificar o projeto Gradle atual.
  local raiz_gradle = gradle.raiz_gradle(arquivo)

  -- Identificar as fontes do modulo Kotlin.
  local fontes_kotlin = tipos.localizar_fontes(arquivo)

  local opcoes = {
    {
      nome = "Criar novo projeto Kotlin",
      executar = function()
        projetos.criar()
      end,
    },
  }

  -- Criacao de classes e outros tipos Kotlin.
  if fontes_kotlin then
    table.insert(opcoes, {
      nome = "Novo elemento Kotlin (Class, Interface, Data Class...)",
      executar = function()
        tipos.criar(arquivo)
      end,
    })
  end

  -- Comandos disponiveis dentro de projetos Gradle.
  if raiz_gradle then
    table.insert(opcoes, {
      nome = "Gradle - Build do projeto",
      executar = function()
        gradle.executar("build", arquivo)
      end,
    })

    table.insert(opcoes, {
      nome = "Gradle - Executar testes",
      executar = function()
        gradle.executar("test", arquivo)
      end,
    })
  end

  vim.ui.select(opcoes, {
    prompt = "Kotlin - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      escolha.executar()
    end
  end)
end

-- Registrar o comando :KotlinMenu.
function M.setup()
  vim.api.nvim_create_user_command("KotlinMenu", function()
    M.abrir()
  end, {
    desc = "Abrir menu de gerenciamento Kotlin",
  })
end

return M
