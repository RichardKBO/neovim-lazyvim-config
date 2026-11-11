local M = {}

local targets = require("languages.cpp.meson.dependency_targets")
local paths = require("languages.cpp.meson.dependency_paths")
local uv = vim.uv

local nomes_json = {
  info = "meson-info.json",
  alvos = "intro-targets.json",
  projeto = "intro-projectinfo.json",
  inputs = "intro-buildsystem_files.json",
  opcoes = "intro-buildoptions.json",
}

local function recusar(estado, mensagem)
  return nil, {
    estado = estado,
    mensagem = mensagem,
    atualidade_inventario = "nao_comprovada",
    autorizada_para_aplicacao = false,
  }
end

local function absoluto(caminho)
  return type(caminho) == "string" and caminho:sub(1, 1) == "/"
    and caminho ~= "/" and not caminho:find("%c") and vim.fs.normalize(caminho) == caminho
end

local function identidade(info, arquivo)
  local valor = { type = info.type, dev = info.dev, ino = info.ino, mode = info.mode }
  if arquivo then
    valor.size, valor.mtime, valor.ctime = info.size, info.mtime, info.ctime
  end
  return valor
end

local function diretorio(caminho)
  if not absoluto(caminho) then
    return recusar("incoerente", "Diretorio absoluto e normalizado exigido.")
  end
  local info, erro, codigo = uv.fs_lstat(caminho)
  if not info then
    return recusar(codigo == "ENOENT" and "ausente" or "incoerente", tostring(erro))
  end
  if info.type ~= "directory" or info.dev == nil or info.ino == nil or uv.fs_realpath(caminho) ~= caminho then
    return recusar("incoerente", "Diretorio redirecionado ou sem identidade: " .. caminho)
  end
  return { caminho = caminho, identidade = identidade(info) }, nil
end

local function ler(caminho)
  local antes, erro, codigo = uv.fs_lstat(caminho)
  if not antes then
    return recusar(codigo == "ENOENT" and "ausente" or "incoerente", tostring(erro))
  end
  if antes.type ~= "file" or antes.dev == nil or antes.ino == nil or uv.fs_realpath(caminho) ~= caminho then
    return recusar("incoerente", "Arquivo regular canonico exigido: " .. caminho)
  end
  local arquivo, erro_abrir = io.open(caminho, "rb")
  if not arquivo then
    return recusar("incoerente", "Falha ao abrir " .. caminho .. ": " .. tostring(erro_abrir))
  end
  local conteudo, erro_ler = arquivo:read("*a")
  local fechou, erro_fechar = arquivo:close()
  if not conteudo or not fechou then
    return recusar("incoerente", "Falha ao ler/fechar " .. caminho .. ": " .. tostring(erro_ler or erro_fechar))
  end
  local depois = uv.fs_lstat(caminho)
  if not depois or uv.fs_realpath(caminho) ~= caminho or #conteudo ~= antes.size
    or not vim.deep_equal(identidade(antes, true), identidade(depois, true))
  then
    return recusar("alterado", "Arquivo mudou durante a leitura: " .. caminho)
  end
  return { caminho = caminho, conteudo = conteudo, identidade = identidade(antes, true) }, nil
end

