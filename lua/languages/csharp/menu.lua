local M = {}

-- Criar um arquivo C# usando um dos modelos disponíveis.
local function criar_arquivo(modelo)
  local diretorio = vim.fn.expand("%:p:h")

  if vim.fn.expand("%:p") == "" then
    diretorio = vim.fn.getcwd()
  end

  local nome = vim.fn.input("Nome do arquivo (sem .cs): ")

  if nome == "" then
    vim.notify("Criação cancelada.", vim.log.levels.WARN)
    return
  end

  if nome:find("[/\\]") then
    vim.notify("Digite apenas o nome do arquivo, sem diretórios.", vim.log.levels.ERROR)
    return
  end

  nome = nome:gsub("%.cs$", "")

  if not nome:match("^[%a_][%w_]*$") then
    vim.notify("Nome inválido para uma classe C#.", vim.log.levels.ERROR)
    return
  end

  local caminho = diretorio .. "/" .. nome .. ".cs"

  if vim.fn.filereadable(caminho) == 1 then
    vim.notify("O arquivo já existe: " .. caminho, vim.log.levels.ERROR)
    return
  end

  local linhas

  if modelo == "top-level" then
    linhas = {
      'Console.WriteLine("Olá, mundo!");',
      "",
    }
  else
    linhas = {
      "namespace MeuProjeto;",
      "",
      "internal class " .. nome,
      "{",
      "    static void Main(string[] args)",
      "    {",
      '        Console.WriteLine("Olá, mundo!");',
      "    }",
      "}",
      "",
    }
  end

  local sucesso = vim.fn.writefile(linhas, caminho)

  if sucesso ~= 0 then
    vim.notify("Não foi possível criar o arquivo.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(caminho))
  vim.notify("Arquivo criado: " .. caminho)
end

-- Criar um projeto C# completo.
local function criar_projeto()
  local tipos = {
    "Aplicativo de console",
    "Biblioteca de classes",
    "Cancelar",
  }

  vim.ui.select(tipos, {
    prompt = "Tipo de projeto C#",
  }, function(tipo)
    if not tipo or tipo == "Cancelar" then
      return
    end

    local nome = vim.fn.input("Nome do projeto: ")

    if not nome:match("^[%a_][%w_]*$") then
      vim.notify("Nome de projeto inválido.", vim.log.levels.ERROR)
      return
    end

    local raiz = vim.fn.getcwd()
    local destino = raiz .. "/" .. nome

    if vim.fn.isdirectory(destino) == 1 or vim.fn.filereadable(destino) == 1 then
      vim.notify("Já existe um item com esse nome: " .. destino, vim.log.levels.ERROR)
      return
    end

    local template = "console"

    if tipo == "Biblioteca de classes" then
      template = "classlib"
    end

    vim.notify("Criando projeto " .. nome .. "...")

    local resultado = vim.fn.system({
      "dotnet",
      "new",
      template,
      "--name",
      nome,
      "--output",
      destino,
    })

    if vim.v.shell_error ~= 0 then
      vim.notify("Falha ao criar projeto:\n" .. resultado, vim.log.levels.ERROR)
      return
    end

    vim.notify("Projeto criado com sucesso: " .. destino)

    vim.ui.select({
      "Abrir arquivo principal",
      "Abrir pasta do projeto",
      "Deixar como está",
    }, {
      prompt = "Projeto criado. O que deseja fazer?",
    }, function(acao)
      if acao == "Abrir arquivo principal" then
        local arquivo_principal

        if template == "console" then
          arquivo_principal = destino .. "/Program.cs"
        else
          arquivo_principal = destino .. "/Class1.cs"
        end

        vim.cmd("edit " .. vim.fn.fnameescape(arquivo_principal))
      elseif acao == "Abrir pasta do projeto" then
        vim.cmd("Explore " .. vim.fn.fnameescape(destino))
      end
    end)
  end)
end

-- Localizar o projeto C# mais próximo.
local function localizar_projeto()
  local arquivo = vim.fn.expand("%:p")

  if arquivo == "" then
    vim.notify("Abra um arquivo dentro do projeto C#.", vim.log.levels.WARN)
    return nil
  end

  local projetos = vim.fs.find(function(nome)
    return nome:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = vim.fn.fnamemodify(arquivo, ":h"),
  })

  if not projetos[1] then
    vim.notify("Nenhum projeto .csproj encontrado.", vim.log.levels.ERROR)
    return nil
  end

  return projetos[1]
end

-- Compilar o projeto C# atual.
local function compilar_projeto()
  local projeto = localizar_projeto()

  if not projeto then
    return
  end

  vim.cmd("botright split")

  vim.fn.termopen({
    "dotnet",
    "build",
    projeto,
    "--configuration",
    "Debug",
  }, {
    cwd = vim.fn.fnamemodify(projeto, ":h"),
  })
end

-- Iniciar a depuração usando a configuração DAP existente.
local function iniciar_depurar()
  local projeto = localizar_projeto()

  if not projeto then
    return
  end

  local dap = require("dap")
  local configuracoes = dap.configurations.cs

  if not configuracoes or #configuracoes == 0 then
    vim.notify("Nenhuma configuração DAP encontrada para C#.", vim.log.levels.ERROR)
    return
  end

  dap.continue()
end

-- Abrir o menu interativo.
function M.abrir()
  local opcoes = {
    "Criar projeto C#",
    "Criar arquivo com top-level statements",
    "Criar arquivo com Main tradicional",
    "Executar projeto atual",
    "Compilar projeto atual",
    "Iniciar depuração",
    "Cancelar",
  }

  vim.ui.select(opcoes, {
    prompt = "Menu C#",
  }, function(escolha)
    if not escolha or escolha == "Cancelar" then
      return
    end

    if escolha == "Criar projeto C#" then
      criar_projeto()
    elseif escolha == "Criar arquivo com top-level statements" then
      criar_arquivo("top-level")
    elseif escolha == "Criar arquivo com Main tradicional" then
      criar_arquivo("main")
    elseif escolha == "Executar projeto atual" then
      local arquivo = vim.fn.expand("%:p")

      if arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
        vim.notify("Abra e salve um arquivo C# do projeto primeiro.", vim.log.levels.WARN)
        return
      end

      -- Utilizar o executor C# modularizado.
      require("languages.csharp.runner").executar(arquivo)
    elseif escolha == "Compilar projeto atual" then
      compilar_projeto()
    elseif escolha == "Iniciar depuração" then
      iniciar_depurar()
    end
  end)
end

return M
