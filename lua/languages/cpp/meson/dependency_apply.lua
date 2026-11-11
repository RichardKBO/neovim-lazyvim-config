local M = {}

local preview = require("languages.cpp.meson.dependency_preview")
local inventory = require("languages.cpp.meson.dependency_inventory")

local function recusar(etapa, mensagem, detalhe)
  return nil, {
    estado = "erro",
    etapa = etapa,
    mensagem = mensagem,
    detalhe = vim.deepcopy(detalhe),
    autorizada_para_aplicacao = false,
    atualidade_inventario = "nao_comprovada",
  }
end

-- Os coletores usam identidades de diretorio com campos diferentes.
-- Comparar somente os campos comuns; isto vincula observacoes, nao as autentica.
local function mesmo_diretorio(a, b)
  return a.type == b.type and a.dev == b.dev and a.ino == b.ino
    and (a.mode == nil or b.mode == nil or a.mode == b.mode)
end

-- Apenas descricao. Nenhuma etapa abaixo possui executor.
local function sequencia_futura(estado)
  if estado == "sem_alteracao" then
    return { executavel = false, backup = {}, aplicacao = {}, rollback = {} }
  end

  return {
    executavel = false,
    backup = {
      "Obter autorizacao especifica e revalidar a operacao exata e o isolamento da fixture.",
      "Criar diretorio privado exclusivo em ~/Backups e copia exclusiva do manifesto.",
      "Conferir a copia com cmp contra o manifesto ainda igual ao snapshot aprovado.",
      "Interromper antes de alterar o projeto se copia, cmp ou permissao falharem.",
    },
    aplicacao = {
      "Preparar manifesto temporario exclusivo no mesmo diretorio; conferir bytes e metadados.",
      "Revalidar caminhos, snapshots, target, inventario, ausencias e colisao de alias/wrap.",
      "Criar subprojects somente se ausente e criar link relativo sem substituir objetos.",
      "Registrar identidades dos objetos proprios e verificar o estado intermediario.",
      "Nao chamar o planejador para aceitar link criado com manifesto ainda nao integrado.",
      "Revalidar antes da substituicao do manifesto e conferir o resultado depois dela.",
      "Invalidar o inventario anterior; nao reconfigurar, compilar ou executar automaticamente.",
    },
    rollback = {
      "Antes da substituicao, conferir que o manifesto original permanece intacto antes de limpar.",
      "Depois da substituicao, restaurar primeiro o manifesto somente se identidade e bytes ainda forem proprios.",
      "Apos comprovar o manifesto original, remover apenas link proprio intacto e diretorio proprio vazio.",
      "Se houver interferencia, falha de restauracao ou duvida, preservar referencias, backup e residuos.",
      "Informar estado indeterminado e exigir recuperacao manual; nao prometer rollback apos queda.",
    },
  }
end

