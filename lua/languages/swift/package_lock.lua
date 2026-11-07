-- ========================================
-- SWIFT - BLOQUEIO COMPARTILHADO SWIFTPM
-- Evita operacoes concorrentes no mesmo pacote
-- ========================================

local M = {}

local uv = vim.uv or vim.loop

-- Estado compartilhado entre os modulos Swift
-- na mesma instancia do Neovim.
local bloqueios = {}

-- ========================================
-- NORMALIZAR DIRETORIO DO PACOTE
-- ========================================

local function normalizar_raiz(raiz)
  if type(raiz) ~= "string" or raiz == "" then
    return nil, "SwiftPM: diretorio do projeto invalido."
  end

  local caminho = uv.fs_realpath(raiz)

  if not caminho then
    return nil, "SwiftPM: diretorio do projeto inexistente."
  end

  local estado = uv.fs_stat(caminho)

  if not estado or estado.type ~= "directory" then
    return nil, "SwiftPM: caminho nao e um diretorio."
  end

  return caminho
end

-- ========================================
-- ADQUIRIR BLOQUEIO
-- ========================================

function M.adquirir(raiz)
  local chave, erro = normalizar_raiz(raiz)

  if not chave then
    return nil, erro
  end

  if bloqueios[chave] then
    return nil, "SwiftPM: ja existe uma operacao em andamento neste projeto."
  end

  -- Token exclusivo da operacao.
  -- Impede que outra operacao libere
  -- um bloqueio que nao lhe pertence.
  local token = {}

  bloqueios[chave] = token

  return token
end

-- ========================================
-- LIBERAR BLOQUEIO
-- ========================================

function M.liberar(raiz, token)
  local chave = normalizar_raiz(raiz)

  if not chave or type(token) ~= "table" then
    return false
  end

  if bloqueios[chave] ~= token then
    return false
  end

  bloqueios[chave] = nil

  return true
end

-- ========================================
-- CONSULTAR ESTADO
-- ========================================

function M.ocupado(raiz)
  local chave = normalizar_raiz(raiz)

  if not chave then
    return false
  end

  return bloqueios[chave] ~= nil
end

return M
