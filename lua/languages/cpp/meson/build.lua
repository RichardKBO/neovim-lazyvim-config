local M = {}

-- ========================================
-- MESON - CONFIGURACAO E COMPILACAO
-- ========================================
-- Setup, reconfigure e compilacao de targets.
-- Operacoes assincronas com vim.system.
-- Nao altera o cwd global do Neovim.
-- ========================================

local function normalizar(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(caminho), ":p"))
end

local function configurado(build)
  local coredata = vim.fs.joinpath(build, "meson-private", "coredata.dat")

  return vim.uv.fs_stat(coredata) ~= nil
end

local function obter_erro(resultado, padrao)
  local mensagem = vim.trim(resultado.stderr or "")

  if mensagem == "" then
    mensagem = vim.trim(resultado.stdout or "")
  end

  if mensagem == "" then
    mensagem = padrao
  end

  return mensagem
end

-- Um unico executor para as operacoes deste modulo.
-- O resultado nativo e preservado; cada API adapta somente seu callback.
local function executar(comando, callback)
  local ok, erro = pcall(vim.system, comando, { text = true }, function(resultado)
    vim.schedule(function()
      callback(resultado)
    end)
  end)

  if not ok then
    return false, tostring(erro)
  end

  return true
end

-- ========================================
-- SETUP / RECONFIGURE
-- ========================================

function M.configurar(raiz, diretorio_build, callback)
  if type(callback) ~= "function" then
    return false, "Callback invalido."
  end

  local projeto = normalizar(raiz)
  local build = normalizar(diretorio_build)

  if not projeto or not build then
    return false, "Caminho do projeto ou build invalido."
  end

  local info = vim.uv.fs_stat(projeto)

  if not info or info.type ~= "directory" then
    return false, "Diretorio do projeto inexistente."
  end

  local meson_build = vim.fs.joinpath(projeto, "meson.build")

  if vim.fn.filereadable(meson_build) ~= 1 then
    return false, "meson.build nao encontrado."
  end

  if projeto == build then
    return false, "Build deve ser separado da raiz do projeto."
  end

  if vim.fn.executable("meson") ~= 1 then
    return false, "Meson nao encontrado no PATH."
  end

  local comando

  if configurado(build) then
    comando = {
      "meson",
      "setup",
      "--reconfigure",
      build,
      projeto,
    }
  else
    comando = {
      "meson",
      "setup",
      "--backend=ninja",
      build,
      projeto,
    }
  end

  return executar(comando, function(resultado)
    if resultado.code ~= 0 then
      callback(false, obter_erro(resultado, "Falha ao configurar Meson."))
      return
    end

    callback(true, resultado.stdout or "")
  end)
end

-- ========================================
-- COMPILACAO DE TARGET
-- ========================================

function M.compilar(diretorio_build, alvo, callback)
  if type(callback) ~= "function" then
    return false, "Callback invalido."
  end

  local build = normalizar(diretorio_build)

  if not build then
    return false, "Diretorio de build invalido."
  end

  local info = vim.uv.fs_stat(build)

  if not info or info.type ~= "directory" then
    return false, "Diretorio de build inexistente."
  end

  if not configurado(build) then
    return false, "Build Meson nao configurado."
  end

  if type(alvo) ~= "string" or alvo == "" or not alvo:match("^[%w_][%w_.%+%-]*$") then
    return false, "Nome de target invalido."
  end

  if vim.fn.executable("meson") ~= 1 then
    return false, "Meson nao encontrado no PATH."
  end

  local comando = {
    "meson",
    "compile",
    "-C",
    build,
    alvo,
  }

  return executar(comando, function(resultado)
    if resultado.code ~= 0 then
      callback(false, obter_erro(resultado, "Falha ao compilar target Meson."))
      return
    end

    callback(true, resultado.stdout or "")
  end)
end