local function preparar(dados)
  if type(dados) ~= "table" then
    return recusar("entrada", "Informe os dados da dependencia para preparar o ensaio.")
  end

  -- Nao repassar tabelas do chamador nem usar campos extras como autorizacao.
  local pedido = vim.deepcopy(dados)
  local previa, erro_previa = preview.previsualizar(pedido)
  if not previa then
    return recusar("previa", "Previa recusada: " .. tostring(erro_previa), erro_previa)
  end
  if previa.estado ~= "alterar" and previa.estado ~= "sem_alteracao" then
    return recusar("previa", "Estado de previa fora do contrato de ensaio.")
  end

  local precondicoes = previa.precondicoes
  local build = precondicoes.inventario.build
  -- Usar as raizes canonicas e o destino ja validados pela previa.
  local inventario, erro_inventario = inventory.verificar({
    consumidor = { raiz = previa.consumidor.raiz },
    origem = { raiz = previa.origem.raiz }, alias = previa.alias,
    diretorio_build = build.caminho,
    destino = vim.deepcopy(previa.destino),
  })
  if not inventario then
    local mensagem = type(erro_inventario) == "table" and erro_inventario.mensagem or erro_inventario
    return recusar("inventario", "Inventario recusado: " .. tostring(mensagem), erro_inventario)
  end
  if inventario.estado ~= "coerente" then
    return recusar("inventario", "Inventario nao informou coerencia.", inventario)
  end

  local observacao = inventario.observacao
  if not vim.deep_equal(previa.destino, inventario.destino)
    or not vim.deep_equal(previa.destino, observacao.destino)
  then
    return recusar("vinculacao", "Target da previa diverge do inventario.")
  end

  local consumidor_observado = observacao.diretorios.consumidor
  local build_observado = observacao.diretorios.build
  if consumidor_observado.caminho ~= previa.consumidor.raiz
    or build_observado.caminho ~= build.caminho
    or not mesmo_diretorio(consumidor_observado.identidade, precondicoes.caminhos.identidades.consumidor)
    or not mesmo_diretorio(build_observado.identidade, build.identidade)
  then
    return recusar("vinculacao", "Raizes ou identidades de consumidor/build divergiram entre as coletas.")
  end

  -- Ambos os contratos fornecem estes snapshots com o mesmo formato.
  -- Reutilizar os coletores; nao duplicar leitura, parser ou validacao Meson.
  for _, snapshot in ipairs({
    precondicoes.consumidor,
    precondicoes.inventario.alvos,
    precondicoes.inventario.meson_info,
  }) do
    if not vim.deep_equal(snapshot, observacao.arquivos[snapshot.caminho]) then
      return recusar("vinculacao", "Snapshot da previa diverge do inventario: " .. snapshot.caminho)
    end
  end

  local subprojeto = observacao.arquivos[precondicoes.caminhos.link.caminho .. "/meson.build"]
  if subprojeto and (type(subprojeto.subprojeto) ~= "table"
    or subprojeto.subprojeto.manifesto_canonico ~= precondicoes.origem.caminho
    or subprojeto.conteudo ~= precondicoes.origem.conteudo
    or not vim.deep_equal(subprojeto.identidade, precondicoes.origem.identidade))
  then
    return recusar("vinculacao", "Manifesto do subprojeto diverge da biblioteca selecionada na previa.")
  end

  -- Reobservar tambem biblioteca, export, link e proposta apos o inventario.
  -- Igualdade detecta divergencias observaveis, sem fornecer coleta atomica.
  local revista, erro_revisao = preview.previsualizar(pedido)
  if not revista then
    return recusar("revalidacao", "Previa posterior recusada: " .. tostring(erro_revisao), erro_revisao)
  end
  if not vim.deep_equal(previa, revista) then
    return recusar("revalidacao", "Previa mudou durante a coleta do ensaio.")
  end

  local manifesto = precondicoes.consumidor
  local diff = {
    caminho = manifesto.caminho,
    conteudo_anterior = manifesto.conteudo,
    conteudo_posterior = manifesto.conteudo,
    edicoes = {},
  }
  if previa.estado == "alterar" then
    -- Preservar exatamente o conteudo e as posicoes de bytes do planejador.
    diff = vim.deepcopy(previa.alteracoes[1])
  end

  return {
    versao = 1,
    ensaio = true,
    estado = previa.estado,
    autorizada_para_aplicacao = false,
    atualidade_inventario = "nao_comprovada",
    cobertura_inputs = "parcial",
    isolamento_fixture = "nao_comprovado",
    operacao = {
      consumidor = vim.deepcopy(previa.consumidor),
      origem = vim.deepcopy(previa.origem),
      diretorio_build = build.caminho,
      destino = vim.deepcopy(previa.destino),
      alias = previa.alias,
      exportacao = previa.exportacao,
      variavel_subprojeto = previa.variavel_subprojeto,
      variavel_dependencia = previa.variavel_dependencia,
    },
    -- Conteudos integrais permitem apresentar o diff sem truncamento.
    -- Em sem_alteracao, anterior == posterior e edicoes esta vazia.
    diff = diff,
    link = {
      estado_atual = vim.deepcopy(precondicoes.caminhos.link),
      subprojects_atual = vim.deepcopy(precondicoes.caminhos.subprojects),
      proposta = vim.deepcopy(previa.link),
    },
    precondicoes = vim.deepcopy(precondicoes),
    inventario = vim.deepcopy(inventario),
    verificacoes_realizadas = {
      "Previa aceita pelos validadores existentes.",
      "Inventario coerente para consumidor, build e target selecionados.",
      "Identidades de diretorios e snapshots comuns compativeis entre as coletas.",
      "Segunda previa igual a primeira, incluindo biblioteca, alias, export e link.",
    },
    verificacoes_antes_de_escrita = {
      "Aprovar contrato separado e autorizacao especifica para a operacao exata na fixture identificada.",
      "Apresentar diff integral e link; vincular confirmacao a conteudos, caminhos, identidades e target.",
      "Comprovar isolamento por propriedade, permissoes e identidades; /tmp nao e prova.",
      "Revalidar raizes, manifestos, metadados, ausencia de hardlinks e buffers modificados.",
      "Revalidar inventario, target top-level, inputs conhecidos, ausencias e conteudos.",
      "Revalidar pai/link, destino relativo, colisao de alias/wrap e ausencia de escritores conhecidos.",
      "Invalidar confirmacao diante de qualquer divergencia antes de cada mutacao.",
      "Verificar objetos proprios no estado intermediario sem enfraquecer o planejador.",
    },
    sequencia_futura = sequencia_futura(previa.estado),
    bloqueios = {
      "Este relatorio nao autoriza aplicacao experimental nem real e nao e recibo autenticado.",
      "Cobertura de inputs parcial e atualidade do inventario nao comprovada.",
      "Isolamento, autorizacao especifica, backup e rollback nao foram executados ou comprovados.",
      "Nao ha atomicidade entre link e manifesto nem exclusao garantida de escritores externos.",
      "Releituras e locks cooperativos deixam janelas de corrida; nao garantem recuperacao apos queda.",
      "Nenhuma etapa futura descrita neste relatorio pode ser executada por este modulo.",
    },
  }, nil
end

-- M.preparar_ensaio(dados) -> relatorio, nil OU nil, erro estruturado.
-- Entrada: o mesmo contrato de dependency_preview.previsualizar(dados).
-- Estados de sucesso: alterar ou sem_alteracao; erro tem estado/etapa/mensagem.
-- Retorna copias das evidencias, sem modificar argumentos ou snapshots.
-- Somente leitura: nao reconfigura, cria backup/link/temporario ou escreve.
-- Esta API de ensaio permanece sem escrita e sem mecanismo de autorizacao.
function M.preparar_ensaio(dados)
  local ok, relatorio, erro = pcall(preparar, dados)
  if not ok then
    return recusar("ensaio", "Falha ao preparar ensaio: " .. tostring(relatorio))
  end
  return relatorio, erro
end


-- Um unico motor; cada instancia possui politica e capacidades privadas.
local uv = vim.uv
local paths = require("languages.cpp.meson.dependency_paths")
local transacao_em_curso = false

