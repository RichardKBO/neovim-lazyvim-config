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
-- SOLICITAR SOLUCAO
-- ========================================

local function solicitar_solucao(callback)
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
