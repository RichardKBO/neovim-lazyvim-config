-- ========================================
-- C# - RUNNER DINAMICO GLOBAL (F6)
-- ========================================

local M = {}

local terminais = {}
local ultima_execucao = 0

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function diretorio(arquivo)
  return vim.fn.fnamemodify(arquivo, ":h")
end

-- ========================================
-- LOCALIZAR PROJETOS
-- ========================================

local function buscar_projetos(arquivo)
  local pasta = diretorio(arquivo)

  while pasta and pasta ~= "" do
    local projetos = vim.fn.globpath(pasta, "*.csproj", false, true)

    if #projetos > 0 then
      table.sort(projetos)
      return projetos
    end

    local pai = vim.fs.dirname(pasta)

    if not pai or pai == pasta then
      break
    end

    pasta = pai
  end

  -- Alternativa: procurar na solucao ancestral.
  local solucoes = vim.fs.find(function(nome)
    return nome:match("%.slnx?$") ~= nil
  end, {
    path = diretorio(arquivo),
    upward = true,
  })

  if #solucoes == 0 then
    return {}
  end

  local raiz = diretorio(solucoes[1])
  local encontrados = vim.fn.globpath(raiz, "**/*.csproj", false, true)
  local projetos = {}

  for _, projeto in ipairs(encontrados) do
    if not projeto:find("/obj/", 1, true) and not projeto:find("/bin/", 1, true) then
      table.insert(projetos, projeto)
    end
  end

  table.sort(projetos)

  return projetos
end

-- ========================================
-- SELETOR GENERICO
-- ========================================

local function selecionar(opcoes, titulo, formatar, callback)
  if #opcoes == 0 then
    callback(nil)
    return
  end

  if #opcoes == 1 then
    callback(opcoes[1])
    return
  end

  vim.ui.select(opcoes, {
    prompt = titulo,
    format_item = formatar,
  }, callback)
end

-- ========================================
-- IDENTIFICAR EXECUTORES DE EXERCICIOS
-- ========================================

local function ler_executor(arquivo)
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

  if namespace then
    return namespace .. "." .. classe
  end

  return classe
end

local function listar_executores(arquivo)
  local pasta = diretorio(arquivo)
  local nome = vim.fn.fnamemodify(arquivo, ":t:r")

  local candidatos = {}
  local registrados = {}

  local function adicionar(caminho)
    if registrados[caminho] then
      return
    end

    registrados[caminho] = true

    local classe = ler_executor(caminho)

    if classe then
      table.insert(candidatos, {
        arquivo = caminho,
        classe = classe,
      })
    end
  end

  -- Prioridade 1: arquivo aberto.
  adicionar(arquivo)

  if #candidatos > 0 then
    return candidatos, true
  end

  -- Prioridade 2: executor correspondente.
  -- Produto.cs -> ProdutoExecutar.cs
  if not nome:match("Executar$") then
    adicionar(pasta .. "/" .. nome .. "Executar.cs")
  end

  if #candidatos > 0 then
    return candidatos, true
  end

  -- Prioridade 3: executores da mesma pasta.
  local encontrados = vim.fn.globpath(pasta, "*Executar.cs", false, true)

  for _, caminho in ipairs(encontrados) do
    adicionar(caminho)
  end

  return candidatos, false
end

-- ========================================
-- TERMINAL EXCLUSIVO DO C#
-- ========================================

