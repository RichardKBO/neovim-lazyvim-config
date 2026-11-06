-- ========================================
-- SWIFT - GERENCIAMENTO DE TIPOS
-- Selecao, validacao e escrita segura
-- ========================================

local M = {}

local uv = vim.uv or vim.loop
local templates = require("languages.swift.templates")

-- ========================================
-- TIPOS DISPONIVEIS
-- ========================================

local tipos = {
  { nome = "Nova classe", tipo = "class" },
  { nome = "Nova struct", tipo = "struct" },
  { nome = "Novo protocol", tipo = "protocol" },
  { nome = "Novo enum", tipo = "enum" },
  { nome = "Novo actor", tipo = "actor" },
  { nome = "Nova extension", tipo = "extension" },
  { nome = "Novo tipo Error", tipo = "error" },
  { nome = "Novo teste Swift", tipo = "test" },
}

-- ========================================
-- PALAVRAS RESERVADAS
-- ========================================

local reservadas = {}

local palavras = [[
  Any Self Type Protocol
  actor associatedtype as async await
  break case catch class continue
  default defer deinit do else enum
  extension fallthrough false fileprivate
  for func guard if import in
  indirect infix init inout internal
  is let nil nonisolated open operator
  package postfix precedencegroup prefix
  private protocol public repeat rethrows
  return self some static struct subscript
  super switch throw throws true try
  typealias var where while
]]

for palavra in palavras:gmatch("%S+") do
  reservadas[palavra] = true
end

-- ========================================
-- VALIDAR IDENTIFICADOR SWIFT
-- ========================================

function M.identificador_valido(nome)
  return type(nome) == "string" and nome:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil and not reservadas[nome]
end

-- ========================================
-- IDENTIFICAR CONTEXTO SWIFTPM
-- ========================================

local function identificar_contexto(caminho)
  local manifestos = vim.fs.find("Package.swift", {
    path = vim.fs.dirname(caminho),
    upward = true,
  })

  if #manifestos == 0 then
    return nil, "Swift: Package.swift nao encontrado."
  end

  local raiz = vim.fs.dirname(manifestos[1])
  local relativo = vim.fs.relpath(raiz, caminho)

  if not relativo then
    return nil, "Swift: arquivo fora do projeto."
  end

  local em_sources = relativo:match("^Sources/") ~= nil
  local em_tests = relativo:match("^Tests/") ~= nil

  if not em_sources and not em_tests then
    return nil, "Swift: crie arquivos em Sources/ ou Tests/."
  end

  return {
    raiz = raiz,
    relativo = relativo,
    teste = em_tests,
  }
end

-- ========================================
-- GRAVAR SOMENTE EM ARQUIVO VAZIO
-- ========================================

local function gravar_arquivo(caminho, linhas)
  local estado = uv.fs_lstat(caminho)

  if not estado or estado.type ~= "file" then
    return false, "Swift: arquivo inexistente ou invalido."
  end

  if estado.size ~= 0 then
    return false, "Swift: arquivo ja possui conteudo."
  end

  local buffer = vim.fn.bufnr(caminho)

  if buffer ~= -1 and vim.bo[buffer].modified then
    return false, "Swift: salve ou descarte alteracoes pendentes."
  end

  local fd, erro_abertura = uv.fs_open(caminho, "r+", 420)

  if not fd then
    return false, "Swift: falha ao abrir arquivo: " .. tostring(erro_abertura)
  end

  local atual = uv.fs_fstat(fd)

  if not atual or atual.type ~= "file" or atual.size ~= 0 or atual.dev ~= estado.dev or atual.ino ~= estado.ino then
    uv.fs_close(fd)

    return false, "Swift: arquivo alterado durante a operacao."
  end

  local conteudo = table.concat(linhas, "\n")
  local escritos, erro_escrita = uv.fs_write(fd, conteudo, 0)
  local fechado, erro_fechamento = uv.fs_close(fd)

  if escritos ~= #conteudo or not fechado then
    return false, "Swift: falha na escrita: " .. tostring(erro_escrita or erro_fechamento)
  end

  return true
end

-- ========================================
-- GERAR E SALVAR CONTEUDO
-- ========================================

local function concluir_geracao(caminho, tipo, nome, opcoes)
  local linhas, erro = templates.gerar(tipo, nome, opcoes)

  if not linhas then
    vim.notify(erro, vim.log.levels.ERROR)
    return
  end

  local sucesso, mensagem = gravar_arquivo(caminho, linhas)

  if not sucesso then
    vim.notify(mensagem, vim.log.levels.ERROR)
    return
  end

  vim.notify("Swift: arquivo gerado com sucesso: " .. vim.fs.basename(caminho), vim.log.levels.INFO)
end

-- ========================================
-- SELECIONAR TIPO E GERAR ARQUIVO
-- ========================================

function M.gerar_no_arquivo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Swift: caminho invalido."
  end

  caminho = vim.fs.normalize(caminho)

  if not caminho:match("%.swift$") then
    return false, "Swift: extensao invalida."
  end

  local nome = vim.fs.basename(caminho):gsub("%.swift$", "")

  if not M.identificador_valido(nome) then
    return false, "Swift: nome de tipo invalido: " .. nome
  end

  local contexto, erro = identificar_contexto(caminho)

  if not contexto then
    return false, erro
  end

  local disponiveis = {}

  for _, item in ipairs(tipos) do
    if contexto.teste then
      if item.tipo == "test" then
        table.insert(disponiveis, item)
      end
    elseif item.tipo ~= "test" then
      table.insert(disponiveis, item)
    end
  end

  vim.ui.select(disponiveis, {
    prompt = "Swift - Tipo para " .. nome,

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      vim.notify("Swift: geracao cancelada. Arquivo vazio preservado.", vim.log.levels.INFO)
      return
    end

    if escolha.tipo == "extension" then
      local padrao = nome:match("^(.-)Extension$") or nome

      vim.ui.input({
        prompt = "Tipo Swift que sera estendido: ",
        default = padrao,
      }, function(alvo)
        if alvo == nil then
          return
        end

        alvo = vim.trim(alvo)

        if not M.identificador_valido(alvo) then
          vim.notify("Swift: tipo de destino invalido.", vim.log.levels.ERROR)
          return
        end

        concluir_geracao(caminho, "extension", nome, {
          alvo = alvo,
        })
      end)

      return
    end

    if escolha.tipo == "test" then
      vim.ui.input({
        prompt = "Modulo Swift que sera testado: ",
      }, function(modulo)
        if modulo == nil then
          return
        end

        modulo = vim.trim(modulo)

        if not M.identificador_valido(modulo) then
          vim.notify("Swift: modulo invalido.", vim.log.levels.ERROR)
          return
        end

        concluir_geracao(caminho, "test", nome, {
          modulo = modulo,
        })
      end)

      return
    end

    concluir_geracao(caminho, escolha.tipo, nome)
  end)

  return true, "Swift: selecao de tipo iniciada."
end

return M
