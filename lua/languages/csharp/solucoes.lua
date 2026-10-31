-- ========================================
-- C# - GERENCIAMENTO DE SOLUCOES
-- ========================================

local M = {}

-- ========================================
-- NORMALIZAR CAMINHOS
-- ========================================

local function normalizar_caminho(entrada)
  entrada = vim.trim(entrada or "")

  if entrada == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(entrada), ":p"))
end

-- ========================================
-- VALIDAR ARQUIVOS
-- ========================================

local function arquivo_existe(caminho)
  return caminho ~= nil and vim.fn.filereadable(caminho) == 1
end

local function solucao_valida(caminho)
  return arquivo_existe(caminho) and (caminho:match("%.sln$") or caminho:match("%.slnx$"))
end

local function projeto_valido(caminho)
  return arquivo_existe(caminho) and caminho:match("%.csproj$") ~= nil
end

-- ========================================
-- IDENTIFICAR PROJETO ATUAL
-- ========================================

local function localizar_projeto_atual()
  local arquivo = vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    return nil
  end

  local diretorio = vim.fs.dirname(arquivo)

  while diretorio do
    local projetos = vim.fn.globpath(diretorio, "*.csproj", false, true)

    if #projetos > 1 then
      return nil
    end

    if #projetos == 1 then
      return vim.fs.normalize(projetos[1])
    end

    local pai = vim.fs.dirname(diretorio)

    if not pai or pai == diretorio then
      break
    end

    diretorio = pai
  end

  return nil
end

-- ========================================
-- DESCOBRIR SOLUCOES PROXIMAS
-- ========================================

local function coletar_solucoes(pasta, padrao, encontrados, vistos)
  for _, caminho in ipairs(vim.fn.globpath(pasta, padrao, false, true)) do
    local solucao = vim.fs.normalize(caminho)

    if solucao_valida(solucao) and not vistos[solucao] then
      vistos[solucao] = true
      table.insert(encontrados, solucao)
    end
  end
end

function M.descobrir_solucoes()
  local arquivo = vim.api.nvim_buf_get_name(0)
  local projeto = localizar_projeto_atual()

  local diretorio = projeto and vim.fs.dirname(projeto)
    or (arquivo ~= "" and vim.fs.dirname(arquivo) or vim.fn.getcwd())

  local pai = vim.fs.dirname(diretorio)
  local encontrados = {}
  local vistos = {}

  for _, extensao in ipairs({ "*.sln", "*.slnx" }) do
    coletar_solucoes(diretorio, extensao, encontrados, vistos)
    coletar_solucoes(diretorio, "*/" .. extensao, encontrados, vistos)

    if pai and pai ~= diretorio and vim.fs.dirname(pai) ~= pai then
      coletar_solucoes(pai, extensao, encontrados, vistos)
      coletar_solucoes(pai, "*/" .. extensao, encontrados, vistos)
    end
  end

  table.sort(encontrados)
  return encontrados
end

-- ========================================
-- SOLICITAR SOLUCAO
-- ========================================

local function solicitar_solucao_manual(callback)
  local entrada = vim.fn.input("Caminho da solucao (.sln/.slnx): ", vim.fn.getcwd() .. "/", "file")

  local solucao = normalizar_caminho(entrada)

  if not solucao then
    vim.notify("Operacao cancelada.", vim.log.levels.WARN)
    return
  end

  if not solucao_valida(solucao) then
    vim.notify("Solucao inexistente ou invalida:\n" .. solucao, vim.log.levels.ERROR)
    return
  end

  callback(solucao)
end

-- ========================================
-- SELECIONAR SOLUCAO INTELIGENTEMENTE
-- ========================================

