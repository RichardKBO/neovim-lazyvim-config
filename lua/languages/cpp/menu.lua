local M = {}

-- Modulos C++.
local projetos = require("languages.cpp.projects")
local tipos = require("languages.cpp.types")
local runner = require("languages.cpp.runner")
local debugger = require("languages.cpp.debugger")

-- Identificar o diretorio de partida.
local function diretorio_atual(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.getcwd()
  end

  local caminho = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  if vim.fn.isdirectory(caminho) == 1 then
    return caminho
  end

  return vim.fs.dirname(caminho)
end

-- Localizar a raiz CMake pelo arquivo aberto.
function M.raiz_cmake(arquivo)
  local diretorio = diretorio_atual(arquivo)

  local marcadores = vim.fs.find({
    "CMakeLists.txt",
  }, {
    path = diretorio,
    upward = true,
  })

  if #marcadores == 0 then
    return nil
  end

  return vim.fs.dirname(marcadores[1])
end

-- Identificar arquivos de codigo C/C++.
local function eh_codigo_cpp(arquivo)
  if not arquivo or arquivo == "" then
    return false
  end

  local extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()

  local extensoes = {
    c = true,
    cc = true,
    cpp = true,
    cxx = true,
  }

  return extensoes[extensao] == true
end

-- Abrir o CPPMenu.
function M.abrir()
  -- Capturar o arquivo antes de abrir o seletor.
  local arquivo = vim.api.nvim_buf_get_name(0)
  local raiz = M.raiz_cmake(arquivo)

  local opcoes = {
    {
      nome = "Criar novo projeto C++",
      executar = function()
        projetos.criar()
      end,
    },
  }

  if raiz then
    table.insert(opcoes, {
      nome = "Criar classe C++ (.hpp + .cpp)",
      executar = function()
        tipos.criar(arquivo)
      end,
    })

    -- Mesma configuracao utilizada pelo F7.
    table.insert(opcoes, {
      nome = "CMake - Configurar projeto (F7)",
      executar = function()
        runner.configurar(arquivo)
      end,
    })

    -- Permitir alterar o preset salvo pelo projeto.
    if vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakePresets.json")) == 1
      or vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakeUserPresets.json")) == 1
    then
      table.insert(opcoes, {
        nome = "CMake - Alterar preset",
        executar = function()
          local presets = require("languages.cpp.presets")

          presets.selecionar(raiz, function(nome)
            if nome then
              runner.configurar(arquivo)
            end
          end)
        end,
      })
    end

    if eh_codigo_cpp(arquivo) then
      -- Compilar somente o alvo associado ao arquivo.
      table.insert(opcoes, {
        nome = "CMake - Compilar alvo do arquivo atual",
        executar = function()
          runner.preparar(arquivo, function(executavel)
            vim.notify(
              "C++: alvo compilado: "
                .. vim.fn.fnamemodify(executavel, ":t"),
              vim.log.levels.INFO
            )
          end)
        end,
      })

      -- Mesma execucao utilizada pelo F6.
      table.insert(opcoes, {
        nome = "CMake - Executar arquivo atual (F6)",
        executar = function()
          runner.executar(arquivo)
        end,
      })

      -- Mesma depuracao utilizada pelo F8.
      table.insert(opcoes, {
        nome = "CMake - Depurar arquivo atual (F8)",
        executar = function()
          debugger.depurar(arquivo)
        end,
      })
    end
  end

  vim.ui.select(opcoes, {
    prompt = "C++ - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    local ok, erro = pcall(escolha.executar)

    if not ok then
      vim.notify(
        "C++: falha na operacao do CPPMenu: " .. tostring(erro),
        vim.log.levels.ERROR
      )
    end
  end)
end

-- Registrar o comando CPPMenu.
function M.setup()
  vim.api.nvim_create_user_command("CPPMenu", function()
    M.abrir()
  end, {
    desc = "Abrir menu de gerenciamento C++",
  })
end

return M