local function criar_executor(politica)
  assert(type(politica) == "table" and politica.experimental == false, "Executor experimental desativado.")
  politica = vim.deepcopy(politica)
  local api = {}
  local FIXTURE, CONSUMIDOR, BIBLIOTECA, BUILD = politica.fixture, politica.consumidor, politica.biblioteca, politica.build
  local MANIFESTO, PAI = CONSUMIDOR .. "/meson.build", CONSUMIDOR .. "/subprojects"
  local LINK, RELATIVO = PAI .. "/" .. politica.alias, politica.relativo
  local BACKUPS = vim.fn.expand("~/Backups")
  local PREFIXO_BACKUP = BACKUPS .. (politica.experimental and "/cpp-meson-experimental-" or "/cpp-meson-selecionado-")
  local TTL = 300 * 1000000000
  local pendente, autorizado
  local em_aplicacao = false
  local numero_solicitacao = 0
  local raizes_aprovadas = politica.raizes
  local function exigir(condicao, mensagem)
    if not condicao then
      error(mensagem, 0)
    end
    return condicao
  end

  local function identidade_experimental(info)
    local id = {
      type = info.type, dev = info.dev, ino = info.ino,
      uid = info.uid, gid = info.gid, mode = info.mode,
    }
    if info.type ~= "directory" then
      id.nlink, id.size, id.mtime, id.ctime = info.nlink, info.size, info.mtime, info.ctime
    end
    return id
  end

  local function ausente(caminho)
    local info, erro, codigo = uv.fs_lstat(caminho)
    exigir(info ~= nil or codigo == "ENOENT", "Falha ao inspecionar ausencia: " .. tostring(erro))
    return info == nil
  end

  -- Leitura por descritor com conferencias antes/depois; nao e snapshot atomico.
  local function objeto(caminho)
    local antes = exigir(uv.fs_lstat(caminho), "Objeto indisponivel: " .. caminho)
    exigir(antes.uid == politica.uid and antes.gid == politica.gid, "Proprietario/grupo inesperado: " .. caminho)
    exigir(antes.type == "directory" or antes.type == "file" or antes.type == "link",
      "Tipo nao suportado: " .. caminho)
    local registro = { caminho = caminho, identidade = identidade_experimental(antes) }
    if antes.type == "link" then
      exigir(caminho == LINK and antes.nlink == 1, "Link inesperado: " .. caminho)
      registro.destino = exigir(uv.fs_readlink(caminho), "Destino do link indisponivel.")
      exigir(registro.destino == RELATIVO and uv.fs_realpath(caminho) == BIBLIOTECA,
        "Link nao corresponde a biblioteca aprovada.")
    else
      exigir(uv.fs_realpath(caminho) == caminho, "Caminho redirecionado: " .. caminho)
      if antes.type == "file" then
        exigir(antes.nlink == 1 and antes.size <= 2 * 1024 * 1024,
          "Hardlink ou tamanho fora do subconjunto experimental: " .. caminho)
        local fd = exigir(uv.fs_open(caminho, "r", 0), "Falha ao abrir: " .. caminho)
        local ok, conteudo = pcall(function()
          exigir(vim.deep_equal(identidade_experimental(uv.fs_fstat(fd)), registro.identidade),
            "Descritor diverge do caminho: " .. caminho)
          local partes, offset = {}, 0
          while offset < antes.size do
            local trecho = exigir(uv.fs_read(fd, math.min(65536, antes.size - offset), offset),
              "Falha ao ler: " .. caminho)
            exigir(#trecho > 0, "Leitura incompleta: " .. caminho)
            partes[#partes + 1], offset = trecho, offset + #trecho
          end
          exigir(vim.deep_equal(identidade_experimental(uv.fs_fstat(fd)), registro.identidade),
            "Arquivo mudou durante leitura: " .. caminho)
          return table.concat(partes)
        end)
        local fechou = uv.fs_close(fd)
        exigir(ok and fechou, "Falha de leitura/fechamento: " .. tostring(conteudo))
        registro.conteudo = conteudo
      end
    end
    local depois = exigir(uv.fs_lstat(caminho), "Objeto desapareceu: " .. caminho)
    exigir(vim.deep_equal(registro.identidade, identidade_experimental(depois)),
      "Identidade mudou durante leitura: " .. caminho)
    return registro
  end

  local function listar(caminho)
    local req = exigir(uv.fs_scandir(caminho), "Falha ao listar: " .. caminho)
    local nomes = {}
    while true do
      local nome = uv.fs_scandir_next(req)
      if not nome then break end
      nomes[#nomes + 1] = nome
    end
    table.sort(nomes)
    return nomes
  end

  local function buffers_limpos()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
        local nome = vim.api.nvim_buf_get_name(buf)
        local real = uv.fs_realpath(nome) or vim.fs.normalize(nome)
        for _, raiz in ipairs(politica.experimental and { FIXTURE } or { CONSUMIDOR, BIBLIOTECA, BUILD }) do
          exigir(real ~= raiz and real:sub(1, #raiz + 1) ~= raiz .. "/", "Buffer modificado no escopo da operacao.")
        end
      end
    end
  end

  -- Estrutura fixa dos fontes; somente os arquivos gerados dentro de build/
  -- sao enumerados dinamicamente e depois selados integralmente na autorizacao.
  local function capturar_fixture(tx)
    exigir(uv.getuid() == politica.uid and uv.getgid() == politica.gid, "Identidade de execucao inesperada.")
    buffers_limpos()
    local arvore, quantidade = {}, 0
    local function visitar(caminho, nivel)
      quantidade = quantidade + 1
      exigir(nivel <= 8 and quantidade <= 128, "Fixture excede o subconjunto suportado.")
      local registro = objeto(caminho)
      arvore[caminho] = registro
      if registro.identidade.type == "directory" then
        for _, nome in ipairs(listar(caminho)) do
          visitar(caminho .. "/" .. nome, nivel + 1)
        end
      end
    end
    if not politica.experimental then
      -- Somente fontes/includes e inputs conhecidos; nao percorrer .git ou builds inteiros.
      local function registrar(caminho)
        if not arvore[caminho] then arvore[caminho] = objeto(caminho) end
        return arvore[caminho]
      end
      for caminho, id in pairs(raizes_aprovadas) do
        local atual = registrar(caminho).identidade
        exigir(atual.type == "directory" and atual.dev == id.dev and atual.ino == id.ino,
          "Raiz fisica selecionada divergiu: " .. caminho)
      end
      for _, raiz in ipairs({ CONSUMIDOR, BIBLIOTECA }) do
        registrar(raiz .. "/meson.build")
        visitar(raiz .. "/src", 0)
        visitar(raiz .. "/include", 0)
      end
      for caminho in pairs(politica.observacao.arquivos) do registrar(caminho) end
      for _, pasta in pairs(politica.observacao.diretorios) do registrar(pasta.caminho) end
      if not ausente(PAI) then
        exigir(registrar(PAI).identidade.type == "directory", "subprojects deve ser diretorio real.")
        for _, nome in ipairs(listar(PAI)) do
          exigir(tx and tx.link and PAI .. "/" .. nome == LINK,
            "subprojects ocupado por objeto nao apresentado; operacao recusada.")
        end
        if tx and tx.link then registrar(LINK) end
      end
      for _, registro in ipairs({ tx and tx.temporario or false, tx and tx.restauro or false }) do
        if registro then registrar(registro.caminho) end
      end
      for _, nome in ipairs(listar(CONSUMIDOR)) do
        if nome:match("^%.meson%-dependency%-") or nome:match("^%.meson%-restore%-") then
          exigir(arvore[CONSUMIDOR .. "/" .. nome], "Temporario sem recibo; recuperacao manual necessaria.")
        end
      end
      exigir(vim.tbl_count(arvore) <= 128, "Escopo excede o limite de snapshots.")
      return arvore
    end
    visitar(FIXTURE, 0)
    exigir(arvore[FIXTURE].identidade.mode % 512 == 448, "Fixture deve permanecer privada (0700).")
    for caminho, id in pairs(raizes_aprovadas) do
      local atual = arvore[caminho]
      exigir(atual and atual.identidade.type == "directory"
        and atual.identidade.dev == id.dev and atual.identidade.ino == id.ino,
        "Raiz fisica nao e a fixture aprovada: " .. caminho)
    end
    local permitidos = {
      [FIXTURE] = "directory",
      [CONSUMIDOR] = "directory", [BIBLIOTECA] = "directory",
      [MANIFESTO] = "file", [BIBLIOTECA .. "/meson.build"] = "file",
      [CONSUMIDOR .. "/include"] = "directory", [CONSUMIDOR .. "/src"] = "directory",
      [CONSUMIDOR .. "/src/main.cpp"] = "file",
      [BIBLIOTECA .. "/include"] = "directory", [BIBLIOTECA .. "/src"] = "directory",
      [BIBLIOTECA .. "/include/Produto.hpp"] = "file",
      [BIBLIOTECA .. "/src/Produto.cpp"] = "file",
      [BUILD] = "directory",
    }
    for caminho, tipo in pairs(permitidos) do
      exigir(arvore[caminho] and arvore[caminho].identidade.type == tipo, "Estrutura ausente: " .. caminho)
    end
    permitidos[PAI] = "directory" -- Opcional, vazio antes da operacao.
    if tx then
      if tx.temporario then permitidos[tx.temporario.caminho] = "file" end
      if tx.restauro then permitidos[tx.restauro.caminho] = "file" end
      if tx.link then permitidos[LINK] = "link" end
    end
    for caminho, registro in pairs(arvore) do
      local gerado = caminho:sub(1, #BUILD + 1) == BUILD .. "/"
      exigir((gerado and registro.identidade.type ~= "link")
        or permitidos[caminho] == registro.identidade.type, "Objeto nao previsto: " .. caminho)
    end
    return arvore
  end

  local function conferir_fixture(tx)
    local atual = capturar_fixture(tx)
    local esperado = vim.deepcopy(tx.base)
    for _, registro in ipairs({ tx.temporario or false, tx.restauro or false, tx.pai or false, tx.link or false }) do
      if registro then esperado[registro.caminho] = registro end
    end
    if tx.manifesto then esperado[MANIFESTO] = tx.manifesto end
    exigir(vim.deep_equal(atual, esperado), "Identidade, conteudo ou estrutura da fixture divergiram.")
    return atual
  end

  local function conferir_backup(tx)
    exigir(vim.deep_equal(objeto(BACKUPS), tx.raiz_backup), "Raiz de backups divergiu.")
    if tx.pasta_backup then
      exigir(vim.deep_equal(objeto(tx.pasta_backup.caminho), tx.pasta_backup), "Pasta de backup divergiu.")
    end
    if tx.pasta_backup then
      local nomes = listar(tx.pasta_backup.caminho)
      local tem_copia = tx.backup or tx.backup_pendente
      exigir((not tem_copia and #nomes == 0)
        or (tem_copia and #nomes == 1 and nomes[1] == "meson.build.original"),
        "Conteudo inesperado na pasta de backup.")
    end
    if tx.backup then
      exigir(vim.deep_equal(objeto(tx.backup.caminho), tx.backup), "Backup alterado ou substituido.")
      exigir(tx.backup.conteudo == tx.relatorio.diff.conteudo_anterior, "Backup nao contem o original.")
    end
  end

  local function revalidar(tx)
    conferir_fixture(tx)
    conferir_backup(tx)
    local fisico, erro = paths.inspecionar(tx.relatorio.operacao)
    exigir(fisico, "Caminhos recusados: " .. tostring(erro))
    local link_esperado = tx.link and "link" or "ausente"
    exigir(fisico.link.estado == link_esperado, "Estado do link divergiu.")
    local inv, falha = inventory.verificar({
      consumidor = { raiz = CONSUMIDOR }, diretorio_build = BUILD,
      origem = { raiz = tx.relatorio.operacao.origem.raiz }, alias = tx.relatorio.operacao.alias,
      destino = vim.deepcopy(tx.relatorio.operacao.destino),
    }, vim.deepcopy(tx.relatorio.inventario.observacao))
    exigir(inv and inv.estado == "coerente" and inv.correspondencia_evidencia == "correspondente",
      "Inventario/target divergiram: " .. vim.inspect(falha))
  end

  local function validar_relatorio(relatorio)
    exigir(not em_aplicacao and not transacao_em_curso, "Outra operacao esta em curso nesta instancia.")
    exigir(type(relatorio) == "table" and relatorio.estado == "alterar"
      and relatorio.autorizada_para_aplicacao == false,
      "Exige ensaio de dependencia nova, sem promover autorizada_para_aplicacao.")
    local op = relatorio.operacao
    if politica.experimental then
    exigir(type(op) == "table" and op.consumidor.raiz == CONSUMIDOR
      and op.origem.raiz == BIBLIOTECA and op.diretorio_build == BUILD
      and op.alias == "BibliotecaProdutos" and op.exportacao == "biblioteca_produtos_dep"
      and op.variavel_subprojeto == "biblioteca" and op.variavel_dependencia == "produtos_dep"
      and op.destino.id == "SistemaVendas@exe" and op.destino.name == "SistemaVendas",
      "Operacao fora da fixture/selecao aprovada.")
    else
      exigir(vim.deep_equal(op, politica.operacao), "Contexto selecionado alterado ou incompleto.")
    end
    local atual, erro = preparar(vim.deepcopy(op))
    exigir(atual and vim.deep_equal(atual, relatorio), "Ensaio desatualizado/invalido: " .. vim.inspect(erro))
    exigir(atual.link.estado_atual.estado == "ausente" and atual.link.proposta.acao == "criar"
      and atual.link.proposta.destino_literal == RELATIVO, "Estado inicial nao suportado.")
    local base = capturar_fixture()
    exigir(base[MANIFESTO].identidade.mode % 4096 == base[MANIFESTO].identidade.mode % 512,
      "Permissoes especiais do manifesto nao sao suportadas.")
    local raiz_backup = objeto(BACKUPS)
    exigir(raiz_backup.identidade.type == "directory", "Backups deve ser diretorio real.")
    if not politica.experimental then
      for _, pasta in ipairs({ base[CONSUMIDOR], base[PAI] or base[CONSUMIDOR], raiz_backup }) do
        exigir(math.floor(pasta.identidade.mode / 64) % 4 == 3, "Diretorio sem escrita/execucao para o proprietario.")
      end
      exigir(math.floor(base[MANIFESTO].identidade.mode / 128) % 2 == 1, "Manifesto somente leitura.")
    end
    exigir(vim.fn.executable("/usr/bin/cmp") == 1, "cmp indisponivel; escrita bloqueada.")
    return base, raiz_backup
  end

  local function vigente(registro)
    exigir(registro and uv.hrtime() - registro.instante <= TTL, "Autorizacao ausente ou expirada.")
  end

  -- Somente leitura. Devolve diff e frase exata a serem revisados ANTES da
  -- confirmacao. O objeto e local a esta instancia; copia/serializacao nao vale.
  function api.solicitar(relatorio)
    local ok, resultado = pcall(function()
      local base, raiz_backup = validar_relatorio(relatorio)
      numero_solicitacao = numero_solicitacao + 1
      local id = vim.fn.sha256(vim.inspect({
        relatorio = relatorio, fixture = base, backup = raiz_backup,
        instancia = uv.hrtime(), solicitacao = numero_solicitacao,
      }))
      local frase = politica.experimental and ("AUTORIZO EXPERIMENTO MESON " .. id .. " EM " .. FIXTURE)
        or ("AUTORIZO DEPENDENCIA MESON " .. id .. " EM " .. CONSUMIDOR .. "; BIBLIOTECA " .. BIBLIOTECA)
      frase = frase .. "; SEM ESCRITORES CONCORRENTES; ACEITO RISCO RESIDUAL E RECUPERACAO MANUAL"
      local pedido = {
        id = id, fixture = FIXTURE, diff = vim.deepcopy(relatorio.diff),
        operacao = vim.deepcopy(relatorio.operacao), confirmacao_exigida = frase,
        validade_segundos = 300,
        aviso = politica.experimental and "Exclusivo do laboratorio; nao ha exclusao de escritores nao cooperantes."
          or "Sem exclusao de escritores concorrentes, atomicidade link+manifesto ou recuperacao apos queda; ACLs nao cobertas.",
      }
      pendente = {
        pedido = pedido, exibido = vim.deepcopy(pedido), frase = frase,
        relatorio = vim.deepcopy(relatorio), base = base, raiz_backup = raiz_backup, instante = uv.hrtime(),
      }
      autorizado = nil
      return pedido
    end)
    if not ok then return recusar("solicitacao_experimental", tostring(resultado)) end
    return resultado, nil
  end

  -- Confirmacao textual especifica; nao aceita booleano, forcar=true ou id solto.
  -- O chamador deve obter a frase da pessoa que revisou a operacao. Nao se
  -- autentica uma pessoa nem se protege de codigo hostil no mesmo processo Lua.
  function api.confirmar(pedido, confirmacao)
    local registro = pendente
    pendente = nil
    local ok, resultado = pcall(function()
      vigente(registro)
      exigir(pedido == registro.pedido and vim.deep_equal(pedido, registro.exibido),
        "Solicitacao desconhecida ou alterada.")
      exigir(type(confirmacao) == "string" and confirmacao == registro.frase, "Confirmacao especifica exigida.")
      local base, raiz_backup = validar_relatorio(registro.relatorio)
      exigir(vim.deep_equal(base, registro.base) and vim.deep_equal(raiz_backup, registro.raiz_backup),
        "Fixture ou backups divergiram antes da autorizacao.")
      local ticket = {}
      registro.ticket, registro.instante = ticket, uv.hrtime()
      autorizado = registro
      return ticket
    end)
    if not ok then return recusar("confirmacao_experimental", tostring(resultado)) end
    return resultado, nil
  end

  local function etapa(tx, nome)
    tx.etapa = nome
    tx.etapas[#tx.etapas + 1] = nome
  end

  local function escrever_fd(fd, conteudo, modo)
    local identidade
    local ok, erro = pcall(function()
      local offset = 0
      while offset < #conteudo do
        local n = exigir(uv.fs_write(fd, conteudo:sub(offset + 1), offset), "Falha de escrita.")
        exigir(n > 0, "Escrita incompleta.")
        offset = offset + n
      end
      exigir(uv.fs_fchmod(fd, modo), "Falha ao preservar permissoes.")
      exigir(uv.fs_fsync(fd), "Falha de fsync do arquivo.")
      identidade = identidade_experimental(exigir(uv.fs_fstat(fd), "Descritor criado indisponivel."))
    end)
    local fechou = uv.fs_close(fd)
    exigir(ok and fechou, "Falha de escrita/fechamento: " .. tostring(erro))
    return identidade
  end

  local function sincronizar_diretorio(caminho)
    exigir(objeto(caminho).identidade.type == "directory", "Diretorio de fsync invalido.")
    local fd = exigir(uv.fs_open(caminho, "r", 0), "Falha ao abrir diretorio para fsync.")
    local ok, erro = uv.fs_fsync(fd)
    local fechou = uv.fs_close(fd)
    exigir(ok and fechou, "Falha de fsync/fechamento do diretorio: " .. tostring(erro))
  end

  local function movido(antes, depois)
    if not depois or antes.conteudo ~= depois.conteudo then return false end
    local a, b = vim.deepcopy(antes.identidade), vim.deepcopy(depois.identidade)
    -- rename pode atualizar ctime; os demais campos e os bytes devem coincidir.
    a.ctime, b.ctime = nil, nil
    return vim.deep_equal(a, b)
  end

  local function resolver_rename(tx)
    local atual = objeto(MANIFESTO)
    if movido(tx.temporario, atual) and ausente(tx.temporario.caminho) then
      tx.manifesto, tx.temporario, tx.instalado = atual, nil, true
    else
      exigir(vim.deep_equal(atual, tx.base[MANIFESTO])
        and vim.deep_equal(objeto(tx.temporario.caminho), tx.temporario),
        "Resultado do rename incerto; preservar para recuperacao manual.")
    end
    tx.rename_pendente = false
  end

  local function executar_experimento(tx)
    etapa(tx, "revalidacao_inicial")
    revalidar(tx)
    etapa(tx, "backup_exclusivo")
    local pasta = exigir(uv.fs_mkdtemp(PREFIXO_BACKUP .. "XXXXXX"), "Falha ao criar backup exclusivo.")
    local prefixo = PREFIXO_BACKUP
    exigir(pasta:sub(1, #prefixo) == prefixo, "Pasta de backup inesperada.")
    tx.pasta_backup = objeto(pasta)
    exigir(tx.pasta_backup.identidade.mode % 512 == 448, "Backup nao e privado.")
    revalidar(tx)
    tx.backup_pendente = pasta .. "/meson.build.original"
    local fd = exigir(uv.fs_open(tx.backup_pendente, "wx", 384), "Falha ao criar copia exclusiva.")
    local id_backup = escrever_fd(fd, tx.relatorio.diff.conteudo_anterior, 384)
    tx.backup = objeto(tx.backup_pendente)
    exigir(vim.deep_equal(tx.backup.identidade, id_backup), "Copia nao corresponde ao descritor criado.")
    tx.backup_pendente = nil
    exigir(tx.backup.identidade.ino ~= tx.base[MANIFESTO].identidade.ino
      or tx.backup.identidade.dev ~= tx.base[MANIFESTO].identidade.dev, "Backup nao e independente.")
    sincronizar_diretorio(pasta)
    revalidar(tx)
    etapa(tx, "cmp_do_backup")
    local processo = vim.system({ "/usr/bin/cmp", "--", tx.backup.caminho, MANIFESTO }, { text = true }):wait()
    tx.cmp = { code = processo.code, signal = processo.signal, stderr = processo.stderr }
    exigir(processo.code == 0 and (processo.signal == nil or processo.signal == 0), "cmp recusou o backup.")
    conferir_backup(tx)
    revalidar(tx)
    etapa(tx, "temporario_exclusivo")
    local temp_fd, caminho = uv.fs_mkstemp(CONSUMIDOR .. "/.meson-dependency-XXXXXX")
    exigir(temp_fd, "Falha ao criar temporario exclusivo.")
    tx.projeto_tocado = true
    tx.temporario_pendente = caminho
    local id_temp = escrever_fd(temp_fd, tx.relatorio.diff.conteudo_posterior, tx.base[MANIFESTO].identidade.mode % 512)
    tx.temporario = objeto(caminho)
    exigir(vim.deep_equal(tx.temporario.identidade, id_temp), "Temporario nao corresponde ao descritor criado.")
    tx.temporario_pendente = nil
    exigir(tx.temporario.conteudo == tx.relatorio.diff.conteudo_posterior, "Temporario diverge do plano.")
    revalidar(tx)
    if not tx.base[PAI] then
      etapa(tx, "criacao_subprojects")
      exigir(ausente(PAI), "Colisao em subprojects.")
      exigir(uv.fs_mkdir(PAI, 448), "Falha ao criar subprojects exclusivamente.")
      tx.pai_pendente = true
      tx.pai = objeto(PAI)
      tx.pai_pendente = nil
    end
    revalidar(tx)
    etapa(tx, "criacao_link_relativo")
    exigir(ausente(LINK), "Colisao no link.")
    exigir(uv.fs_symlink(RELATIVO, LINK), "Falha ao criar link sem substituicao.")
    tx.link_pendente = true
    tx.link = objeto(LINK)
    tx.link_pendente = nil
    sincronizar_diretorio(PAI)
    revalidar(tx)
    etapa(tx, "substituicao_manifesto")
    -- Ultima conferencia nao e compare-and-swap: permanece uma janela de corrida.
    tx.rename_pendente = true
    exigir(uv.fs_rename(tx.temporario.caminho, MANIFESTO), "Falha ao substituir manifesto.")
    resolver_rename(tx)
    exigir(tx.instalado, "Manifesto nao foi instalado.")
    sincronizar_diretorio(CONSUMIDOR)
    etapa(tx, "conferencia_final")
    conferir_fixture(tx)
    conferir_backup(tx)
    local final, erro = preview.previsualizar(vim.deepcopy(tx.relatorio.operacao))
    exigir(final and final.estado == "sem_alteracao" and #final.alteracoes == 0
      and final.link.acao == "manter" and final.link.destino_literal == RELATIVO,
      "Integracao final nao reconhecida: " .. tostring(erro))
    conferir_fixture(tx)
    tx.previa_final = final
  end

  local function remover_proprio(tx, campo, diretorio)
    local registro = tx[campo]
    if not registro then return end
    conferir_fixture(tx)
    conferir_backup(tx)
    exigir(vim.deep_equal(objeto(registro.caminho), registro), "Objeto proprio divergiu; nao remover.")
    if diretorio then
      exigir(#listar(registro.caminho) == 0, "Diretorio proprio nao esta vazio.")
      exigir(uv.fs_rmdir(registro.caminho), "Falha ao remover diretorio proprio vazio.")
    else
      exigir(uv.fs_unlink(registro.caminho), "Falha ao remover objeto proprio.")
    end
    tx[campo] = nil
  end

  local function recuperar(tx)
    exigir(not tx.temporario_pendente and not tx.pai_pendente and not tx.link_pendente,
      "Objeto criado sem recibo completo; recuperacao manual necessaria.")
    if tx.rename_pendente then resolver_rename(tx) end
    conferir_fixture(tx)
    conferir_backup(tx)
    if tx.instalado then
      exigir(tx.backup and tx.cmp and tx.cmp.code == 0, "Backup verificado indisponivel.")
      etapa(tx, "rollback_manifesto")
      local fd, caminho = uv.fs_mkstemp(CONSUMIDOR .. "/.meson-restore-XXXXXX")
      exigir(fd, "Falha ao preparar restauracao exclusiva.")
      tx.restauro_pendente = caminho
      local id_restauro = escrever_fd(fd, tx.backup.conteudo, tx.base[MANIFESTO].identidade.mode % 512)
      tx.restauro = objeto(caminho)
      exigir(vim.deep_equal(tx.restauro.identidade, id_restauro), "Restauro nao corresponde ao descritor criado.")
      tx.restauro_pendente = nil
      exigir(tx.restauro.conteudo == tx.base[MANIFESTO].conteudo, "Restauracao nao contem o original.")
      conferir_fixture(tx)
      conferir_backup(tx)
      exigir(uv.fs_rename(tx.restauro.caminho, MANIFESTO), "Falha ao restaurar manifesto.")
      local restaurado = objeto(MANIFESTO)
      exigir(movido(tx.restauro, restaurado), "Resultado da restauracao incerto.")
      tx.manifesto, tx.restauro, tx.instalado = restaurado, nil, false
      sincronizar_diretorio(CONSUMIDOR)
    end
    exigir((tx.manifesto or tx.base[MANIFESTO]).conteudo == tx.base[MANIFESTO].conteudo,
      "Manifesto original nao foi recuperado; preservar referencias.")
    etapa(tx, "rollback_objetos_proprios")
    remover_proprio(tx, "link", false)
    remover_proprio(tx, "pai", true)
    remover_proprio(tx, "temporario", false)
    conferir_fixture(tx)
    conferir_backup(tx)
  end

  local function resultado_experimental(tx, estado, mensagem)
    return {
      estado = estado, etapa = tx.etapa, mensagem = mensagem,
      experimento = politica.experimental, autorizada_para_aplicacao = false,
      atualidade_inventario = "nao_comprovada",
      inventario_apos_operacao = "exige_nova_verificacao",
      operacao_id = tx.id, backup = tx.backup and tx.backup.caminho or tx.backup_pendente,
      pasta_backup = tx.pasta_backup and tx.pasta_backup.caminho,
      cmp = vim.deepcopy(tx.cmp), etapas = vim.deepcopy(tx.etapas),
      hashes = {
        anterior = vim.fn.sha256(tx.relatorio.diff.conteudo_anterior),
        posterior = vim.fn.sha256(tx.relatorio.diff.conteudo_posterior),
        backup = tx.backup and vim.fn.sha256(tx.backup.conteudo),
      },
      objetos = vim.deepcopy({
        manifesto = tx.manifesto, temporario = tx.temporario, pai = tx.pai, link = tx.link,
        restauro = tx.restauro, backup = tx.backup, pasta_backup = tx.pasta_backup,
        temporario_pendente = tx.temporario_pendente, restauro_pendente = tx.restauro_pendente,
        pai_pendente = tx.pai_pendente, link_pendente = tx.link_pendente,
      }),
      previa_final = vim.deepcopy(tx.previa_final),
      risco_residual = "Operacoes por caminho; sem exclusao de escritores nao cooperantes ou atomicidade link+manifesto.",
      evidencia = "Recibos em memoria e backup preservado; nao ha journal duravel ou rollback automatico apos queda.",
      orientacao_recuperacao = estado == "recuperacao_manual"
        and "Nao sobrescreva nem remova objetos; preserve backup e recibos e confira identidades/conteudos antes da recuperacao manual." or nil,
    }
  end

  -- UNICA entrada de escrita, opt-in e sincronica. Ticket opaco de uso unico,
  -- da mesma instancia e vinculado ao relatorio integral. Nao aceita caminhos,
  -- booleans ou flags para ampliar o escopo. Somente cmp e executado; nao Meson.
  -- Sucesso: resultado,nil. Falha: nil,erro com backup/recibos e estado
  -- erro_sem_alteracao|revertido|recuperacao_manual. Backup nunca e removido.
  function api.aplicar(relatorio, ticket)
    local registro = autorizado
    if not registro or ticket ~= registro.ticket or em_aplicacao or transacao_em_curso then
      return recusar("aplicacao_experimental", "Ticket desconhecido, consumido ou operacao em curso.")
    end
    autorizado = nil -- Consumir antes de validar ou escrever; falha tambem consome.
    local ok, erro = pcall(function()
      vigente(registro)
      exigir(vim.deep_equal(relatorio, registro.relatorio), "Relatorio diverge da operacao autorizada.")
      local base, raiz_backup = validar_relatorio(relatorio)
      exigir(vim.deep_equal(base, registro.base) and vim.deep_equal(raiz_backup, registro.raiz_backup),
        "Precondicoes fisicas divergiram apos autorizacao.")
    end)
    if not ok then return recusar("aplicacao_experimental", tostring(erro)) end
    local tx = {
      id = registro.exibido.id, relatorio = vim.deepcopy(registro.relatorio),
      base = registro.base, raiz_backup = registro.raiz_backup, etapas = {},
    }
    em_aplicacao, transacao_em_curso = true, true
    local sucesso, falha = pcall(executar_experimento, tx)
    if sucesso then
      em_aplicacao, transacao_em_curso = false, false
      return resultado_experimental(tx, politica.experimental and "aplicado_experimentalmente" or "aplicado", "Integracao verificada; backup preservado."), nil
    end
    local etapa_falha = tx.etapa
    local recuperou, erro_recuperacao = pcall(recuperar, tx)
    em_aplicacao, transacao_em_curso = false, false
    local estado = "recuperacao_manual"
    if recuperou then estado = tx.projeto_tocado and "revertido" or "erro_sem_alteracao" end
    local mensagem = "Falha em " .. tostring(etapa_falha) .. ": " .. tostring(falha)
    if not recuperou then mensagem = mensagem .. "; interrompido: " .. tostring(erro_recuperacao) end
    local resultado = resultado_experimental(tx, estado, mensagem)
    resultado.etapa_falha = etapa_falha
    return nil, resultado
  end


  function api.cancelar()
    pendente, autorizado = nil, nil
  end

  function api.verificar(relatorio)
    local base, raiz_backup = validar_relatorio(relatorio)
    return {
      estado = "pronto_para_revisao", autorizada_para_aplicacao = false,
      contexto = { operacao = vim.deepcopy(relatorio.operacao), raizes = vim.deepcopy(raizes_aprovadas),
        manifesto = vim.deepcopy(base[MANIFESTO]), link = vim.deepcopy(relatorio.link.proposta) },
      arquivos_afetados = { MANIFESTO, PAI, LINK },
      temporarios = { CONSUMIDOR .. "/.meson-dependency-XXXXXX", CONSUMIDOR .. "/.meson-restore-XXXXXX" },
      backup = PREFIXO_BACKUP .. "XXXXXX/meson.build.original",
      raiz_backup = vim.deepcopy(raiz_backup),
      riscos = "Sem exclusao de escritores concorrentes ou atomicidade link+manifesto; recuperacao manual pode ser necessaria. ACLs/metadados estendidos nao cobertos.",
    }
  end
  return api
end

-- A fixture privada nao faz parte da configuracao publicavel.
-- Preservar os nomes da API com recusa incondicional, sem criar executor/ticket.
local function recusar_experimental()
  return recusar("politica_experimental", "Aplicacao experimental desativada nesta configuracao.")
end
M.solicitar_autorizacao_experimental = recusar_experimental
M.confirmar_autorizacao_experimental = recusar_experimental
M.aplicar_experimental = recusar_experimental

local function executor_selecionado(relatorio)
  assert(type(relatorio) == "table" and type(relatorio.operacao) == "table", "Ensaio selecionado obrigatorio.")
  local op = vim.deepcopy(relatorio.operacao)
  local p = relatorio.precondicoes
  assert(type(p) == "table" and type(relatorio.link) == "table", "Contexto incompleto.")
  local relativo = relatorio.link.proposta.destino_literal
  assert(type(relativo) == "string" and relativo:sub(1, 1) ~= "/", "Link relativo da previa obrigatorio.")
  return criar_executor({
    experimental = false, consumidor = op.consumidor.raiz, biblioteca = op.origem.raiz,
    build = op.diretorio_build, alias = op.alias, relativo = relativo,
    uid = uv.getuid(), gid = uv.getgid(), operacao = op,
    observacao = vim.deepcopy(relatorio.inventario.observacao),
    raizes = {
      [op.consumidor.raiz] = vim.deepcopy(p.caminhos.identidades.consumidor),
      [op.origem.raiz] = vim.deepcopy(p.caminhos.identidades.origem),
      [op.diretorio_build] = vim.deepcopy(p.inventario.build.identidade),
    },
  })
end

-- Bloqueio de politica do Passo 403: nao e configuravel por dados/flags do chamador.
local SELECIONADA_HABILITADA = false
local selecionado
function M.aplicacao_selecionada_disponivel()
  return SELECIONADA_HABILITADA
end

function M.verificar_selecionada(relatorio)
  local ok, resultado = pcall(function() return executor_selecionado(relatorio).verificar(relatorio) end)
  if not ok then return recusar("contexto_selecionado", tostring(resultado)) end
  resultado.execucao_habilitada = SELECIONADA_HABILITADA
  return resultado, nil
end

function M.solicitar_autorizacao_selecionada(relatorio)
  if not SELECIONADA_HABILITADA then return recusar("politica_selecionada", "Aplicacao real bloqueada no Passo 403.") end
  if selecionado then selecionado.executor.cancelar(); selecionado = nil end
  local ok, executor = pcall(executor_selecionado, relatorio)
  if not ok then return recusar("contexto_selecionado", tostring(executor)) end
  local pedido, erro = executor.solicitar(relatorio)
  if pedido then selecionado = { executor = executor, pedido = pedido, relatorio = vim.deepcopy(relatorio) } end
  return pedido, erro
end

function M.cancelar_autorizacao_selecionada(pedido)
  if selecionado and pedido == selecionado.pedido then selecionado.executor.cancelar(); selecionado = nil end
end

function M.confirmar_autorizacao_selecionada(pedido, frase)
  if not SELECIONADA_HABILITADA or not selecionado or pedido ~= selecionado.pedido then
    return recusar("confirmacao_selecionada", "Solicitacao indisponivel ou aplicacao real bloqueada.")
  end
  local ticket, erro = selecionado.executor.confirmar(pedido, frase)
  if ticket then selecionado.ticket = ticket else selecionado = nil end
  return ticket, erro
end

function M.aplicar_selecionada(relatorio, ticket)
  local registro = selecionado
  selecionado = nil
  if not SELECIONADA_HABILITADA or not registro then
    if registro then registro.executor.cancelar() end
    return recusar("politica_selecionada", "Aplicacao real bloqueada no Passo 403 ou solicitacao ausente.")
  end
  if ticket ~= registro.ticket then registro.executor.cancelar(); return recusar("aplicacao_selecionada", "Ticket invalido.") end
  return registro.executor.aplicar(relatorio, ticket)
end

return M
