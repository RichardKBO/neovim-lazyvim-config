local M = {}

local reservadas = {
  ["and"] = true,
  ["or"] = true,
  ["not"] = true,
  ["in"] = true,
  ["if"] = true,
  ["elif"] = true,
  ["else"] = true,
  ["endif"] = true,
  ["foreach"] = true,
  ["endforeach"] = true,
  ["break"] = true,
  ["continue"] = true,
  ["true"] = true,
  ["false"] = true,
}

local function texto_valido(valor)
  return type(valor) == "string" and valor:find("%S") ~= nil and valor:find("%c") == nil
end

local function nome_alvo_valido(nome)
  return type(nome) == "string" and nome:match("^[%w_][%w_.%+%-]*$") ~= nil
end

local function exportacao_valida(nome)
  return type(nome) == "string" and nome:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil and not reservadas[nome]
end

-- Planejamento puro: recebe dados declarados, sem consultar projetos ou builds.
-- dados.consumidor: { sistema = "meson", raiz = "..." }
-- dados.origem: { sistema = "meson", raiz = "...",
--                 alvo = { name = "...", type = "static library" } }
-- dados.exportacao: nome explicito da variavel declare_dependency().
-- dados.destino: { id = "...", name = "...", type = "executable",
--                  top_level = true }
-- top_level e uma afirmacao explicita do chamador, nao uma descoberta.
-- Sucesso: plano, nil. Falha: nil, mensagem.
-- Nao comprova existencia, export real, ownership, symlinks ou ciclos gerais.
function M.planejar(dados)
  if type(dados) ~= "table" then
    return nil, "Dados da dependencia invalidos."
  end

  local consumidor = dados.consumidor
  local origem = dados.origem
  local destino = dados.destino

  if type(consumidor) ~= "table" then
    return nil, "Consumidor nao informado ou invalido."
  end

  if type(origem) ~= "table" then
    return nil, "Origem nao informada ou invalida."
  end

  if consumidor.sistema ~= "meson" or origem.sistema ~= "meson" then
    return nil, "Consumidor e origem devem ser projetos Meson."
  end

  if not texto_valido(consumidor.raiz) or not texto_valido(origem.raiz) then
    return nil, "Raizes do consumidor e da origem devem ser informadas sem caracteres de controle."
  end

  -- Comparacao apenas textual; ignora barras finais, sem resolver caminhos.
  local raiz_consumidor = consumidor.raiz:gsub("/+$", "")
  local raiz_origem = origem.raiz:gsub("/+$", "")

  if raiz_consumidor == raiz_origem then
    return nil, "Auto-referencia: consumidor e origem possuem a mesma raiz textual."
  end

  local biblioteca = origem.alvo

  if type(biblioteca) ~= "table" then
    return nil, "Target da biblioteca de origem nao informado ou invalido."
  end

  if biblioteca.type ~= "static library" then
    return nil, "Origem deve identificar uma biblioteca estatica Meson."
  end

  if not nome_alvo_valido(biblioteca.name) then
    return nil, "Nome do target da biblioteca invalido."
  end

  if not exportacao_valida(dados.exportacao) then
    return nil, "Exportacao invalida: informe um identificador Meson que nao seja reservado."
  end

  if type(destino) ~= "table" then
    return nil, "Target consumidor nao informado ou invalido."
  end

  if destino.type ~= "executable" then
    return nil, "Destino deve ser um executavel Meson."
  end

  if destino.top_level ~= true then
    return nil, "Destino deve ser explicitamente identificado como top-level."
  end

  if not texto_valido(destino.id) then
    return nil, "Identificador do target consumidor ausente ou invalido."
  end

  if not nome_alvo_valido(destino.name) then
    return nil, "Nome do target consumidor invalido."
  end

  -- Copiar somente campos validados; nao alterar nem compartilhar tabelas de entrada.
  return {
    consumidor = {
      sistema = "meson",
      raiz = consumidor.raiz,
    },
    origem = {
      sistema = "meson",
      raiz = origem.raiz,
      alvo = {
        name = biblioteca.name,
        type = biblioteca.type,
      },
    },
    exportacao = dados.exportacao,
    destino = {
      id = destino.id,
      name = destino.name,
      type = destino.type,
      top_level = true,
    },
  }, nil
end