local function abrir_terminal(comando, pasta)
  local aba = vim.api.nvim_get_current_tabpage()
  local janela = terminais[aba]

  if janela and (not vim.api.nvim_win_is_valid(janela) or vim.api.nvim_win_get_tabpage(janela) ~= aba) then
    janela = nil
  end

  if janela then
    vim.api.nvim_set_current_win(janela)

    local antigo = vim.api.nvim_win_get_buf(janela)

    if vim.bo[antigo].buftype == "terminal" then
      local job = vim.b[antigo].terminal_job_id

      if job then
        pcall(vim.fn.jobstop, job)
      end
    end

    local novo = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(janela, novo)

    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    vim.cmd("botright 12new")

    janela = vim.api.nvim_get_current_win()
    terminais[aba] = janela
  end

  local buffer = vim.api.nvim_win_get_buf(janela)

  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false

  local job = vim.fn.termopen(comando, {
    cwd = pasta,
  })

  if job <= 0 then
    avisar("C#: falha ao iniciar o terminal.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

-- ========================================
-- CONSULTAR PROPRIEDADES DO MSBUILD
-- ========================================

local function consultar_projeto(projeto, callback)
  local comando = {
    "dotnet",
    "msbuild",
    projeto,
    "-getProperty:EnableClassRunner,TargetFramework,TargetFrameworks,OutputType,IsTestProject",
  }

  vim.system(comando, {
    cwd = diretorio(projeto),
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        avisar("C#: erro ao consultar projeto:\n" .. (resultado.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local ok, dados = pcall(vim.json.decode, resultado.stdout or "")

      if not ok or type(dados) ~= "table" or type(dados.Properties) ~= "table" then
        avisar("C#: resposta inesperada do MSBuild.", vim.log.levels.ERROR)
        return
      end

      callback(dados.Properties)
    end)
  end)
end

-- ========================================
-- CONSULTAR CAMINHO REAL DO ASSEMBLY
-- ========================================

local function consultar_assembly(projeto, framework, callback)
  local comando = {
    "dotnet",
    "msbuild",
    projeto,
    "-property:Configuration=Debug",
    "-getProperty:TargetPath",
  }

  if framework and framework ~= "" then
    table.insert(comando, "-property:TargetFramework=" .. framework)
  end

  vim.system(comando, {
    cwd = diretorio(projeto),
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        avisar("C#: erro ao localizar assembly:\n" .. (resultado.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local caminho = vim.trim(resultado.stdout or "")

      if caminho == "" or caminho:find("\n", 1, true) then
        avisar("C#: TargetPath invalido ou vazio.", vim.log.levels.ERROR)
        return
      end

      -- Resolver caminhos relativos ao projeto.
      if not caminho:match("^/") then
        caminho = vim.fs.joinpath(diretorio(projeto), caminho)
      end

      callback(vim.fs.normalize(caminho))
    end)
  end)
end

-- ========================================
-- EXECUTOR GLOBAL COMPARTILHADO
-- ========================================

local function obter_runner_global()
  local caminho =
    vim.fs.joinpath(vim.fn.stdpath("data"), "csharp-class-runner", "bin", "Debug", "net10.0", "NeovimCSharpRunner.dll")

  return vim.fs.normalize(caminho)
end

-- ========================================
-- EXECUTAR CLASSE PELO RUNNER GLOBAL
-- ========================================

local function executar_classe_global(projeto, framework, classe, chamada)
  local runner = obter_runner_global()

  if vim.fn.filereadable(runner) ~= 1 then
    avisar("C#: executor global nao encontrado:\n" .. runner, vim.log.levels.ERROR)
    return
  end

  consultar_assembly(projeto, framework, function(assembly)
    -- Evitar execucoes antigas apos outro F6.
    if chamada ~= ultima_execucao then
      return
    end

    -- Compilar sempre antes da execucao.
    -- Argumentos posicionais evitam problemas
    -- com espacos e metacaracteres em caminhos.
    local script = [[
if [ -n "$5" ]; then
  dotnet build "$1" --configuration Debug --framework "$5" --nologo
else
  dotnet build "$1" --configuration Debug --nologo
fi || exit $?

exec dotnet "$2" "$3" "$4"
]]

    local comando = {
      "sh",
      "-c",
      script,
      "neovim-csharp-runner",
      projeto,
      runner,
      assembly,
      classe,
      framework or "",
    }

    avisar("C#: executando " .. classe)

    abrir_terminal(comando, diretorio(projeto))
  end)
end

-- ========================================
-- EXECUCAO CONVENCIONAL DO DOTNET
-- E COMPATIBILIDADE COM DISPATCHER ANTIGO
-- ========================================

local function criar_comando(projeto, propriedades, framework, classe)
  local pasta = diretorio(projeto)

  local testes = (tostring(propriedades.IsTestProject):lower() == "true")

  local tipo = tostring(propriedades.OutputType or ""):lower()

  local comando

  if testes then
    comando = {
      "dotnet",
      "test",
      projeto,
      "--configuration",
      "Debug",
    }

    avisar("C#: executando testes.")
  elseif tipo == "library" then
    comando = {
      "dotnet",
      "build",
      projeto,
      "--configuration",
      "Debug",
    }

    avisar("C#: compilando biblioteca.")
  else
    comando = {
      "dotnet",
      "run",
      "--project",
      projeto,
      "--configuration",
      "Debug",
    }

    if classe then
      avisar("C#: executando " .. classe)
    else
      avisar("C#: executando projeto " .. vim.fn.fnamemodify(projeto, ":t:r"))
    end
  end

  if framework and framework ~= "" then
    table.insert(comando, "--framework")
    table.insert(comando, framework)
  end

  -- Compatibilidade com projetos antigos
  -- que usam DesafioRunner e --executar.
  if classe and not testes and tipo ~= "library" then
    table.insert(comando, "--")
    table.insert(comando, "--executar")
    table.insert(comando, classe)
  end

  abrir_terminal(comando, pasta)
end

-- ========================================
-- SELECIONAR EXECUCAO
-- ========================================

local function escolher_execucao(arquivo, projeto, propriedades, framework, chamada)
  local legado = (tostring(propriedades.EnableClassRunner):lower() == "true")

  local testes = (tostring(propriedades.IsTestProject):lower() == "true")

  local biblioteca = (tostring(propriedades.OutputType or ""):lower() == "library")

  local function executar(classe)
    if chamada ~= ultima_execucao then
      return
    end

    -- Testes, bibliotecas e execucao normal.
    if not classe or testes or biblioteca then
      criar_comando(projeto, propriedades, framework, nil)
      return
    end

    -- Projetos antigos com dispatcher proprio.
    if legado then
      criar_comando(projeto, propriedades, framework, classe)
      return
    end

    -- Projetos comuns: runner global.
    executar_classe_global(projeto, framework, classe, chamada)
  end

  -- Program.cs executa o ponto de entrada normal.
  if vim.fn.fnamemodify(arquivo, ":t") == "Program.cs" then
    executar(nil)
    return
  end

  if testes or biblioteca then
    executar(nil)
    return
  end

  local candidatos, correspondencia_direta = listar_executores(arquivo)

  if #candidatos == 0 then
    executar(nil)
    return
  end

  -- Arquivo atual ou executor correspondente.
  if correspondencia_direta and #candidatos == 1 then
    executar(candidatos[1].classe)
    return
  end

  -- Multiplos executores: solicitar escolha.
  local opcoes = {
    {
      descricao = "Executar projeto normalmente",
      classe = nil,
    },
  }

  for _, candidato in ipairs(candidatos) do
    table.insert(opcoes, {
      descricao = "Executar " .. candidato.classe,
      classe = candidato.classe,
    })
  end

  selecionar(opcoes, "C# - Escolha a execucao", function(item)
    return item.descricao
  end, function(item)
    if item then
      executar(item.classe)
    end
  end)
end

-- ========================================
-- SELECIONAR FRAMEWORK
-- ========================================

local function preparar_execucao(arquivo, projeto, propriedades, chamada)
  local frameworks = tostring(propriedades.TargetFrameworks or "")

  local opcoes = {}

  if frameworks ~= "" then
    opcoes = vim.split(frameworks, ";", {
      plain = true,
      trimempty = true,
    })
  end

  if #opcoes == 0 then
    local unico = tostring(propriedades.TargetFramework or "")

    if unico ~= "" then
      table.insert(opcoes, unico)
    end
  end

  if #opcoes == 0 then
    escolher_execucao(arquivo, projeto, propriedades, nil, chamada)
    return
  end

  selecionar(opcoes, "C# - Selecione o framework", function(item)
    return item
  end, function(framework)
    if framework and chamada == ultima_execucao then
      escolher_execucao(arquivo, projeto, propriedades, framework, chamada)
    end
  end)
end

-- ========================================
-- F6 - ENTRADA PRINCIPAL
-- ========================================

function M.executar(arquivo)
  if vim.fn.executable("dotnet") ~= 1 then
    avisar("C#: dotnet nao encontrado.", vim.log.levels.ERROR)
    return
  end

  if not arquivo or arquivo == "" then
    avisar("C#: nenhum arquivo selecionado.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  if vim.fn.filereadable(arquivo) ~= 1 then
    avisar("C#: salve o arquivo antes de executar.", vim.log.levels.WARN)
    return
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    avisar("C#: salve as alteracoes antes de executar.", vim.log.levels.WARN)
    return
  end

  local projetos = buscar_projetos(arquivo)

  if #projetos == 0 then
    avisar("C#: nenhum .csproj encontrado.", vim.log.levels.ERROR)
    return
  end

  -- Cada acionamento invalida consultas anteriores.
  ultima_execucao = ultima_execucao + 1
  local chamada = ultima_execucao

  selecionar(projetos, "C# - Selecione o projeto", function(projeto)
    return vim.fn.fnamemodify(projeto, ":t") .. " - " .. diretorio(projeto)
  end, function(projeto)
    if not projeto or chamada ~= ultima_execucao then
      return
    end

    consultar_projeto(projeto, function(propriedades)
      if chamada ~= ultima_execucao then
        return
      end

      preparar_execucao(arquivo, projeto, propriedades, chamada)
    end)
  end)
end

return M
