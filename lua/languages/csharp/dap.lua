-- ========================================
-- C# - DEBUGGER CONTEXTUAL (F8)
-- NetCoreDbg + executor global compartilhado
-- ========================================

local M = {}

-- ========================================
-- PROJETO DO ARQUIVO ATUAL
-- ========================================

local function localizar_projeto(arquivo)
  arquivo = arquivo or vim.fn.expand("%:p")

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

-- ========================================
-- CONSULTAR MSBUILD
-- ========================================

local function consultar_propriedade(projeto, propriedade, framework)
  local comando = {
    "dotnet",
    "msbuild",
    projeto,
    "-property:Configuration=Debug",
    "-getProperty:" .. propriedade,
  }

  if framework and framework ~= "" then
    table.insert(comando, "-property:TargetFramework=" .. framework)
  end

  local resultado = vim.fn.system(comando)

  if vim.v.shell_error ~= 0 then
    error("Erro ao consultar " .. propriedade .. ":\n" .. resultado)
  end

  return vim.trim(resultado)
end

local function obter_framework(projeto)
  local framework = consultar_propriedade(projeto, "TargetFramework")

  if framework == "" or framework:find("\n", 1, true) then
    error(
      "TargetFramework nao definido ou projeto com multiplos frameworks. " .. "Configure um framework para depurar."
    )
  end

  return framework
end

local function obter_assembly(projeto, framework)
  local caminho = consultar_propriedade(projeto, "TargetPath", framework)

  if caminho == "" or caminho:find("\n", 1, true) then
    error("TargetPath invalido ou vazio para o projeto C#.")
  end

  if not caminho:match("^/") then
    caminho = vim.fs.joinpath(vim.fs.dirname(projeto), caminho)
  end

  return vim.fs.normalize(caminho)
end

-- ========================================
-- VALIDAR E IDENTIFICAR EXECUTOR
-- ========================================

local function verificar_arquivo(arquivo)
  if arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
    error("Salve o arquivo C# antes de depurar.")
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    error("Salve as alteracoes antes de depurar o C#.")
  end
end

local function analisar_executor(arquivo)
  if vim.fn.filereadable(arquivo) ~= 1 then
    return nil
  end

  local conteudo = table.concat(vim.fn.readfile(arquivo), "\n")

  if not conteudo:match("public%s+static%s+void%s+Executar%s*%(%s*%)") then
    return nil
  end

  local classe = conteudo:match("%f[%w]class%s+([%a_][%w_]*)")

  if not classe then
    return nil
  end

  local namespace = conteudo:match("namespace%s+([%w_%.]+)%s*[;{]")

  return namespace and (namespace .. "." .. classe) or classe
end

local function identificar_executor(arquivo)
  verificar_arquivo(arquivo)

  -- Program.cs mantem a execucao convencional.
  if vim.fn.fnamemodify(arquivo, ":t") == "Program.cs" then
    return nil
  end

  -- Primeiro, verificar o proprio arquivo.
  local classe = analisar_executor(arquivo)

  if classe then
    return classe
  end

  -- Depois, procurar o executor correspondente.
  local nome = vim.fn.fnamemodify(arquivo, ":t:r")

  if not nome:match("Executar$") then
    local candidato = vim.fs.joinpath(vim.fs.dirname(arquivo), nome .. "Executar.cs")

    classe = analisar_executor(candidato)

    if classe then
      verificar_arquivo(candidato)
      return classe
    end
  end

  -- Sem executor direto, depurar o projeto normal.
  -- Para varios executores, abrir o arquivo *Executar.cs.
  return nil
end

-- ========================================
-- EXECUTOR GLOBAL
-- ========================================

local function obter_runner_global()
  return vim.fs.joinpath(
    vim.fn.stdpath("data"),
    "csharp-class-runner",
    "bin",
    "Debug",
    "net10.0",
    "NeovimCSharpRunner.dll"
  )
end

local function usar_runner_global(projeto, classe)
  if not classe then
    return false
  end

  local habilitado = consultar_propriedade(projeto, "EnableClassRunner")

  -- Preservar o dispatcher antigo quando presente.
  return habilitado:lower() ~= "true"
end

-- ========================================
-- COMPILAR O PROJETO
-- ========================================

local function compilar(projeto, framework)
  local resultado = vim.fn.system({
    "dotnet",
    "build",
    projeto,
    "--configuration",
    "Debug",
    "--framework",
    framework,
    "--nologo",
  })

  if vim.v.shell_error ~= 0 then
    error("A compilacao do projeto C# falhou:\n" .. resultado)
  end
end

-- ========================================
-- CONFIGURACAO DO NVIM-DAP
-- ========================================

function M.setup()
  local dap = require("dap")

  -- Preservar o adaptador NetCoreDbg existente.
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

      -- Selecionar a DLL conforme o arquivo aberto.
      program = function()
        local arquivo = vim.fn.expand("%:p")
        verificar_arquivo(arquivo)

        local projeto = localizar_projeto(arquivo)

        local tipo = consultar_propriedade(projeto, "OutputType")

        if tipo:lower() ~= "exe" and tipo:lower() ~= "winexe" then
          error("O projeto atual nao e executavel. OutputType: " .. tipo)
        end

        local framework = obter_framework(projeto)
        local classe = identificar_executor(arquivo)

        -- Gerar DLL e PDB atualizados.
        compilar(projeto, framework)

        local assembly = obter_assembly(projeto, framework)

        if vim.fn.filereadable(assembly) ~= 1 then
          error("DLL compilada nao encontrada: " .. assembly)
        end

        -- Para projetos novos, iniciar o executor global.
        if usar_runner_global(projeto, classe) then
          local runner = obter_runner_global()

          if vim.fn.filereadable(runner) ~= 1 then
            error("Executor global C# nao encontrado: " .. runner)
          end

          return runner
        end

        -- Program.cs e projetos antigos usam DLL propria.
        return assembly
      end,

      -- Argumentos enviados ao assembly depurado.
      args = function()
        local arquivo = vim.fn.expand("%:p")
        verificar_arquivo(arquivo)

        local projeto = localizar_projeto(arquivo)
        local classe = identificar_executor(arquivo)

        -- Execucao convencional.
        if not classe then
          return {}
        end

        -- Projeto novo: DLL e classe para o runner global.
        if usar_runner_global(projeto, classe) then
          local framework = obter_framework(projeto)
          local assembly = obter_assembly(projeto, framework)

          return {
            assembly,
            classe,
          }
        end

        -- Projeto antigo: manter --executar.
        return {
          "--executar",
          classe,
        }
      end,

      -- Trabalhar a partir da pasta do projeto.
      cwd = function()
        return vim.fs.dirname(localizar_projeto())
      end,

      stopAtEntry = false,
    },
  }
end

return M
