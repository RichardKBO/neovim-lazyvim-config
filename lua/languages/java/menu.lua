local M = {}

local projetos = require("languages.java.projects")
local gradle_projetos = require("languages.java.gradle_projects")
local tipos = require("languages.java.types")

local comandos_maven = require("languages.java.commands")
local comandos_gradle = require("languages.java.gradle_commands")

function M.abrir()
  -- Capturar o arquivo atual antes de abrir a interface.
  local arquivo = vim.api.nvim_buf_get_name(0)

  local raiz_maven = comandos_maven.raiz_maven(arquivo)
  local raiz_gradle = comandos_gradle.raiz_gradle(arquivo)

  local fontes_java = tipos.localizar_fontes(arquivo)

  local opcoes = {
    {
      nome = "Criar novo projeto Maven",
      executar = function()
        projetos.criar_maven()
      end,
    },
    {
      nome = "Criar novo projeto Gradle",
      executar = function()
        gradle_projetos.criar()
      end,
    },
  }

  -- Criacao de tipos em projetos Maven e Gradle.
  if fontes_java then
    table.insert(opcoes, {
      nome = "Novo elemento Java (Class, Interface, Record, Enum)",
      executar = function()
        tipos.criar(arquivo)
      end,
    })
  end

  -- Comandos exclusivos de projetos Maven.
  if raiz_maven and not raiz_gradle then
    table.insert(opcoes, {
      nome = "Maven - Compilar projeto",
      executar = function()
        comandos_maven.executar_maven("compile", arquivo)
      end,
    })

    table.insert(opcoes, {
      nome = "Maven - Executar testes",
      executar = function()
        comandos_maven.executar_maven("test", arquivo)
      end,
    })
  end

  -- Comandos exclusivos de projetos Gradle.
  if raiz_gradle and not raiz_maven then
    table.insert(opcoes, {
      nome = "Gradle - Build do projeto",
      executar = function()
        comandos_gradle.executar("build", arquivo)
      end,
    })

    table.insert(opcoes, {
      nome = "Gradle - Executar testes",
      executar = function()
        comandos_gradle.executar("test", arquivo)
      end,
    })
  end

  vim.ui.select(opcoes, {
    prompt = "Java - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      escolha.executar()
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("JavaMenu", function()
    M.abrir()
  end, {
    desc = "Abrir menu de gerenciamento Java",
  })
end

return M