-- Reconhecedor fechado do formato do laboratorio, nao um parser geral Meson.
-- Comentarios sao ignorados somente fora de strings simples na mesma linha.
local function linhas_meson(conteudo)
  if type(conteudo) ~= "string" or conteudo == "" then
    return nil
  end

  local original = conteudo
  conteudo = conteudo:gsub("\r\n", "\n")
  if conteudo:find("[\r%z]") then
    return nil
  end

  local linhas, trechos = {}, {}
  local inicio = 1
  for linha in (conteudo .. "\n"):gmatch("(.-)\n") do
    local quebra = original:find("\n", inicio, true)
    local eol = quebra and (original:sub(quebra - 1, quebra) == "\r\n" and "\r\n" or "\n") or ""
    local em_string = false
    local fim = #linha

    for indice = 1, #linha do
      local caractere = linha:sub(indice, indice)
      if caractere == "#" and not em_string then
        fim = indice - 1
        break
      elseif caractere == "\\" or caractere == '"' or linha:sub(indice, indice + 2) == "'''" then
        return nil
      elseif caractere == "'" then
        em_string = not em_string
      end
    end

    if em_string then
      return nil
    end

    local codigo = linha:sub(1, fim):gsub("%s+$", "")
    local texto = codigo:match("^%s*(.-)%s*$")
    if texto ~= "" then
      table.insert(linhas, texto)
      trechos[#linhas] = {
        inicio = inicio,
        fim_codigo = inicio + #codigo - 1,
        proxima_linha = quebra and quebra + 1 or #original + 1,
        indentacao = codigo:match("^%s*"),
        eol = eol,
      }
    end
    inicio = quebra and quebra + 1 or #original + 1
  end

  return linhas, trechos
end

local function cabecalho_valido(linhas)
  if not linhas or #linhas < 9 then
    return false
  end

  local padrao = linhas[6]:match("^'cpp_std=c%+%+(%d+)',$")
  return linhas[1] == "project("
    and linhas[2]:match("^'[%a_][%w_%-]*',$") ~= nil
    and linhas[3] == "'cpp',"
    and linhas[4] == "version: '1.0.0',"
    and linhas[5] == "default_options: ["
    and (padrao == "17" or padrao == "20" or padrao == "23")
    and linhas[7] == "'buildtype=debug',"
    and linhas[8] == "]"
    and linhas[9] == ")"
end

local function corresponde(linhas, declaracoes)
  if not cabecalho_valido(linhas) or #linhas ~= 9 + #declaracoes then
    return false
  end

  for indice, declaracao in ipairs(declaracoes) do
    if linhas[indice + 9] ~= declaracao then
      return false
    end
  end

  return true
end

local function origem_reconhecida(linhas, plano)
  if not linhas or #linhas ~= 19 then
    return false
  end

  local include = linhas[10]:match("^([A-Za-z_][A-Za-z0-9_]*) = include_directories%('include'%)$")
  local biblioteca = linhas[11]:match("^([A-Za-z_][A-Za-z0-9_]*) = static_library%($")
  if not exportacao_valida(include) or not exportacao_valida(biblioteca) then
    return false
  end

  if include == biblioteca or include == plano.exportacao or biblioteca == plano.exportacao then
    return false
  end

  if not linhas[13]:match("^'src/[%w_%-]+%.cpp',$") then
    return false
  end

  return corresponde(linhas, {
    include .. " = include_directories('include')",
    biblioteca .. " = static_library(",
    "'" .. plano.origem.alvo.name .. "',",
    linhas[13],
    "include_directories: " .. include,
    ")",
    plano.exportacao .. " = declare_dependency(",
    "link_with: " .. biblioteca .. ",",
    "include_directories: " .. include,
    ")",
  })
end

