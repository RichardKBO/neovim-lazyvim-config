local M = {}

local caminhos = require("languages.cpp.meson.dependency_paths")
local targets = require("languages.cpp.meson.dependency_targets")
local dependencias = require("languages.cpp.meson.dependencies")
local uv = vim.uv

local function observar(info)
  return {
    type = info.type, dev = info.dev, ino = info.ino,
    size = info.size, mode = info.mode, mtime = info.mtime, ctime = info.ctime,
  }
end

local function ler_arquivo(caminho)
  local antes, erro_stat = uv.fs_lstat(caminho)
  if not antes then
    return nil, "Falha ao inspecionar " .. caminho .. ": " .. tostring(erro_stat)
  end
  if antes.type ~= "file" then
    return nil, "Arquivo regular exigido: " .. caminho
  end
  if uv.fs_realpath(caminho) ~= caminho then
    return nil, "Caminho de leitura redirecionado ou indisponivel: " .. caminho
  end

  local arquivo, erro_abrir = io.open(caminho, "rb")
  if not arquivo then
    return nil, "Falha ao abrir " .. caminho .. ": " .. tostring(erro_abrir)
  end
  local conteudo, erro_ler = arquivo:read("*a")
  local fechou, erro_fechar = arquivo:close()
  if not conteudo or not fechou then
    return nil, "Falha ao ler/fechar " .. caminho .. ": " .. tostring(erro_ler or erro_fechar)
  end

  local depois = uv.fs_lstat(caminho)
  if not depois or uv.fs_realpath(caminho) ~= caminho or not vim.deep_equal(observar(antes), observar(depois)) then
    return nil, "Arquivo mudou durante a leitura: " .. caminho
  end
  return { caminho = caminho, conteudo = conteudo, identidade = observar(antes) }, nil
end

local function decodificar(arquivo)
  local ok, valor = pcall(vim.json.decode, arquivo.conteudo)
  if not ok or type(valor) ~= "table" then
    return nil, "JSON invalido em " .. arquivo.caminho .. (ok and "" or ": " .. tostring(valor))
  end
  return valor, nil
end

local function coordenar(dados)
  local fisico, erro_fisico = caminhos.inspecionar(dados)
  if not fisico then
    return nil, "Inspecao fisica: " .. tostring(erro_fisico)
  end

  local consumidor, erro_consumidor = ler_arquivo(vim.fs.joinpath(fisico.raizes.consumidor, "meson.build"))
  if not consumidor then
    return nil, erro_consumidor
  end
  local origem, erro_origem = ler_arquivo(vim.fs.joinpath(fisico.raizes.origem, "meson.build"))
  if not origem then
    return nil, erro_origem
  end

  local build_informado = dados.diretorio_build
  if type(build_informado) ~= "string" or build_informado:sub(1, 1) ~= "/" or build_informado:find("%c") then
    return nil, "Informe um diretorio de build absoluto valido."
  end
  local build, erro_build = uv.fs_realpath(build_informado)
  if not build then
    return nil, "Build indisponivel: " .. tostring(erro_build)
  end
  build = vim.fs.normalize(build)
  local info_build, erro_stat = uv.fs_stat(build)
  if not info_build or info_build.type ~= "directory" or info_build.dev == nil or info_build.ino == nil then
    return nil, "Build nao e um diretorio com identidade disponivel: " .. tostring(erro_stat)
  end

  local arquivo_alvos, erro_alvos = ler_arquivo(vim.fs.joinpath(build, "meson-info", "intro-targets.json"))
  if not arquivo_alvos then
    return nil, erro_alvos
  end
  local arquivo_info, erro_info = ler_arquivo(vim.fs.joinpath(build, "meson-info", "meson-info.json"))
  if not arquivo_info then
    return nil, erro_info
  end
  local alvos, erro_json_alvos = decodificar(arquivo_alvos)
  if not alvos then
    return nil, erro_json_alvos
  end
  local info, erro_json_info = decodificar(arquivo_info)
  if not info then
    return nil, erro_json_info
  end

  local destino, erro_destino = targets.validar({
    consumidor = { raiz = fisico.raizes.consumidor },
    diretorio_build = build,
    destino = dados.destino,
  }, {
    alvos = alvos,
    meson_info = info,
  })
  if not destino then
    return nil, "Identidade do target: " .. tostring(erro_destino)
  end

  local plano, erro_plano = dependencias.propor_alteracao({
    consumidor = { sistema = "meson", raiz = fisico.raizes.consumidor },
    origem = { sistema = "meson", raiz = fisico.raizes.origem, alvo = dados.origem.alvo },
    destino = destino,
    exportacao = dados.exportacao,
    alias = dados.alias,
    variavel_subprojeto = dados.variavel_subprojeto,
    variavel_dependencia = dados.variavel_dependencia,
  }, {
    consumidor = consumidor,
    origem = origem,
    raizes = fisico.raizes,
    link = fisico.link,
  })
  if not plano then
    return nil, "Planejamento: " .. tostring(erro_plano)
  end

  -- Acrescentar evidencias ao plano novo, sem alterar contratos dos componentes.
  plano.previa = true
  plano.autorizada_para_aplicacao = false
  plano.atualidade_inventario = "nao_comprovada"
  plano.precondicoes.consumidor.identidade = consumidor.identidade
  plano.precondicoes.origem.identidade = origem.identidade
  plano.precondicoes.caminhos = fisico
  plano.precondicoes.inventario = {
    alvos = arquivo_alvos,
    meson_info = arquivo_info,
    build = { caminho = build, identidade = observar(info_build) },
  }
  return plano, nil
end

-- Entrada: contrato de dependencies.propor_alteracao mais diretorio_build absoluto.
-- destino.id/name identificam a selecao; type/top_level usados no plano vem do validador.
-- Retorna previa, nil ou nil, mensagem. estado preserva alterar/sem_alteracao.
-- previa=true, autorizada_para_aplicacao=false e atualidade_inventario=nao_comprovada.
-- Conserva alteracoes, link, snapshots e evidencias fisicas/JSON nas precondicoes.
-- Somente leitura: nao configura, compila, confirma ou aplica qualquer alteracao.
-- A observacao nao e atomica; ausencia de mudanca durante cada leitura nao atesta
-- atualidade do inventario. A aplicacao futura deve revalidar todas as evidencias.
function M.previsualizar(dados)
  local ok, previa, erro = pcall(coordenar, dados)
  if not ok then
    return nil, "Falha na previa: " .. tostring(previa)
  end
  return previa, erro
end

return M
