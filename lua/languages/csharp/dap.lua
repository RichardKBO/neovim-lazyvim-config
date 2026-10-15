-- Debugger C# modularizado
-- Utiliza nvim-dap + netcoredbg
-- Suporta projetos convencionais e projetos com DesafioRunner.

local M = {}

-- Localizar o projeto C# mais próximo do arquivo atual.
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

-- Verificar se o arquivo atual possui alterações não salvas.
local function verificar_arquivo(arquivo)
  if arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
    error("Salve o arquivo C# antes de depurar.")
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    error("Salve as alterações antes de depurar o C#.")
  end
end

-- Identificar a classe que possui o método Executar().
local function identificar_classe(arquivo)
  verificar_arquivo(arquivo)

  local linhas = vim.fn.readfile(arquivo)
  local conteudo = table.concat(linhas, "\n")

  local namespace = conteudo:match("namespace%s+([%w_%.]+)%s*[;{]")

  local classe = conteudo:match("public%s+class%s+([%a_][%w_]*)")

  local metodo = conteudo:match("public%s+static%s+void%s+Executar%s*%(%s*%)")

  if not namespace or not classe or not metodo then
    error("Não foi possível identificar namespace, classe pública e método Executar() no arquivo atual.")
  end

  return namespace .. "." .. classe
end

-- Configurar o debugger C#.
function M.setup()
  local dap = require("dap")

  -- Adaptador netcoredbg.
  dap.adapters.coreclr = {
    type = "executable",
    command = vim.fn.expand("~/.local/share/netcoredbg-3.2.0-1092/netcoredbg/netcoredbg"),
    args = {
      "--interpreter=vscode",
    },
  }

  -- Configuração de depuração C#.
  dap.configurations.cs = {
    {
      name = "C#: Depurar projeto atual",
      type = "coreclr",
      request = "launch",

      -- Identificar e compilar o projeto correto.
      program = function()
        local arquivo = vim.fn.expand("%:p")
        verificar_arquivo(arquivo)

        local projeto = localizar_projeto()
        local diretorio = vim.fs.dirname(projeto)

        -- Verificar se é um projeto executável.
        local output_type = consultar_propriedade(projeto, "OutputType")

        if output_type ~= "Exe" and output_type ~= "WinExe" then
          error("O projeto atual não é executável. OutputType: " .. output_type)
        end

        -- Identificar o framework.
        local framework = consultar_propriedade(projeto, "TargetFramework")

        if framework == "" or framework:find("\n", 1, true) then
          error("TargetFramework vazio ou com múltiplos valores.")
        end

        -- Compilar em modo Debug.
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
          error("A compilação do projeto C# falhou:\n" .. resultado)
        end

        -- Identificar o nome real do assembly.
        local assembly_name = consultar_propriedade(projeto, "AssemblyName")

        if assembly_name == "" then
          error("Não foi possível identificar o AssemblyName.")
        end

        -- Montar o caminho padrão da DLL.
        local dll = diretorio .. "/bin/Debug/" .. framework .. "/" .. assembly_name .. ".dll"

        if vim.fn.filereadable(dll) ~= 1 then
          error("DLL compilada não encontrada: " .. dll)
        end

        return dll
      end,

      -- Escolher automaticamente o modo de depuração.
      args = function()
        local projeto = localizar_projeto()

        local class_runner = consultar_propriedade(projeto, "EnableClassRunner")

        -- Projetos com DesafioRunner.
        if class_runner:lower() == "true" then
          local arquivo = vim.fn.expand("%:p")

          return {
            "--executar",
            identificar_classe(arquivo),
          }
        end

        -- Projetos convencionais executam pelo Main().
        return {}
      end,

      -- Executar no diretório do projeto correspondente.
      cwd = function()
        return vim.fs.dirname(localizar_projeto())
      end,

      stopAtEntry = false,
    },
  }
end

return M