local function consumidor_reconhecido(linhas, plano, dados)
  if not linhas or (#linhas ~= 16 and #linhas ~= 18) then
    return false
  end

  local gerado = #linhas == 18
  local fonte = gerado and "'src/main.cpp'," or linhas[14]
  if not fonte:match("^'src/[%w_%-]+%.cpp',$") then
    return false
  end
  if gerado and (dados.variavel_subprojeto == "inc" or dados.variavel_dependencia == "inc") then
    return false
  end

  local declaracoes = {
    dados.variavel_subprojeto .. " = subproject('" .. dados.alias .. "')",
    dados.variavel_dependencia .. " = " .. dados.variavel_subprojeto .. ".get_variable('" .. plano.exportacao .. "')",
    "executable(",
    "'" .. plano.destino.name .. "',",
    fonte,
  }
  if gerado then
    table.insert(declaracoes, 1, "inc = include_directories('include')")
    table.insert(declaracoes, "include_directories: inc,")
  end
  table.insert(declaracoes, "dependencies: " .. dados.variavel_dependencia)
  table.insert(declaracoes, ")")
  return corresponde(linhas, declaracoes)
end

-- Verificacao lexical apenas; a identidade fisica e informada pelo coletor.
local function raiz_absoluta_simples(raiz)
  if not texto_valido(raiz) or raiz:sub(1, 1) ~= "/" or raiz:sub(-1) == "/" or raiz:find("//", 1, true) then
    return false
  end

  for parte in raiz:gmatch("[^/]+") do
    if parte == "." or parte == ".." then
      return false
    end
  end

  return true
end

local function destino_relativo(consumidor, origem)
  local base, alvo, partes = {}, {}, {}
  for parte in (consumidor .. "/subprojects"):gmatch("[^/]+") do
    table.insert(base, parte)
  end
  for parte in origem:gmatch("[^/]+") do
    table.insert(alvo, parte)
  end
  local comum = 1
  while base[comum] and base[comum] == alvo[comum] do
    comum = comum + 1
  end
  for _ = comum, #base do
    table.insert(partes, "..")
  end
  for indice = comum, #alvo do
    table.insert(partes, alvo[indice])
  end
  return table.concat(partes, "/")
end

local function insercao_simples(linhas, trechos, plano, dados, conteudo)
  if not corresponde(linhas, {
    "inc = include_directories('include')",
    "executable(",
    "'" .. plano.destino.name .. "',",
    "'src/main.cpp',",
    "include_directories: inc",
    ")",
  }) or dados.variavel_subprojeto == "inc" or dados.variavel_dependencia == "inc" then
    return nil, "Consumidor nao corresponde ao template simples ou possui variaveis conflitantes."
  end

  local abertura, include = trechos[11], trechos[14]
  if abertura.eol == "" or include.eol == "" then
    return nil, "Quebras de linha insuficientes para insercao segura."
  end

  local declaracoes = abertura.indentacao .. dados.variavel_subprojeto .. " = subproject('" .. dados.alias .. "')"
    .. abertura.eol .. abertura.indentacao .. dados.variavel_dependencia .. " = " .. dados.variavel_subprojeto
    .. ".get_variable('" .. plano.exportacao .. "')" .. abertura.eol .. abertura.eol
  local edicoes = {
    { posicao = abertura.inicio, anterior = "", posterior = declaracoes },
    { posicao = include.fim_codigo + 1, anterior = "", posterior = "," },
    { posicao = include.proxima_linha, anterior = "", posterior = include.indentacao
      .. "dependencies: " .. dados.variavel_dependencia .. include.eol },
  }
  local posterior = conteudo
  for indice = #edicoes, 1, -1 do
    local edicao = edicoes[indice]
    posterior = posterior:sub(1, edicao.posicao - 1) .. edicao.posterior .. posterior:sub(edicao.posicao)
  end
  return {
    caminho = plano.consumidor.raiz .. "/meson.build",
    conteudo_anterior = conteudo,
    conteudo_posterior = posterior,
    edicoes = edicoes,
  }, nil
end

local function nao_reconhecida(mensagem)
  return nil, mensagem .. " Insercao nao implementada para este caso."
end

-- Dados adicionais: alias, variavel_subprojeto e variavel_dependencia.
-- snapshots.consumidor/origem: { caminho, conteudo }.
-- snapshots.raizes: { consumidor, origem }, canonicas segundo o coletor.
-- snapshots.link: { caminho, estado = 'link', destino_literal, destino_canonico }
-- ou { caminho, estado = 'ausente' }, sem destinos ou colisao declarados.
-- Reconhece laboratorio e saida da insercao, com link absoluto ou relativo exato.
-- Propoe insercao apenas no template simples, sem alterar links existentes.
-- Propostas e precondicoes nao comprovam ausencia/identidade fisica atual.
-- Nao consulta disco/vim, nao executa projetos e nao altera as entradas.
function M.propor_alteracao(dados, snapshots)
  local plano, erro = M.planejar(dados)
  if not plano then
    return nao_reconhecida(erro)
  end

  if not nome_alvo_valido(dados.alias)
    or not exportacao_valida(dados.variavel_subprojeto)
    or not exportacao_valida(dados.variavel_dependencia)
    or dados.variavel_subprojeto == dados.variavel_dependencia
  then
    return nao_reconhecida("Alias ou variaveis locais invalidos ou conflitantes.")
  end

  if type(snapshots) ~= "table"
    or type(snapshots.raizes) ~= "table"
    or type(snapshots.consumidor) ~= "table"
    or type(snapshots.origem) ~= "table"
    or type(snapshots.link) ~= "table"
  then
    return nao_reconhecida("Snapshots de arquivos, raizes e link devem ser informados.")
  end

  local consumidor = snapshots.consumidor
  local origem = snapshots.origem
  local raizes = snapshots.raizes
  local link = snapshots.link

  if not raiz_absoluta_simples(raizes.consumidor)
    or not raiz_absoluta_simples(raizes.origem)
    or raizes.consumidor ~= plano.consumidor.raiz
    or raizes.origem ~= plano.origem.raiz
  then
    return nao_reconhecida("Raizes absolutas dos snapshots divergem da solicitacao ou nao sao suportadas.")
  end

  if consumidor.caminho ~= raizes.consumidor .. "/meson.build" or origem.caminho ~= raizes.origem .. "/meson.build" then
    return nao_reconhecida("Caminhos dos snapshots nao correspondem aos meson.build esperados.")
  end

  if link.caminho ~= raizes.consumidor .. "/subprojects/" .. dados.alias
    or (link.colisao ~= nil and link.colisao ~= false)
    or (link.estado ~= "link" and link.estado ~= "ausente")
  then
    return nao_reconhecida("Estado ou caminho do link invalido, ou colisao declarada.")
  end
  if link.estado == "link" then
    local relativo_esperado = destino_relativo(raizes.consumidor, raizes.origem)
    if (link.destino_literal ~= raizes.origem and link.destino_literal ~= relativo_esperado)
      or link.destino_canonico ~= raizes.origem
    then
      return nao_reconhecida("Link existente nao corresponde ao alias e a origem esperados.")
    end
  end
  if link.estado == "ausente" and (link.destino_literal ~= nil or link.destino_canonico ~= nil) then
    return nao_reconhecida("Link declarado ausente possui destino informado.")
  end

  if not origem_reconhecida(linhas_meson(origem.conteudo), plano) then
    return nao_reconhecida("Biblioteca estatica e export nao reconhecidos no formato suportado.")
  end

  local linhas, trechos = linhas_meson(consumidor.conteudo)
  if link.estado == "link" then
    if not consumidor_reconhecido(linhas, plano, dados) then
      return nao_reconhecida("Integracao completa do executavel nao reconhecida no formato suportado.")
    end
    plano.estado = "sem_alteracao"
    plano.alteracoes = {}
    plano.link = {
      acao = "manter",
      caminho = link.caminho,
      destino_literal = link.destino_literal,
      destino_canonico = link.destino_canonico,
    }
  else
    if raizes.origem:sub(1, #raizes.consumidor + 1) == raizes.consumidor .. "/"
      or raizes.consumidor:sub(1, #raizes.origem + 1) == raizes.origem .. "/"
    then
      return nao_reconhecida("Raizes aninhadas nao sao suportadas para nova dependencia independente.")
    end
    local alteracao, erro_insercao = insercao_simples(linhas, trechos, plano, dados, consumidor.conteudo)
    if not alteracao then
      return nao_reconhecida(erro_insercao)
    end
    plano.estado = "alterar"
    plano.alteracoes = { alteracao }
    plano.link = {
      acao = "criar",
      caminho = link.caminho,
      destino_literal = destino_relativo(raizes.consumidor, raizes.origem),
      destino_canonico = raizes.origem,
    }
  end

  -- M.planejar devolve tabelas novas; snapshots sao copiados somente por campos.
  plano.alias = dados.alias
  plano.variavel_subprojeto = dados.variavel_subprojeto
  plano.variavel_dependencia = dados.variavel_dependencia
  plano.precondicoes = {
    consumidor = { caminho = consumidor.caminho, conteudo = consumidor.conteudo },
    origem = { caminho = origem.caminho, conteudo = origem.conteudo },
    raizes = { consumidor = raizes.consumidor, origem = raizes.origem },
    link = {
      caminho = link.caminho,
      estado = link.estado,
      destino_literal = link.destino_literal,
      destino_canonico = link.destino_canonico,
    },
  }
  if link.estado == "ausente" then
    plano.precondicoes.link.colisao = link.colisao
  end

  return plano, nil
end

return M
