-- ========================================
-- C# - MENU GLOBAL
-- ========================================

local M = {}

-- ========================================
-- LOCALIZAR PROJETO ANCESTRAL
-- ========================================

local function encontrar_projeto_ancestral(diretorio)
  local projetos = vim.fs.find(function(nome)
    return nome:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = diretorio,
    limit = 1,
  })

  return projetos[1]
end

-- ========================================
-- DIRETORIO BASE PARA NOVOS PROJETOS
-- ========================================

local function obter_diretorio_base()
  local atual = vim.fs.normalize(vim.fn.getcwd())

  local projeto = encontrar_projeto_ancestral(atual)

  if projeto then
    return vim.fs.dirname(vim.fs.dirname(projeto))
  end

  return atual
end

-- ========================================
-- CRIAR PROJETO PELO TEMPLATE OFICIAL
-- ========================================

local function criar_projeto()
  local tipos = {
    {
      nome = "Console - top-level statements",
      template = "console",
      main_tradicional = false,
    },
    {
      nome = "Console - Main tradicional",
      template = "console",
      main_tradicional = true,
    },
    {
      nome = "Biblioteca de classes",
      template = "classlib",
      main_tradicional = false,
    },
  }

  vim.ui.select(tipos, {
    prompt = "Tipo de projeto C#",

    format_item = function(item)
      return item.nome
    end,
  }, function(tipo)
    if not tipo then
      return
    end

    local nome = vim.fn.input("Nome do projeto: ")

    if not nome:match("^[%a_][%w_]*$") then
      vim.notify("Nome de projeto invalido.", vim.log.levels.ERROR)
      return
    end

    local sugerido = obter_diretorio_base()

    local entrada = vim.fn.input("Diretorio pai do projeto: ", sugerido, "dir")

    if entrada == "" then
      vim.notify("Criacao cancelada.", vim.log.levels.WARN)
      return
    end

    local raiz = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(entrada), ":p"))

    if vim.fn.isdirectory(raiz) ~= 1 then
      vim.notify("O diretorio pai nao existe: " .. raiz, vim.log.levels.ERROR)
      return
    end

    local projeto_existente = encontrar_projeto_ancestral(raiz)

    if projeto_existente then
      vim.notify(
        "O diretorio escolhido ja pertence a um projeto C#:\n"
          .. projeto_existente
          .. "\nEscolha um diretorio fora desse projeto.",
        vim.log.levels.ERROR
      )
      return
    end

    local destino = vim.fs.joinpath(raiz, nome)

    if vim.uv.fs_lstat(destino) then
      vim.notify("Ja existe um item com esse nome: " .. destino, vim.log.levels.ERROR)
      return
    end

    local comando = {
      "dotnet",
      "new",
      tipo.template,
      "--name",
      nome,
      "--output",
      destino,
    }

    if tipo.main_tradicional then
      table.insert(comando, "--use-program-main")
    end

    vim.notify("Criando projeto: " .. destino)

    local resultado = vim.fn.system(comando)

    if vim.v.shell_error ~= 0 then
      vim.notify("Falha ao criar projeto:\n" .. resultado, vim.log.levels.ERROR)
      return
    end

    vim.notify("Projeto criado com sucesso: " .. destino)

    vim.ui.select({
      "Abrir arquivo principal",
      "Abrir pasta do projeto",
      "Deixar como esta",
    }, {
      prompt = "Projeto criado. O que deseja fazer?",
    }, function(acao)
      if acao == "Abrir arquivo principal" then
        local arquivo_principal

        if tipo.template == "console" then
          arquivo_principal = destino .. "/Program.cs"
        else
          arquivo_principal = destino .. "/Class1.cs"
        end

        if vim.fn.filereadable(arquivo_principal) ~= 1 then
          vim.notify("Arquivo principal nao encontrado: " .. arquivo_principal, vim.log.levels.ERROR)
          return
        end

        vim.cmd("edit " .. vim.fn.fnameescape(arquivo_principal))
      elseif acao == "Abrir pasta do projeto" then
        vim.cmd("Explore " .. vim.fn.fnameescape(destino))
      end
    end)
  end)
end

-- ========================================
-- CRIAR SOLUCAO .SLN OU .SLNX
-- ========================================

