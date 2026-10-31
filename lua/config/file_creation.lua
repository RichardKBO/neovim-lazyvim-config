-- ========================================
-- INFRAESTRUTURA GLOBAL - NOVOS ARQUIVOS
-- ========================================

local M = {}

-- Modulos independentes por linguagem.
local manipuladores = {
  cs = function(caminho)
    return require("languages.csharp.namespace_auto").gerar_no_arquivo(caminho)
  end,
  java = function(caminho)
    return require("languages.java.package_auto").gerar_no_arquivo(caminho)
  end,
}

-- ========================================
-- PROCESSAR ARQUIVO RECEM-CRIADO
-- ========================================

function M.processar_arquivo_novo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Caminho invalido."
  end

  local extensao = caminho:match("%.([^./\\]+)$")
  local manipulador = extensao and manipuladores[extensao]

  if not manipulador then
    return nil, "Nenhuma automacao para esta extensao."
  end

  return manipulador(caminho)
end

return M