local function solicitar_solucao(callback)
  M.classificar_solucoes(function(grupos)
    local opcoes = {}

    local function incluir(solucoes, categoria)
      for _, solucao in ipairs(solucoes) do
        table.insert(opcoes, {
          caminho = solucao,
          rotulo = categoria .. " | " .. solucao,
        })
      end
    end

    incluir(grupos.associadas, "Associada")
    incluir(grupos.outras, "Outra")
    incluir(grupos.nao_verificadas, "Nao verificada")

    table.insert(opcoes, {
      manual = true,
      rotulo = "Informar caminho manualmente...",
    })

    vim.ui.select(opcoes, {
      prompt = "Selecionar solucao (.sln/.slnx):",
      format_item = function(item)
        return item.rotulo
      end,
    }, function(escolha)
      if not escolha then
        return
      end

      if escolha.manual then
        solicitar_solucao_manual(callback)
        return
      end

      if not solucao_valida(escolha.caminho) then
        vim.notify("Solucao inexistente ou invalida.", vim.log.levels.ERROR)
        return
      end

      callback(escolha.caminho)
    end)
  end)
end

-- ========================================
-- EXECUTAR COMANDOS DOTNET
-- ========================================

local function executar_comando(comando, diretorio, sucesso)
  vim.notify("Executando comando do .NET...")

  vim.system(comando, {
    cwd = diretorio,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      local saida = vim.trim((resultado.stdout or "") .. "\n" .. (resultado.stderr or ""))

      if resultado.code ~= 0 then
        vim.notify("Erro ao executar comando:\n" .. saida, vim.log.levels.ERROR)
        return
      end

      vim.notify(saida ~= "" and saida or sucesso, vim.log.levels.INFO)
    end)
  end)
end

-- ========================================
-- CONSULTAR PROJETOS DA SOLUCAO
-- ========================================

local function consultar_projetos(solucao, callback)
  vim.system({
    "dotnet",
    "sln",
    solucao,
    "list",
  }, {
    cwd = vim.fs.dirname(solucao),
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        vim.notify(
          "Falha ao consultar solucao:\n" .. (resultado.stderr or "") .. "\n" .. (resultado.stdout or ""),
          vim.log.levels.ERROR
        )
        return
      end

      local saida = resultado.stdout or ""
      local projetos = {}
      local separador_encontrado = false

      for linha in saida:gmatch("[^\r\n]+") do
        local item = vim.trim(linha)

        if item:match("^%-+$") then
          separador_encontrado = true
        elseif separador_encontrado and item ~= "" then
          table.insert(projetos, item)
        end
      end

      -- Nunca permitir remocao baseada em uma
      -- resposta que nao conseguimos interpretar.
      local vazia = saida:find("No projects found", 1, true) ~= nil

      if not separador_encontrado and not vazia then
        vim.notify(
          "Nao foi possivel interpretar a lista " .. "de projetos retornada pelo .NET:\n" .. saida,
          vim.log.levels.ERROR
        )
        return
      end

      callback(projetos)
    end)
  end)
end

-- ========================================
-- CLASSIFICAR SOLUCOES POR PROJETO
-- ========================================

local function solucao_contem_projeto(saida, solucao, projeto)
  for linha in saida:gmatch("[^\r\n]+") do
    local relativo = vim.trim(linha)

    if relativo:match("%.csproj$") then
      local absoluto = vim.fs.normalize(
        vim.fs.joinpath(vim.fs.dirname(solucao), relativo)
      )

      if absoluto == projeto then
        return true
      end
    end
  end

  return false
end