local function criar_solucao()
  local formatos = {
    {
      nome = "Solucao moderna (.slnx)",
      formato = "slnx",
    },
    {
      nome = "Solucao classica (.sln)",
      formato = "sln",
    },
  }

  vim.ui.select(formatos, {
    prompt = "Formato da solucao C#",

    format_item = function(item)
      return item.nome
    end,
  }, function(tipo)
    if not tipo then
      return
    end

    local nome = vim.fn.input("Nome da solucao: ")

    if not nome:match("^[%a_][%w_]*$") then
      vim.notify("Nome de solucao invalido.", vim.log.levels.ERROR)
      return
    end

    local sugerido = obter_diretorio_base()

    local entrada = vim.fn.input("Diretorio pai da solucao: ", sugerido, "dir")

    if entrada == "" then
      vim.notify("Criacao cancelada.", vim.log.levels.WARN)
      return
    end

    local raiz = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(entrada), ":p"))

    if vim.fn.isdirectory(raiz) ~= 1 then
      vim.notify("O diretorio pai nao existe: " .. raiz, vim.log.levels.ERROR)
      return
    end

    local projeto_existente = encontrar_projeto_ancestral(raiz)

    if projeto_existente then
      vim.notify(
        "O diretorio pertence a um projeto C#:\n" .. projeto_existente .. "\nEscolha um diretorio externo.",
        vim.log.levels.ERROR
      )
      return
    end

    local destino = vim.fs.joinpath(raiz, nome)

    if vim.uv.fs_lstat(destino) then
      vim.notify("Ja existe um item com esse nome: " .. destino, vim.log.levels.ERROR)
      return
    end

    local comando = {
      "dotnet",
      "new",
      "sln",
      "--name",
      nome,
      "--output",
      destino,
      "--format",
      tipo.formato,
    }

    vim.notify("Criando solucao ." .. tipo.formato .. ": " .. nome)

    local resultado = vim.fn.system(comando)

    if vim.v.shell_error ~= 0 then
      vim.notify("Falha ao criar solucao:\n" .. resultado, vim.log.levels.ERROR)
      return
    end

    local arquivo_solucao = vim.fs.joinpath(destino, nome .. "." .. tipo.formato)

    if vim.fn.filereadable(arquivo_solucao) ~= 1 then
      vim.notify("O comando terminou, mas o arquivo nao foi encontrado:\n" .. arquivo_solucao, vim.log.levels.ERROR)
      return
    end

    vim.notify("Solucao criada com sucesso: " .. arquivo_solucao)

    vim.ui.select({
      "Abrir arquivo da solucao",
      "Abrir pasta da solucao",
      "Deixar como esta",
    }, {
      prompt = "Solucao criada. O que deseja fazer?",
    }, function(acao)
      if acao == "Abrir arquivo da solucao" then
        vim.cmd("edit " .. vim.fn.fnameescape(arquivo_solucao))
      elseif acao == "Abrir pasta da solucao" then
        vim.cmd("Explore " .. vim.fn.fnameescape(destino))
      end
    end)
  end)
end

-- ========================================
-- LOCALIZAR PROJETO DO ARQUIVO ATUAL
-- ========================================

local function localizar_projeto()
  local arquivo = vim.fn.expand("%:p")

  if arquivo == "" then
    vim.notify("Abra um arquivo dentro do projeto C#.", vim.log.levels.WARN)
    return nil
  end

  local projeto = encontrar_projeto_ancestral(vim.fs.dirname(arquivo))

  if not projeto then
    vim.notify("Nenhum projeto .csproj encontrado.", vim.log.levels.ERROR)
    return nil
  end

  return projeto
end

-- ========================================
-- COMPILAR PROJETO ATUAL
-- ========================================

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
    cwd = vim.fs.dirname(projeto),
  })
end

-- ========================================
-- INICIAR DEPURACAO EXISTENTE
-- ========================================

local function iniciar_depurar()
  local projeto = localizar_projeto()

  if not projeto then
    return
  end

  local dap = require("dap")
  local configuracoes = dap.configurations.cs

  if not configuracoes or #configuracoes == 0 then
    vim.notify("Nenhuma configuracao DAP encontrada para C#.", vim.log.levels.ERROR)
    return
  end

  dap.continue()
end

-- ========================================
-- MENU PRINCIPAL C#
-- ========================================

function M.abrir()
  local opcoes = {
    "Criar projeto C#",
    "Criar solucao C# (.sln / .slnx)",
    "Adicionar projeto a solucao",
    "Listar projetos da solucao",
    "Remover projeto da solucao",
    "Criar classe C# (namespace automatico)",
    "Executar projeto atual",
    "Compilar projeto atual",
    "Iniciar depuracao",
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
    elseif escolha == "Criar solucao C# (.sln / .slnx)" then
      criar_solucao()
    elseif escolha == "Adicionar projeto a solucao" then
      require("languages.csharp.solucoes").adicionar()
    elseif escolha == "Listar projetos da solucao" then
      require("languages.csharp.solucoes").listar()
    elseif escolha == "Remover projeto da solucao" then
      require("languages.csharp.solucoes").remover()
    elseif escolha == "Criar classe C# (namespace automatico)" then
      require("languages.csharp.classes").criar()
    elseif escolha == "Executar projeto atual" then
      local arquivo = vim.fn.expand("%:p")

      if arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
        vim.notify("Abra e salve um arquivo C# do projeto primeiro.", vim.log.levels.WARN)
        return
      end

      require("languages.csharp.runner").executar(arquivo)
    elseif escolha == "Compilar projeto atual" then
      compilar_projeto()
    elseif escolha == "Iniciar depuracao" then
      iniciar_depurar()
    end
  end)
end

return M
