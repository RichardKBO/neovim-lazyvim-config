local M = {}

-- Modulos C++.
local projetos = require("languages.cpp.projects")
local tipos = require("languages.cpp.types")

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

-- Localizar o projeto CMake mais proximo
-- do arquivo atualmente aberto.
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

-- Verificar se o arquivo aberto possui
-- uma extensao de codigo C/C++.
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

-- Executar comandos existentes do CMake Tools.
local function executar_cmake(comando)
  local ok, erro = pcall(vim.cmd, comando)

  if not ok then
    vim.notify(
      "C++: falha ao executar "
        .. comando
        .. ".\n"
        .. tostring(erro)
        .. "\nVerifique se o CMake foi configurado com F7.",
      vim.log.levels.ERROR
    )
  end
end

-- Abrir o CPPMenu.
function M.abrir()
  -- Capturar o arquivo atual antes
  -- de abrir a interface de selecao.
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

  -- Mostrar funcionalidades de projetos CMake.
  if raiz then
    -- Gerador de classes com header,
    -- implementacao e integracao CMake.
    table.insert(opcoes, {
      nome = "Criar classe C++ (.hpp + .cpp)",
      executar = function()
        tipos.criar(arquivo)
      end,
    })

    table.insert(opcoes, {
      nome = "CMake - Configurar projeto (F7)",
      executar = function()
        executar_cmake("CMakeGenerate")
      end,
    })

    table.insert(opcoes, {
      nome = "CMake - Compilar projeto",
      executar = function()
        executar_cmake("CMakeBuild")
      end,
    })

    table.insert(opcoes, {
      nome = "CMake - Selecionar tipo de build",
      executar = function()
        executar_cmake("CMakeSelectBuildType")
      end,
    })

    if eh_codigo_cpp(arquivo) then
      table.insert(opcoes, {
        nome = "CMake - Executar arquivo atual (F6)",
        executar = function()
          executar_cmake("CMakeRunCurrentFile")
        end,
      })

      table.insert(opcoes, {
        nome = "CMake - Depurar arquivo atual (F8)",
        executar = function()
          executar_cmake("CMakeDebugCurrentFile")
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
    if escolha then
      escolha.executar()
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