function M.classificar_solucoes(callback)
  local solucoes = M.descobrir_solucoes()
  local projeto = localizar_projeto_atual()

  local grupos = {
    associadas = {},
    outras = {},
    nao_verificadas = {},
  }

  if not projeto then
    grupos.nao_verificadas = solucoes
    callback(grupos)
    return
  end

  local pendentes = #solucoes

  if pendentes == 0 then
    callback(grupos)
    return
  end

  for _, solucao in ipairs(solucoes) do
    vim.system({
      "dotnet",
      "sln",
      solucao,
      "list",
    }, {
      cwd = vim.fs.dirname(solucao),
      text = true,
    }, function(resposta)
      vim.schedule(function()
        local destino = grupos.nao_verificadas
        local saida = resposta.stdout or ""
        local formato_valido = saida:find("No projects found", 1, true) ~= nil

        for linha in saida:gmatch("[^\r\n]+") do
          if vim.trim(linha):match("^%-+$") then
            formato_valido = true
            break
          end
        end

        if resposta.code == 0 and formato_valido then
          if solucao_contem_projeto(saida, solucao, projeto) then
            destino = grupos.associadas
          else
            destino = grupos.outras
          end
        end

        table.insert(destino, solucao)
        pendentes = pendentes - 1

        if pendentes == 0 then
          table.sort(grupos.associadas)
          table.sort(grupos.outras)
          table.sort(grupos.nao_verificadas)

          callback(grupos)
        end
      end)
    end)
  end
end

-- ========================================
-- ADICIONAR PROJETO
-- ========================================

function M.adicionar()
  solicitar_solucao(function(solucao)
    local sugerido = localizar_projeto_atual() or ""

    local entrada = vim.fn.input("Caminho do projeto (.csproj): ", sugerido, "file")

    local projeto = normalizar_caminho(entrada)

    if not projeto then
      vim.notify("Operacao cancelada.", vim.log.levels.WARN)
      return
    end

    if not projeto_valido(projeto) then
      vim.notify("Projeto inexistente ou invalido:\n" .. projeto, vim.log.levels.ERROR)
      return
    end

    vim.ui.select({
      "Confirmar",
      "Cancelar",
    }, {
      prompt = "Adicionar " .. vim.fs.basename(projeto) .. " a " .. vim.fs.basename(solucao) .. "?",
    }, function(escolha)
      if escolha ~= "Confirmar" then
        return
      end

      executar_comando({
        "dotnet",
        "sln",
        solucao,
        "add",
        projeto,
      }, vim.fs.dirname(solucao), "Projeto adicionado a solucao.")
    end)
  end)
end

-- ========================================
-- LISTAR PROJETOS
-- ========================================

function M.listar()
  solicitar_solucao(function(solucao)
    consultar_projetos(solucao, function(projetos)
      if #projetos == 0 then
        vim.notify("A solucao nao possui projetos registrados.", vim.log.levels.INFO)
        return
      end

      local linhas = {
        "Solucao: " .. vim.fs.basename(solucao),
        "",
      }

      for indice, projeto in ipairs(projetos) do
        table.insert(linhas, indice .. ". " .. projeto)
      end

      vim.notify(table.concat(linhas, "\n"), vim.log.levels.INFO)
    end)
  end)
end

-- ========================================
-- REMOVER PROJETO DA SOLUCAO
-- ========================================

function M.remover()
  solicitar_solucao(function(solucao)
    consultar_projetos(solucao, function(projetos)
      if #projetos == 0 then
        vim.notify("A solucao nao possui projetos para remover.", vim.log.levels.WARN)
        return
      end

      -- Exibir somente projetos realmente
      -- registrados na solucao escolhida.
      vim.ui.select(projetos, {
        prompt = "Projeto a remover da solucao:",
      }, function(projeto_relativo)
        if not projeto_relativo then
          return
        end

        local projeto = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(solucao), projeto_relativo))

        -- Remocao apenas da referencia:
        -- nenhum arquivo sera excluido.
        vim.ui.select({
          "Cancelar",
          "Confirmar remocao da solucao",
        }, {
          prompt = "Remover " .. vim.fs.basename(projeto) .. " de " .. vim.fs.basename(solucao) .. "?",
        }, function(escolha)
          if escolha ~= "Confirmar remocao da solucao" then
            vim.notify("Remocao cancelada.", vim.log.levels.INFO)
            return
          end

          executar_comando({
            "dotnet",
            "sln",
            solucao,
            "remove",
            projeto,
          }, vim.fs.dirname(solucao), "Referencia removida da solucao.")
        end)
      end)
    end)
  end)
end

return M
