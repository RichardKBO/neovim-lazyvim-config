local M = {}

-- vim.json.decode preserva JSON null como vim.NIL por padrao.
local nulo_json = vim.NIL

local function texto_valido(valor)
  return type(valor) == "string" and valor:find("%S") ~= nil and valor:find("%c") == nil
end

-- Apenas forma lexical; canonicidade e identidade fisica pertencem ao coletor.
local function caminho_absoluto(caminho)
  if not texto_valido(caminho) or caminho:sub(1, 1) ~= "/" or caminho:sub(-1) == "/" or caminho:find("//", 1, true) then
    return false
  end
  for parte in caminho:gmatch("[^/]+") do
    if parte == "." or parte == ".." then
      return false
    end
  end
  return true
end

-- dados: consumidor = { raiz = "/..." }, diretorio_build = "/...",
--        destino = { id = "...", name = "..." }.
-- destino.type/top_level sao opcionais; quando presentes, devem ser coerentes.
-- inventario: alvos = lista de intro-targets.json,
--             meson_info = objeto de meson-info.json, ambos ja decodificados.
-- Exige null explicito como vim.NIL; nao aceitar decode que o elimine.
-- Sucesso: { id, name, type = "executable", top_level = true }, nil.
-- Falha: nil, mensagem. Nao altera entradas, consulta disco ou executa processos.
-- Valida coerencia dos dados fornecidos, nao sua autenticidade/atualidade.
-- O coletor deve vincular os JSONs ao mesmo build e comprovar identidade fisica;
-- a futura aplicacao devera revalidar inventario, caminhos e declaracao.
function M.validar(dados, inventario)
  if type(dados) ~= "table" or type(dados.consumidor) ~= "table" or type(dados.destino) ~= "table" then
    return nil, "Consumidor e destino devem ser informados."
  end

  local esperado = dados.destino
  if not texto_valido(esperado.id) then
    return nil, "ID selecionado ausente ou invalido."
  end
  if type(esperado.name) ~= "string" or not esperado.name:match("^[%w_][%w_.%+%-]*$") then
    return nil, "Nome esperado do executavel invalido."
  end
  if (esperado.type ~= nil and esperado.type ~= "executable") or (esperado.top_level ~= nil and esperado.top_level ~= true) then
    return nil, "Tipo ou pertencimento esperado do target inconsistente."
  end

  local consumidor = dados.consumidor.raiz
  local build = dados.diretorio_build
  if not caminho_absoluto(consumidor) or not caminho_absoluto(build) or consumidor == build then
    return nil, "Raizes canonicas declaradas de source/build invalidas ou coincidentes."
  end
  if type(inventario) ~= "table" or type(inventario.alvos) ~= "table" or type(inventario.meson_info) ~= "table" then
    return nil, "Inventario deve conter alvos e meson_info decodificados."
  end

  local info = inventario.meson_info
  if info.error ~= false then
    return nil, "meson_info deve informar error=false explicitamente."
  end
  if type(info.directories) ~= "table" or info.directories.source ~= consumidor or info.directories.build ~= build then
    return nil, "Diretorios source/build do inventario ausentes ou divergentes das raizes fornecidas."
  end

  -- Conferir lista densa, sem truncar silenciosamente em buracos de ipairs.
  local quantidade = 0
  for indice, alvo in pairs(inventario.alvos) do
    if type(indice) ~= "number" or indice < 1 or indice % 1 ~= 0 or type(alvo) ~= "table" then
      return nil, "Inventario de targets deve ser uma lista de objetos."
    end
    quantidade = quantidade + 1
  end

  local vistos = {}
  local selecionado
  for indice = 1, quantidade do
    local alvo = rawget(inventario.alvos, indice)
    if type(alvo) ~= "table" then
      return nil, "Inventario de targets possui indices ausentes."
    end
    local id = rawget(alvo, "id")
    if not texto_valido(id) then
      return nil, "Target no inventario possui ID ausente ou invalido."
    end
    if vistos[id] then
      return nil, "Inventario possui ID de target duplicado: " .. id
    end
    vistos[id] = true

    if not texto_valido(rawget(alvo, "name")) or not texto_valido(rawget(alvo, "type")) or not texto_valido(rawget(alvo, "defined_in")) then
      return nil, "Target possui name, type ou defined_in ausente ou invalido."
    end
    local subprojeto = rawget(alvo, "subproject")
    if subprojeto == nil then
      return nil, "Campo subproject ausente; ausencia nao comprova projeto principal."
    end
    if subprojeto ~= nulo_json and not texto_valido(subprojeto) then
      return nil, "Campo subproject deve ser null explicito ou nome de subprojeto."
    end
    if id == esperado.id then
      selecionado = alvo
    end
  end

  if not selecionado then
    return nil, "ID selecionado nao encontrado no inventario."
  end
  if rawget(selecionado, "type") ~= "executable" then
    return nil, "Target selecionado nao e executavel."
  end
  if rawget(selecionado, "name") ~= esperado.name then
    return nil, "ID selecionado corresponde a nome diferente do esperado."
  end
  if rawget(selecionado, "subproject") ~= nulo_json then
    return nil, "Target selecionado pertence a um subprojeto."
  end
  if rawget(selecionado, "defined_in") ~= consumidor .. "/meson.build" then
    return nil, "Target nao esta declarado no meson.build da raiz consumidora."
  end

  return {
    id = rawget(selecionado, "id"),
    name = rawget(selecionado, "name"),
    type = "executable",
    top_level = true,
  }, nil
end

return M
