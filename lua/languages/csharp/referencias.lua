-- ========================================
-- C# - PROJECTREFERENCE
-- ========================================

local M = {}

local solucoes = require("languages.csharp.solucoes")

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

local function relativo(caminho, raiz)
  return vim.fs.relpath(raiz, caminho) or vim.fn.fnamemodify(caminho, ":t")
end

local function em_pasta_ignorada(caminho)
  return caminho:find("/bin/", 1, true) or caminho:find("/obj/", 1, true)
end

local function raiz_de_busca(consumidor)
  local melhor

  for _, solucao in ipairs(solucoes.descobrir_solucoes()) do
    local raiz = normalizar(vim.fs.dirname(solucao))

    if consumidor == raiz or consumidor:find(raiz .. "/", 1, true) == 1 then
      if not melhor or #raiz > #melhor then
        melhor = raiz
      end
    end
  end

  return melhor or vim.fs.dirname(consumidor)
end

local function descobrir_candidatos(consumidor, raiz)
  local candidatos = {}
  local vistos = {}

  for _, caminho in ipairs(vim.fn.globpath(raiz, "**/*.csproj", false, true)) do
    caminho = normalizar(caminho)

    if caminho ~= consumidor and not em_pasta_ignorada(caminho) and not vistos[caminho] then
      vistos[caminho] = true
      table.insert(candidatos, caminho)
    end
  end

  table.sort(candidatos)
  return candidatos
end

local function caminho_referenciado(entrada, consumidor)
  entrada = vim.trim(entrada or ""):gsub("\\", "/")

  if entrada == "" then
    return nil
  end

  if not entrada:match("^/") then
    entrada = vim.fs.joinpath(vim.fs.dirname(consumidor), entrada)
  end

  return normalizar(entrada)
end

local function tem_referencia(consumidor, biblioteca, callback)
  vim.system({
    "dotnet",
    "list",
    consumidor,
    "reference",
  }, {
    cwd = vim.fs.dirname(consumidor),
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        callback(nil, (resultado.stderr or "") .. (resultado.stdout or ""))
        return
      end

      for linha in (resultado.stdout or ""):gmatch("[^\r\n]+") do
        if caminho_referenciado(linha, consumidor) == biblioteca then
          callback(true)
          return
        end
      end

      callback(false)
    end)
  end)
end

local function executar(consumidor, biblioteca)
  vim.notify("Adicionando ProjectReference...")

  vim.system({
    "dotnet",
    "add",
    consumidor,
    "reference",
    biblioteca,
  }, {
    cwd = vim.fs.dirname(consumidor),
    text = true,
  }, function(resultado)
    vim.schedule(function()
      local saida = vim.trim((resultado.stdout or "") .. "\n" .. (resultado.stderr or ""))

      if resultado.code ~= 0 then
        vim.notify("Falha ao adicionar ProjectReference:\n" .. saida, vim.log.levels.ERROR)
        return
      end

      vim.notify(
        saida ~= "" and saida or ("ProjectReference adicionada: " .. vim.fn.fnamemodify(biblioteca, ":t")),
        vim.log.levels.INFO
      )
    end)
  end)
end

function M.adicionar()
  local consumidor = solucoes.localizar_projeto_atual()

  if not consumidor then
    vim.notify("Nao foi possivel identificar o projeto consumidor.", vim.log.levels.ERROR)
    return
  end

  consumidor = normalizar(consumidor)

  if vim.fn.filereadable(consumidor) ~= 1 then
    vim.notify("Projeto consumidor inexistente ou invalido:\n" .. consumidor, vim.log.levels.ERROR)
    return
  end

  local raiz = raiz_de_busca(vim.fs.dirname(consumidor))
  local candidatos = descobrir_candidatos(consumidor, raiz)

  if #candidatos == 0 then
    vim.notify("Nenhuma biblioteca .csproj candidata foi encontrada.", vim.log.levels.INFO)
    return
  end

  local opcoes = vim.tbl_map(function(caminho)
    return {
      caminho = caminho,
      rotulo = relativo(caminho, raiz),
    }
  end, candidatos)

  vim.ui.select(opcoes, {
    prompt = "Selecionar biblioteca para ProjectReference:",
    format_item = function(item)
      return item.rotulo
    end,
  }, function(escolha)
    if not escolha then
      vim.notify("Operacao cancelada.", vim.log.levels.WARN)
      return
    end

    local biblioteca = normalizar(escolha.caminho)

    if vim.fn.filereadable(biblioteca) ~= 1 then
      vim.notify("Biblioteca inexistente ou invalida:\n" .. biblioteca, vim.log.levels.ERROR)
      return
    end

    if biblioteca == consumidor then
      vim.notify("Autorreferencia nao permitida.", vim.log.levels.ERROR)
      return
    end

    tem_referencia(consumidor, biblioteca, function(existe, erro)
      if existe == nil then
        vim.notify("Nao foi possivel consultar as referencias:\n" .. vim.trim(erro), vim.log.levels.ERROR)
        return
      end

      if existe then
        vim.notify("ProjectReference ja existe.", vim.log.levels.WARN)
        return
      end

      executar(consumidor, biblioteca)
    end)
  end)
end

return M
