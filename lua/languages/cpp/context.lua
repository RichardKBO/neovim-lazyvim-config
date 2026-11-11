local M = {}

-- ========================================
-- C++ - CONTEXTO COMPARTILHADO
-- ========================================
-- Identifica Meson, CMake ou standalone.
-- Nao modifica projetos, arquivos ou builds.
--
-- API:
--   M.detectar(caminho)
--
-- Sucesso:
--   {
--     sistema = "meson" | "cmake" | "standalone",
--     raiz = caminho_ou_nil
--   }
--
-- Falha:
--   nil, mensagem
-- ========================================

local meson = require("languages.cpp.meson.project")

local function normalizar(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil
  end

  local absoluto = vim.fn.fnamemodify(vim.fn.expand(caminho), ":p")

  return vim.fs.normalize(vim.uv.fs_realpath(absoluto) or absoluto)
end

local function diretorio_partida(caminho)
  local normalizado = normalizar(caminho)

  if not normalizado then
    return nil
  end

  local info = vim.uv.fs_stat(normalizado)

  if info and info.type == "directory" then
    return normalizado
  end

  return vim.fs.dirname(normalizado)
end

-- ========================================
-- LOCALIZAR PROJETO CMAKE
-- ========================================

local function localizar_cmake(caminho)
  local diretorio = diretorio_partida(caminho)

  if not diretorio then
    return nil
  end

  local encontrados = vim.fs.find("CMakeLists.txt", {
    path = diretorio,
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return normalizar(vim.fs.dirname(encontrados[1]))
end

-- ========================================
-- COMPARAR PROFUNDIDADE DAS RAIZES
-- ========================================
-- As raizes sao encontradas subindo a partir
-- do mesmo caminho. A mais profunda e a
-- mais proxima do arquivo atual.

local function profundidade(caminho)
  local _, quantidade = caminho:gsub("/", "")

  return quantidade
end

-- ========================================
-- DETECCAO CONTEXTUAL
-- ========================================

function M.detectar(caminho)
  if caminho == nil or caminho == "" then
    caminho = vim.api.nvim_buf_get_name(0)

    if caminho == "" then
      caminho = vim.fn.getcwd()
    end
  end

  local referencia = normalizar(caminho)

  if not referencia then
    return nil, "Caminho invalido."
  end

  local raiz_cmake = localizar_cmake(referencia)

  local ok_meson, raiz_meson = pcall(meson.localizar_raiz, referencia)

  if not ok_meson then
    return nil, "Falha na deteccao Meson: " .. tostring(raiz_meson)
  end

  if raiz_meson then
    raiz_meson = normalizar(raiz_meson)
  end

  -- ========================================
  -- PROJETO COM AMBOS OS SISTEMAS
  -- ========================================
  -- Preferir a raiz mais proxima.
  -- Em caso de empate, preferir Meson.

  if raiz_meson and raiz_cmake then
    if profundidade(raiz_meson) >= profundidade(raiz_cmake) then
      return {
        sistema = "meson",
        raiz = raiz_meson,
      }
    end

    return {
      sistema = "cmake",
      raiz = raiz_cmake,
    }
  end

  -- ========================================
  -- SOMENTE MESON
  -- ========================================

  if raiz_meson then
    return {
      sistema = "meson",
      raiz = raiz_meson,
    }
  end

  -- ========================================
  -- SOMENTE CMAKE
  -- ========================================

  if raiz_cmake then
    return {
      sistema = "cmake",
      raiz = raiz_cmake,
    }
  end

  -- ========================================
  -- ARQUIVO INDEPENDENTE
  -- ========================================

  return {
    sistema = "standalone",
    raiz = nil,
  }
end

return M