local function relativo(base, destino)
  local a, b, partes = {}, {}, {}
  for parte in base:gmatch("[^/]+") do a[#a + 1] = parte end
  for parte in destino:gmatch("[^/]+") do b[#b + 1] = parte end
  local comum = 1
  while a[comum] and a[comum] == b[comum] do comum = comum + 1 end
  for _ = comum, #a do partes[#partes + 1] = ".." end
  for i = comum, #b do partes[#partes + 1] = b[i] end
  return table.concat(partes, "/")
end

-- Excecao somente para o manifesto do alias explicitamente selecionado.
-- Os demais caminhos continuam sujeitos a ler(), sem redirecionamentos.
local function ler_input(caminho, selecao)
  if not selecao or caminho ~= selecao.consumidor.raiz .. "/subprojects/" .. selecao.alias .. "/meson.build" then
    return ler(caminho)
  end
  local origem, erro_origem = diretorio(selecao.origem.raiz)
  if not origem then return nil, erro_origem end
  local fisico, erro = paths.inspecionar(selecao)
  if not fisico then
    return recusar("incoerente", "Subprojeto selecionado recusado: " .. tostring(erro))
  end
  local canonico = origem.caminho .. "/meson.build"
  if fisico.raizes.consumidor ~= selecao.consumidor.raiz or fisico.raizes.origem ~= origem.caminho
    or fisico.subprojects.estado ~= "diretorio" or fisico.link.estado ~= "link"
    or fisico.link.caminho .. "/meson.build" ~= caminho
    or fisico.link.destino_canonico ~= origem.caminho
    or fisico.link.destino_literal ~= relativo(fisico.subprojects.caminho, origem.caminho)
    or fisico.identidades.origem.dev ~= origem.identidade.dev
    or fisico.identidades.origem.ino ~= origem.identidade.ino
    or uv.fs_realpath(caminho) ~= canonico
  then
    return recusar("incoerente", "Referencia nao corresponde ao symlink relativo selecionado: " .. caminho)
  end
  local relatado = uv.fs_lstat(caminho)
  local snapshot, erro_leitura = ler(canonico)
  if not snapshot then return nil, erro_leitura end
  if not relatado or relatado.type ~= "file"
    or not vim.deep_equal(identidade(relatado, true), snapshot.identidade)
  then
    return recusar("alterado", "Manifesto relatado nao corresponde ao objeto canonico selecionado.")
  end
  local depois = uv.fs_lstat(caminho)
  local origem_depois = diretorio(origem.caminho)
  local fisico_depois = paths.inspecionar(selecao)
  if not depois or uv.fs_realpath(caminho) ~= canonico
    or not vim.deep_equal(identidade(depois, true), snapshot.identidade)
    or not vim.deep_equal(origem, origem_depois) or not vim.deep_equal(fisico, fisico_depois)
  then
    return recusar("alterado", "Identidade ou referencia do subprojeto mudou durante a leitura.")
  end
  snapshot.caminho = caminho
  snapshot.subprojeto = {
    alias = selecao.alias, manifesto_canonico = canonico,
    origem = origem, referencia = fisico,
  }
  return snapshot, nil
end

local function lista(valor)
  if type(valor) ~= "table" then
    return false
  end
  local quantidade = 0
  for chave in pairs(valor) do
    if type(chave) ~= "number" or chave < 1 or chave % 1 ~= 0 then
      return false
    end
    quantidade = quantidade + 1
  end
  for indice = 1, quantidade do
    if rawget(valor, indice) == nil then
      return false
    end
  end
  return true
end

-- Verifica cobertura dos snapshots conhecidos, sem autenticar sua origem.
local function cobertura(evidencia, atual)
  if type(evidencia) ~= "table" or evidencia.versao ~= 1
    or type(evidencia.diretorios) ~= "table" or type(evidencia.arquivos) ~= "table"
    or type(evidencia.ausencias) ~= "table" or not lista(evidencia.inputs_conhecidos)
    or type(evidencia.destino) ~= "table"
  then
    return false
  end
  for nome in pairs(atual.diretorios) do
    local item = evidencia.diretorios[nome]
    if type(item) ~= "table" or type(item.caminho) ~= "string" or type(item.identidade) ~= "table" then
      return false
    end
  end
  for caminho in pairs(atual.arquivos) do
    local item = evidencia.arquivos[caminho]
    if type(item) ~= "table" or item.caminho ~= caminho or type(item.conteudo) ~= "string"
      or type(item.identidade) ~= "table" or item.identidade.dev == nil or item.identidade.ino == nil
      or item.identidade.size == nil or item.identidade.mtime == nil or item.identidade.ctime == nil
    then
      return false
    end
  end
  for caminho in pairs(atual.ausencias) do
    if evidencia.ausencias[caminho] ~= true then
      return false
    end
  end
  return true
end

local function verificar(dados, evidencia)
  if type(dados) ~= "table" or type(dados.consumidor) ~= "table" or type(dados.destino) ~= "table" then
    return recusar("incoerente", "Informe consumidor.raiz, diretorio_build e destino.id/name.")
  end
  local consumidor, erro_consumidor = diretorio(dados.consumidor.raiz)
  if not consumidor then
    return nil, erro_consumidor
  end
  local build, erro_build = diretorio(dados.diretorio_build)
  if not build then
    return nil, erro_build
  end
  if consumidor.caminho == build.caminho
    or (consumidor.identidade.dev == build.identidade.dev and consumidor.identidade.ino == build.identidade.ino)
  then
    return recusar("incoerente", "Consumidor e build devem ser diretorios distintos.")
  end

  local selecao
  if dados.origem ~= nil or dados.alias ~= nil then
    if type(dados.origem) ~= "table" or not absoluto(dados.origem.raiz)
      or type(dados.alias) ~= "string" or not dados.alias:match("^[A-Za-z0-9_][A-Za-z0-9_.%+%-]*$")
    then
      return recusar("incoerente", "Informe origem.raiz canonica e alias seguro juntos.")
    end
    selecao = {
      consumidor = { raiz = consumidor.caminho },
      origem = { raiz = dados.origem.raiz }, alias = dados.alias,
    }
  end

  local observacao = {
    versao = 1,
    diretorios = { consumidor = consumidor, build = build },
    arquivos = {},
    inputs_conhecidos = {},
    ausencias = {},
  }
  for nome, sufixo in pairs({ info = "meson-info", privado = "meson-private" }) do
    local pasta, erro = diretorio(build.caminho .. "/" .. sufixo)
    if not pasta then
      return nil, erro
    end
    observacao.diretorios[nome] = pasta
  end

  local jsons = {}
  for nome, arquivo in pairs(nomes_json) do
    local caminho = build.caminho .. "/meson-info/" .. arquivo
    local snapshot, erro = ler(caminho)
    if not snapshot then
      return nil, erro
    end
    local ok, valor = pcall(vim.json.decode, snapshot.conteudo)
    if not ok or type(valor) ~= "table" then
      return recusar("incoerente", "JSON invalido: " .. caminho)
    end
    observacao.arquivos[caminho], jsons[nome] = snapshot, valor
  end

  local info = jsons.info
  local introspeccao = info.introspection
  if type(info.directories) ~= "table" or info.directories.info ~= build.caminho .. "/meson-info"
    or type(info.meson_version) ~= "table" or type(info.meson_version.full) ~= "string"
    or info.meson_version.full == "" or type(introspeccao) ~= "table"
    or type(introspeccao.version) ~= "table" or introspeccao.version.full ~= "1.0.0"
    or type(introspeccao.information) ~= "table"
  then
    return recusar("incoerente", "Metadados Meson ausentes, divergentes ou formato nao suportado.")
  end
  for chave, nome in pairs({
    targets = nomes_json.alvos, projectinfo = nomes_json.projeto,
    buildsystem_files = nomes_json.inputs, buildoptions = nomes_json.opcoes,
  }) do
    local descritor = introspeccao.information[chave]
    if type(descritor) ~= "table" or descritor.file ~= nome then
      return recusar("incoerente", "Descritor de introspeccao divergente: " .. chave)
    end
  end

  local destino, erro_destino = targets.validar({
    consumidor = { raiz = consumidor.caminho },
    diretorio_build = build.caminho,
    destino = dados.destino,
  }, { alvos = jsons.alvos, meson_info = info })
  if not destino then
    return recusar("incoerente", "Identidade do target: " .. tostring(erro_destino))
  end
  observacao.destino = destino

  local projeto = jsons.projeto
  if type(projeto.descriptive_name) ~= "string" or projeto.descriptive_name == ""
    or type(projeto.version) ~= "string" or not lista(projeto.subprojects)
    or projeto.subproject_dir ~= "subprojects" or not lista(jsons.opcoes)
    or not lista(jsons.inputs) or #jsons.inputs == 0
  then
    return recusar("incoerente", "Informacoes de projeto, opcoes ou inputs ausentes/nao suportadas.")
  end

  local vistos = {}
  for _, caminho in ipairs(jsons.inputs) do
    if not absoluto(caminho) or caminho:sub(1, #consumidor.caminho + 1) ~= consumidor.caminho .. "/"
      or vistos[caminho] then
      return recusar("incoerente", "Input duplicado ou fora da raiz canonica suportada.")
    end
    vistos[caminho] = true
    local snapshot, erro = ler_input(caminho, selecao)
    if not snapshot then
      return nil, erro
    end
    if snapshot.subprojeto then
      local declaracoes, bibliotecas = 0, 0
      for _, sub in ipairs(projeto.subprojects) do
        if type(sub) == "table" and sub.name == selecao.alias then declaracoes = declaracoes + 1 end
      end
      for _, alvo in ipairs(jsons.alvos) do
        if alvo.subproject == selecao.alias and alvo.type == "static library" and alvo.defined_in == caminho then
          bibliotecas = bibliotecas + 1
        end
      end
      if declaracoes ~= 1 or bibliotecas == 0 then
        return recusar("incoerente", "Alias/manifesto selecionado nao corresponde ao subprojeto e biblioteca do inventario.")
      end
    end
    observacao.arquivos[caminho] = snapshot
    table.insert(observacao.inputs_conhecidos, caminho)
  end
  if not vistos[consumidor.caminho .. "/meson.build"] then
    return recusar("incoerente", "Manifesto consumidor ausente do inventario de inputs.")
  end
  table.sort(observacao.inputs_conhecidos)

  for _, nome in ipairs({ "meson.options", "meson_options.txt" }) do
    local caminho = consumidor.caminho .. "/" .. nome
    local existe, erro, codigo = uv.fs_lstat(caminho)
    if existe then
      if not vistos[caminho] then
        return recusar("alterado", "Arquivo de opcoes presente mas nao inventariado: " .. caminho)
      end
    elseif codigo == "ENOENT" then
      observacao.ausencias[caminho] = true
    else
      return recusar("incoerente", "Falha ao inspecionar opcoes: " .. tostring(erro))
    end
  end
  for _, nome in ipairs({ "cmd_line.txt", "coredata.dat" }) do
    local caminho = build.caminho .. "/meson-private/" .. nome
    local snapshot, erro = ler(caminho)
    if not snapshot then
      return nil, erro
    end
    observacao.arquivos[caminho] = snapshot
  end

  -- Segunda passagem detecta mudancas observaveis entre as leituras.
  -- Nao fornece snapshot atomico nem protege contra escritores externos.
  for caminho, anterior in pairs(observacao.arquivos) do
    local atual, erro = ler_input(caminho, selecao)
    if not atual or not vim.deep_equal(anterior, atual) then
      return recusar("alterado", "Conjunto mudou durante a coleta: " .. caminho
        .. (erro and " (" .. erro.mensagem .. ")" or ""))
    end
  end
  for _, anterior in pairs(observacao.diretorios) do
    local atual = diretorio(anterior.caminho)
    if not atual or not vim.deep_equal(anterior, atual) then
      return recusar("alterado", "Diretorio mudou durante a coleta: " .. anterior.caminho)
    end
  end
  for caminho in pairs(observacao.ausencias) do
    local existe, _, codigo = uv.fs_lstat(caminho)
    if existe or codigo ~= "ENOENT" then
      return recusar("alterado", "Ausencia deixou de ser comprovavel: " .. caminho)
    end
  end

  local correspondencia = evidencia == nil and "nao_fornecida" or "insuficiente"
  if evidencia ~= nil and cobertura(evidencia, observacao) then
    if evidencia.diretorios.consumidor.caminho ~= consumidor.caminho
      or evidencia.diretorios.build.caminho ~= build.caminho
      or not vim.deep_equal(evidencia.destino, destino)
    then
      return recusar("incoerente", "Evidencia pertence a outro consumidor/build ou selecao de target.")
    end
    if not vim.deep_equal(evidencia, observacao) then
      return recusar("alterado", "Conteudos, identidades, inputs ou ausencias divergem da evidencia.")
    end
    correspondencia = "correspondente"
  end

  return {
    estado = "coerente",
    destino = vim.deepcopy(destino),
    observacao = observacao,
    correspondencia_evidencia = correspondencia,
    evidencia_configuracao = "insuficiente",
    cobertura_inputs = "parcial",
    proveniencia_configuracao = "nao_verificada",
    atualidade_inventario = "nao_comprovada",
    autorizada_para_aplicacao = false,
  }, nil
end

-- M.verificar(dados, evidencia_opcional) -> resultado, nil OU nil, erro.
-- dados = { consumidor = { raiz = "/..." }, diretorio_build = "/...",
--           destino = { id = "...", name = "..." } }.
-- Par opcional origem={raiz="/..."}, alias="...": permite somente o manifesto
-- do subprojeto selecionado via link relativo exato; evidencias ficam no snapshot.
-- Erro = { estado = ausente|incoerente|alterado, mensagem, flags conservadoras }.
-- Resultado coerente descreve somente os arquivos observados, nao um setup.
-- evidencia_opcional tem o formato exato de resultado.observacao (versao 1):
-- diretorios, arquivos por caminho com conteudo/identidade, inputs_conhecidos,
-- ausencias e destino. A futura coordenacao deve captura-la durante o setup.
-- Uma tabela do chamador, mesmo completa e igual, nao autentica essa captura.
-- cmd_line/coredata/opcoes sao comparados como dados; nao se interpretam
-- configuracoes native/cross, ambiente, toolchain ou inputs dinamicos.
-- Por isso cobertura/proveniencia continuam insuficientes para atestar atualidade.
-- Nunca usa flags de sucesso, timestamps ou updated=true como prova de setup.
-- Nao configura, chama CLI, escreve, modifica entradas ou autoriza aplicacao.
function M.verificar(dados, evidencia)
  local ok, resultado, erro = pcall(verificar, dados, evidencia)
  if not ok then
    return recusar("incoerente", "Falha na verificacao do inventario: " .. tostring(resultado))
  end
  return resultado, erro
end

-- Coordenacao opt-in: nao e chamada por M.verificar() nem ao carregar o modulo.
-- dados tem o mesmo formato de M.verificar(); campos extras nao sao evidencias.
-- Retorno imediato: true se o processo iniciou; caso contrario false, detalhe.
-- Com callback valido, callback(resultado) e agendado uma unica vez, inclusive
-- nas recusas preliminares. Callback invalido nao e chamado.
-- Estados: erro_validacao, erro_inicializacao, falha_meson, erro_verificacao,
-- alterado ou sucesso. O sucesso exige processo bem-sucedido, inventario
-- coerente e preservacao dos inputs conhecidos entre as duas observacoes.
-- Evidencias sao coletadas nesta chamada, nao recebidas como prova do chamador.
-- Nao sao um recibo autenticado para terceiros, nem um snapshot atomico.
-- Cobertura parcial/atualidade nao comprovada SEMPRE impedem autorizacao.
function M.reconfigurar_e_verificar(dados, callback)
  local function resposta(estado, mensagem)
    return {
      estado = estado,
      mensagem = mensagem,
      reconfiguracao_bem_sucedida = false,
      inventario_coerente = false,
      cobertura_inputs = "parcial",
      proveniencia_configuracao = "nao_observada",
      atualidade_inventario = "nao_comprovada",
      autorizada_para_aplicacao = false,
    }
  end

  if type(callback) ~= "function" then
    return false, resposta("erro_validacao", "Callback invalido.")
  end
  local finalizado = false
  local function entregar(resultado)
    if finalizado then
      return
    end
    local copia = vim.deepcopy(resultado)
    finalizado = true
    vim.schedule(function()
      callback(copia)
    end)
  end
  local function falhar(estado, mensagem, detalhe)
    local resultado = resposta(estado, mensagem)
    resultado.detalhe = detalhe
    entregar(resultado)
    return false, resultado
  end

  if type(dados) ~= "table" or type(dados.consumidor) ~= "table" or type(dados.destino) ~= "table" then
    return falhar("erro_validacao", "Informe consumidor, diretorio_build e identidade do target.")
  end
  -- Conservar somente os campos do contrato. Nao reter tabelas do chamador.
  local pedido = {
    consumidor = { raiz = dados.consumidor.raiz },
    origem = type(dados.origem) == "table" and { raiz = dados.origem.raiz } or dados.origem,
    alias = dados.alias,
    diretorio_build = dados.diretorio_build,
    destino = {
      id = dados.destino.id, name = dados.destino.name,
      type = dados.destino.type, top_level = dados.destino.top_level,
    },
  }
  local previa, erro_previo = M.verificar(pedido, nil)
  if not previa then
    return falhar("erro_validacao", "Inventario preliminar recusado.", erro_previo)
  end

  local carregou, build = pcall(require, "languages.cpp.meson.build")
  if not carregou or type(build) ~= "table" or type(build.reconfigurar_explicitamente) ~= "function" then
    return falhar("erro_inicializacao", "API de reconfiguracao explicita indisponivel.")
  end

  local recebido = false
  local function conferir(processo)
    local resultado = resposta("erro_inicializacao", "Resultado de processo invalido.")
    resultado.evidencias = {
      observacao_antes = previa.observacao,
    }
    if type(processo) ~= "table" then
      return resultado
    end
    resultado.evidencias.processo = vim.deepcopy(processo)
    if processo.estado == "erro_validacao" or processo.estado == "erro_inicializacao"
      or processo.estado == "falha_meson"
    then
      resultado.estado = processo.estado
      resultado.mensagem = processo.mensagem
      if processo.processo_iniciado == true and type(processo.code) == "number" then
        resultado.proveniencia_configuracao = "processo_observado_nesta_operacao"
      end
      return resultado
    end
    if processo.estado ~= "sucesso" or processo.processo_iniciado ~= true or processo.code ~= 0
      or (processo.signal ~= nil and processo.signal ~= 0)
    then
      return resultado
    end
    resultado.reconfiguracao_bem_sucedida = true
    resultado.proveniencia_configuracao = "processo_observado_nesta_operacao"

    local atual, erro_atual = M.verificar(pedido, nil)
    if not atual then
      resultado.estado = "erro_verificacao"
      resultado.mensagem = "Reconfiguracao concluida, mas o inventario posterior foi recusado."
      resultado.detalhe = erro_atual
      return resultado
    end
    resultado.inventario_coerente = true
    resultado.inventario = atual
    resultado.evidencias.observacao_depois = atual.observacao
    resultado.evidencias.proveniencia_observacoes = "coletadas_nesta_operacao"

    local antes, depois = previa.observacao, atual.observacao
    local preservados = vim.deep_equal(antes.diretorios, depois.diretorios)
      and vim.deep_equal(antes.destino, depois.destino)
      and vim.deep_equal(antes.inputs_conhecidos, depois.inputs_conhecidos)
      and vim.deep_equal(antes.ausencias, depois.ausencias)
    if preservados then
      for _, caminho in ipairs(antes.inputs_conhecidos) do
        if not vim.deep_equal(antes.arquivos[caminho], depois.arquivos[caminho]) then
          preservados = false
          break
        end
      end
    end
    resultado.inputs_conhecidos_preservados = preservados
    if not preservados then
      resultado.estado = "alterado"
      resultado.mensagem = "Diretorios, selecao, inputs conhecidos ou ausencias mudaram durante a operacao."
      return resultado
    end
    -- JSONs, cmd_line e coredata podem ser regenerados pelo Meson; seus
    -- snapshots anteriores/posteriores sao registrados, nao exigidos iguais.
    resultado.estado = "sucesso"
    resultado.mensagem = "Reconfiguracao observada e inventario coerente; cobertura parcial impede aplicacao."
    return resultado
  end

  local function ao_concluir(processo)
    if recebido or finalizado then
      return
    end
    recebido = true
    local ok, resultado = pcall(conferir, processo)
    if not ok then
      resultado = resposta("erro_verificacao", "Falha ao conferir a operacao: " .. tostring(resultado))
      resultado.evidencias = {
        observacao_antes = previa.observacao,
        processo = type(processo) == "table" and vim.deepcopy(processo) or nil,
      }
    end
    entregar(resultado)
  end

  local ok, iniciou, erro_inicio = pcall(build.reconfigurar_explicitamente, pedido, ao_concluir)
  if not ok then
    return falhar("erro_inicializacao", "Falha na chamada de reconfiguracao: " .. tostring(iniciou))
  end
  if not iniciou then
    -- O build tambem agenda ao_concluir quando retorna false. Nao entregar
    -- novamente aqui, nem expor a tabela que seu callback ainda vai consumir.
    return false, vim.deepcopy(erro_inicio)
  end
  return true
end

return M