-- ========================================
-- RECONFIGURACAO EXPLICITAMENTE SOLICITADA
-- ========================================
-- dados = { consumidor = { raiz = "/..." }, diretorio_build = "/..." }.
-- Exige diretorios explicitos e coredata.dat regular ja existente.
-- Nao valida ownership, caminhos canonicos ou atualidade do inventario:
-- a coordenacao de dependencias deve fazer essas verificacoes.
--
-- Retorno imediato: true (processo iniciado) OU false, resultado.
-- Com callback valido, entrega callback(resultado) uma unica vez, agendado,
-- inclusive para falhas anteriores ao inicio. Callback invalido: false, resultado, sem callback.
-- resultado.estado = erro_validacao|erro_inicializacao|falha_meson|sucesso;
-- processo_iniciado, comando (quando construido), code/signal (quando existem),
-- stdout, stderr e mensagem. Nao inventa codigo de saida quando nao houve processo.
-- Sucesso do processo nao comprova atualidade nem autoriza aplicar dependencias.
-- A chamada e a solicitacao explicita; nenhuma API antiga chama esta funcao.
function M.reconfigurar_explicitamente(dados, callback)
  if type(callback) ~= "function" then
    return false, {
      estado = "erro_validacao",
      processo_iniciado = false,
      stdout = "",
      stderr = "",
      mensagem = "Callback invalido.",
    }
  end

  local finalizado = false
  local comando
  local function entregar(resultado)
    if finalizado then
      return
    end
    finalizado = true
    callback(resultado)
  end

  local function falhar(estado, mensagem)
    local resultado = {
      estado = estado,
      processo_iniciado = false,
      comando = comando and vim.deepcopy(comando) or nil,
      stdout = "",
      stderr = "",
      mensagem = mensagem,
    }
    vim.schedule(function()
      entregar(resultado)
    end)
    return false, resultado
  end

  if type(dados) ~= "table" or type(dados.consumidor) ~= "table" then
    return falhar("erro_validacao", "Informe consumidor.raiz e diretorio_build.")
  end
  if type(dados.consumidor.raiz) ~= "string" or type(dados.diretorio_build) ~= "string" then
    return falhar("erro_validacao", "Source e build devem ser informados explicitamente.")
  end
  for _, caminho in ipairs({ dados.consumidor.raiz, dados.diretorio_build }) do
    if caminho:sub(1, 1) ~= "/" or caminho:find("%c") then
      return falhar("erro_validacao", "Source e build devem ser caminhos absolutos validos.")
    end
  end

  local projeto = normalizar(dados.consumidor.raiz)
  local build = normalizar(dados.diretorio_build)
  if not projeto or not build or projeto == build then
    return falhar("erro_validacao", "Source e build devem ser diretorios distintos.")
  end
  for _, caminho in ipairs({ projeto, build }) do
    local info = vim.uv.fs_stat(caminho)
    if not info or info.type ~= "directory" then
      return falhar("erro_validacao", "Diretorio inexistente ou invalido: " .. caminho)
    end
  end

  local manifesto = vim.uv.fs_stat(vim.fs.joinpath(projeto, "meson.build"))
  if not manifesto or manifesto.type ~= "file" then
    return falhar("erro_validacao", "meson.build regular nao encontrado.")
  end
  local coredata = vim.uv.fs_stat(vim.fs.joinpath(build, "meson-private", "coredata.dat"))
  if not coredata or coredata.type ~= "file" then
    return falhar("erro_validacao", "Build Meson previamente configurado exigido; setup inicial nao permitido.")
  end

  comando = {
    "meson",
    "setup",
    "--reconfigure",
    "--wrap-mode=nodownload",
    build,
    projeto,
  }
  if vim.fn.executable("meson") ~= 1 then
    return falhar("erro_inicializacao", "Meson nao encontrado no PATH.")
  end

  local iniciou, erro = executar(comando, function(resultado)
    local sucesso = resultado.code == 0 and (resultado.signal == nil or resultado.signal == 0)
    entregar({
      estado = sucesso and "sucesso" or "falha_meson",
      processo_iniciado = true,
      comando = vim.deepcopy(comando),
      code = resultado.code,
      signal = resultado.signal,
      stdout = resultado.stdout or "",
      stderr = resultado.stderr or "",
      mensagem = sucesso and "Reconfiguracao Meson concluida."
        or obter_erro(resultado, "Falha ao reconfigurar Meson."),
    })
  end)
  if not iniciou then
    return falhar("erro_inicializacao", erro)
  end

  return true
end

return M
