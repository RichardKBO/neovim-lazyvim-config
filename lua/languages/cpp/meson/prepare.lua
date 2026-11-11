local M = {}

-- ========================================
-- MESON - PREPARACAO PARA F6 E F8
-- ========================================
-- Configura o projeto, consulta os targets,
-- associa o arquivo atual aos executaveis,
-- permite selecionar um executavel e compila.
--
-- Nao executa nem depura o programa.
-- Entrega o caminho do executavel ao runner.
-- ========================================

local build = require("languages.cpp.meson.build")
local targets = require("languages.cpp.meson.targets")
local selection = require("languages.cpp.meson.selection")

local function normalizar(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil
  end

  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(caminho), ":p"))
end

-- ========================================
-- INICIO SEGURO DE OPERACOES ASSINCRONAS
-- ========================================

local function iniciar(funcao, ...)
  local ok, iniciou, erro = pcall(funcao, ...)

  if not ok then
    return false, tostring(iniciou)
  end

  if not iniciou then
    return false, erro or "Operacao nao iniciada."
  end

  return true
end

-- ========================================
-- API PUBLICA
-- ========================================

-- callback(executavel, erro)
--
-- Sucesso:
--   callback(caminho_executavel, nil)
--
-- Erro:
--   callback(nil, mensagem)
--
-- Cancelamento:
--   callback(nil, nil)
--
-- Retorno imediato:
--   true             - operacao iniciada
--   false, mensagem  - falha antes de iniciar

function M.preparar(raiz, arquivo, callback)
  if type(callback) ~= "function" then
    return false, "Callback de preparacao invalido."
  end

  local projeto = normalizar(raiz)
  local fonte = normalizar(arquivo)

  if not projeto or not fonte then
    return false, "Projeto ou arquivo invalido."
  end

  local diretorio_build = vim.fs.joinpath(projeto, "build")

  local finalizado = false

  -- Entregar o resultado somente uma vez.
  local function finalizar(executavel, erro)
    if finalizado then
      return
    end

    finalizado = true

    callback(executavel, erro)
  end

  -- ========================================
  -- COMPILAR EXECUTAVEL SELECIONADO
  -- ========================================

  local function compilar(escolha)
    if not escolha then
      finalizar(nil, nil)
      return
    end

    if type(escolha.name) ~= "string" or escolha.name == "" then
      finalizar(nil, "Target Meson sem nome valido.")
      return
    end

    local artefato = nil

    for _, caminho in ipairs(escolha.filename or {}) do
      if type(caminho) == "string" and caminho ~= "" then
        artefato = caminho
        break
      end
    end

    if not artefato then
      finalizar(nil, "Executavel Meson sem caminho de artefato.")
      return
    end

    if not artefato:match("^/") then
      artefato = vim.fs.joinpath(diretorio_build, artefato)
    end

    artefato = vim.fs.normalize(artefato)

    local iniciou, erro = iniciar(build.compilar, diretorio_build, escolha.name, function(sucesso, mensagem)
      if not sucesso then
        finalizar(nil, mensagem or "Falha na compilacao Meson.")
        return
      end

      finalizar(artefato, nil)
    end)

    if not iniciou then
      finalizar(nil, erro)
    end
  end

  -- ========================================
  -- ASSOCIAR FONTE AOS EXECUTAVEIS
  -- ========================================

  local function selecionar(alvos)
    local ok, executaveis, erro = pcall(selection.executaveis_por_fonte, alvos, fonte)

    if not ok then
      finalizar(nil, tostring(executaveis))
      return
    end

    if not executaveis then
      finalizar(nil, erro or "Falha ao associar fonte aos targets.")
      return
    end

    if #executaveis == 0 then
      finalizar(nil, "Arquivo nao associado a um executavel Meson.")
      return
    end

    if #executaveis == 1 then
      compilar(executaveis[1])
      return
    end

    -- Somente perguntar quando houver
    -- mais de um executavel possivel.
    local abriu, erro_selecao = pcall(vim.ui.select, executaveis, {
      prompt = "Selecione o executavel Meson:",
      format_item = function(item)
        return item.name or "Target sem nome"
      end,
    }, function(escolha)
      compilar(escolha)
    end)

    if not abriu then
      finalizar(nil, "Falha ao abrir selecao: " .. tostring(erro_selecao))
    end
  end

  -- ========================================
  -- CONSULTAR TARGETS
  -- ========================================

  local function listar()
    local iniciou, erro = iniciar(targets.listar, diretorio_build, function(alvos, mensagem)
      if not alvos then
        finalizar(nil, mensagem or "Falha na introspeccao Meson.")
        return
      end

      selecionar(alvos)
    end)

    if not iniciou then
      finalizar(nil, erro)
    end
  end

  -- ========================================
  -- CONFIGURAR E INICIAR PREPARACAO
  -- ========================================

  local iniciou, erro = iniciar(build.configurar, projeto, diretorio_build, function(sucesso, mensagem)
    if not sucesso then
      finalizar(nil, mensagem or "Falha na configuracao Meson.")
      return
    end

    listar()
  end)

  if not iniciou then
    return false, erro
  end

  return true
end

return M
