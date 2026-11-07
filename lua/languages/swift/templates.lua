-- ========================================
-- SWIFT - TEMPLATES DE CODIGO
-- Geracao de estruturas Swift
-- Sem operacoes de escrita no disco
-- ========================================

local M = {}

-- ========================================
-- GERAR CONTEUDO SWIFT
-- ========================================

function M.gerar(tipo, nome, opcoes)
  opcoes = opcoes or {}

  if type(tipo) ~= "string" or type(nome) ~= "string" then
    return nil, "Swift: tipo ou nome invalido."
  end

  local linhas = {}

  if tipo == "class" then
    linhas = {
      "class " .. nome .. " {",
      "    init() {",
      "    }",
      "}",
    }
  elseif tipo == "struct" then
    linhas = {
      "struct " .. nome .. " {",
      "}",
    }
  elseif tipo == "protocol" then
    linhas = {
      "protocol " .. nome .. " {",
      "}",
    }
  elseif tipo == "enum" then
    linhas = {
      "enum " .. nome .. " {",
      "    case exemplo",
      "}",
    }
  elseif tipo == "actor" then
    linhas = {
      "actor " .. nome .. " {",
      "}",
    }
  elseif tipo == "extension" then
    local alvo = opcoes.alvo

    if type(alvo) ~= "string" or alvo == "" then
      return nil, "Swift: informe o tipo que sera estendido."
    end

    linhas = {
      "extension " .. alvo .. " {",
      "}",
    }
  elseif tipo == "error" then
    linhas = {
      "enum " .. nome .. ": Error {",
      "    case exemplo",
      "}",
    }
  elseif tipo == "test" then
    local modulo = opcoes.modulo

    if type(modulo) ~= "string" or modulo == "" then
      return nil, "Swift: modulo de testes nao informado."
    end

    linhas = {
      "import Testing",
      "@testable import " .. modulo,
      "",
      "struct " .. nome .. " {",
      "    @Test",
      "    func exemplo() {",
      "        #expect(true)",
      "    }",
      "}",
    }
  else
    return nil, "Swift: template desconhecido: " .. tipo
  end

  table.insert(linhas, "")

  return linhas
end

return M
