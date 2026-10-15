-- ========================================
-- C# - DEBUGGER COM NViM-DAP E NETCOREDBG
-- ========================================

local M = {}

-- Localizar o projeto C# mais proximo do arquivo atual.
local function localizar_projeto()
  local arquivo = vim.fn.expand("%:p")

  if arquivo == "" then
    error("Nenhum arquivo C# aberto.")
  end

  local projetos = vim.fs.find(function(nome)
    return nome:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = vim.fs.dirname(arquivo),
  })

  if not projetos[1] then
    error("Nenhum arquivo .csproj encontrado.")
  end

  return vim.fn.fnamemodify(projetos[1], ":p")
end

-- Consultar uma propriedade do projeto pelo MSBuild.
local function consultar_propriedade(projeto, propriedade)
  local resultado = vim.fn.system({
    "dotnet",
    "msbuild",
    projeto,
    "-getProperty:" .. propriedade,
  })

  if vim.v.shell_error ~= 0 then
    error("Erro ao consultar " .. propriedade .. ":\n" .. resultado)
  end

  return vim.trim(resultado)
end

-- Verificar se o arquivo esta salvo.
local function verificar_arquivo(arquivo)
  if arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
    error("Salve o arquivo C# antes de depurar.")
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    error("Salve as alteracoes antes de depurar o C#.")
  end
end

-- Identificar uma classe com metodo Executar().
local function analisar_executor(arquivo)
  if vim.fn.filereadable(arquivo) ~= 1 then
    return nil
  end

  local linhas = vim.fn.readfile(arquivo)
  local conteudo = table.concat(linhas, "\n")

  local namespace = conteudo:match("namespace%s+([%w_%.]+)%s*[;{]")

  local classe = conteudo:match("public%s+[%a_%s]-class%s+([%a_][%w_]*)")

  local metodo = conteudo:match("public%s+static%s+void%s+Executar%s*%(%s*%)")

  if not namespace or not classe or not metodo then
    return nil
  end

  return namespace .. "." .. classe
end

-- Encontrar o executor associado ao arquivo atual.
local function identificar_executor(arquivo)
  verificar_arquivo(arquivo)

  -- Caso 1: o proprio arquivo possui Executar().
  local executor = analisar_executor(arquivo)

  if executor then
    return executor
  end

  -- Caso 2: procurar NomeDoArquivoExecutar.cs
  -- na mesma pasta da classe de logica.
  local diretorio = vim.fs.dirname(arquivo)
  local nome = vim.fn.fnamemodify(arquivo, ":t:r")

  if not nome:match("Executar$") then
    local candidato = diretorio .. "/" .. nome .. "Executar.cs"

    executor = analisar_executor(candidato)

    if executor then
      verificar_arquivo(candidato)
      return executor
    end
  end

  error(
    "Nao foi encontrado um metodo Executar() no arquivo atual "
      .. "nem um executor associado na mesma pasta: "
      .. arquivo
  )
end

-- Configurar o debugger C#.
function M.setup()
  local dap = require("dap")

  -- Adaptador NetCoreDbg existente.
  dap.adapters.coreclr = {
    type = "executable",

    command = vim.fn.expand("~/.local/share/netcoredbg-3.2.0-1092/netcoredbg/netcoredbg"),

    args = {
      "--interpreter=vscode",
    },
  }

  dap.configurations.cs = {
    {
      name = "C#: Depurar projeto atual",
      type = "coreclr",
      request = "launch",

      -- Localizar, compilar e obter a DLL do projeto.
      program = function()
        local arquivo = vim.fn.expand("%:p")
        verificar_arquivo(arquivo)

        local projeto = localizar_projeto()
        local diretorio = vim.fs.dirname(projeto)

        local output_type = consultar_propriedade(projeto, "OutputType")

        if output_type ~= "Exe" and output_type ~= "WinExe" then
          error("O projeto atual nao e executavel. OutputType: " .. output_type)
        end

        local framework = consultar_propriedade(projeto, "TargetFramework")

        if framework == "" or framework:find("\n", 1, true) then
          error("TargetFramework vazio ou com multiplos valores.")
        end

        local resultado = vim.fn.system({
          "dotnet",
          "build",
          projeto,
          "--configuration",
          "Debug",
          "--framework",
          framework,
        })

        if vim.v.shell_error ~= 0 then
          error("A compilacao do projeto C# falhou:\n" .. resultado)
        end

        local assembly_name = consultar_propriedade(projeto, "AssemblyName")

        if assembly_name == "" then
          error("Nao foi possivel identificar o AssemblyName.")
        end

        local dll = diretorio .. "/bin/Debug/" .. framework .. "/" .. assembly_name .. ".dll"

        if vim.fn.filereadable(dll) ~= 1 then
          error("DLL compilada nao encontrada: " .. dll)
        end

        return dll
      end,

      -- Definir argumentos conforme o tipo de projeto.
      args = function()
        local projeto = localizar_projeto()

        local class_runner = consultar_propriedade(projeto, "EnableClassRunner")

        -- Projetos convencionais nao precisam de dispatcher.
        if class_runner:lower() ~= "true" then
          return {}
        end

        local arquivo = vim.fn.expand("%:p")

        -- Permitir depurar o Program.cs convencional.
        if vim.fn.fnamemodify(arquivo, ":t") == "Program.cs" then
          return {}
        end

        -- Encontrar Executar() no proprio arquivo
        -- ou em um arquivo executor associado.
        local executor = identificar_executor(arquivo)

        return {
          "--executar",
          executor,
        }
      end,

      -- Usar o diretorio do projeto identificado.
      cwd = function()
        return vim.fs.dirname(localizar_projeto())
      end,

      stopAtEntry = false,
    },
  }
end

return M
