-- ========================================
-- SWIFT - AUTOMACAO DE NOVOS ARQUIVOS
-- Integracao com Snacks Explorer
-- ========================================

local M = {}

local uv = vim.uv or vim.loop

-- ========================================
-- VALIDAR ARQUIVO SWIFT
-- ========================================

function M.validar_arquivo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Swift: caminho invalido."
  end

  caminho = vim.fs.normalize(caminho)

  if not caminho:match("%.swift$") then
    return false, "Swift: extensao .swift necessaria."
  end

  local nome = vim.fs.basename(caminho)

  -- Arquivos especiais nao recebem templates OOP.
  if nome == "Package.swift" or nome == "main.swift" then
    return nil, "Swift: arquivo especial preservado."
  end

  local estado = uv.fs_lstat(caminho)

  if not estado or estado.type ~= "file" then
    return false, "Swift: arquivo inexistente ou invalido."
  end

  -- Nunca modificar um arquivo com conteudo.
  if estado.size ~= 0 then
    return false, "Swift: arquivo ja possui conteudo."
  end

  return true, caminho
end

-- ========================================
-- ENCAMINHAR PARA O GERADOR DE TIPOS
-- ========================================

function M.gerar_no_arquivo(caminho)
  local valido, resultado = M.validar_arquivo(caminho)

  if valido ~= true then
    return valido, resultado
  end

  -- Carregamento sob demanda.
  -- A logica de geracao pertence ao modulo types.
  local carregou, tipos = pcall(require, "languages.swift.types")

  if not carregou then
    return false, "Swift: modulo de tipos indisponivel: " .. tostring(tipos)
  end

  if type(tipos.gerar_no_arquivo) ~= "function" then
    return false, "Swift: gerador de tipos nao implementado."
  end

  return tipos.gerar_no_arquivo(resultado)
end

return M
