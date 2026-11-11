local M = {}

-- ========================================
-- MESON - DESCOBERTA DE PROJETOS
-- ========================================

local function normalizar(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil
  end

  local absoluto = vim.fn.fnamemodify(vim.fn.expand(caminho), ":p")

  return vim.fs.normalize(vim.uv.fs_realpath(absoluto) or absoluto)
end

-- Um meson.build de subdiretorio nao
-- representa necessariamente um projeto.
-- A raiz deve declarar project().
local function eh_raiz_meson(diretorio)
  local arquivo = vim.fs.joinpath(diretorio, "meson.build")

  if vim.fn.filereadable(arquivo) ~= 1 then
    return false
  end

  local ok, linhas = pcall(vim.fn.readfile, arquivo)

  if not ok then
    return false
  end

  for _, linha in ipairs(linhas) do
    local texto = vim.trim(linha)

    -- Ignorar linhas vazias e comentarios.
    if texto ~= "" and not texto:match("^#") then
      return texto:match("^project%s*%(") ~= nil
    end
  end

  return false
end

-- ========================================
-- API PUBLICA
-- ========================================

function M.localizar_raiz(caminho)
  if caminho == nil then
    caminho = vim.api.nvim_buf_get_name(0)
  end

  local normalizado = normalizar(caminho)

  if not normalizado then
    return nil, "Caminho invalido."
  end

  local info = vim.uv.fs_stat(normalizado)

  local diretorio = normalizado

  if not info or info.type ~= "directory" then
    diretorio = vim.fs.dirname(normalizado)
  end

  while diretorio do
    if eh_raiz_meson(diretorio) then
      return diretorio
    end

    local pai = vim.fs.dirname(diretorio)

    if not pai or pai == diretorio then
      break
    end

    diretorio = pai
  end

  return nil, "Projeto Meson nao encontrado."
end

return M
