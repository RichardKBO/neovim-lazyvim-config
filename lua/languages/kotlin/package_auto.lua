-- ========================================
-- KOTLIN - PACKAGE AUTOMATICO
-- ========================================

local M = {}

local reservadas = {
  ["as"] = true,
  ["break"] = true,
  ["class"] = true,
  ["continue"] = true,
  ["do"] = true,
  ["else"] = true,
  ["false"] = true,
  ["for"] = true,
  ["fun"] = true,
  ["if"] = true,
  ["in"] = true,
  ["interface"] = true,
  ["is"] = true,
  ["null"] = true,
  ["object"] = true,
  ["package"] = true,
  ["return"] = true,
  ["super"] = true,
  ["this"] = true,
  ["throw"] = true,
  ["true"] = true,
  ["try"] = true,
  ["typealias"] = true,
  ["typeof"] = true,
  ["val"] = true,
  ["var"] = true,
  ["when"] = true,
  ["while"] = true,
}

-- ========================================
-- IDENTIFICAR PACKAGE PELO PROJETO
-- ========================================

function M.obter_pacote(caminho)
  if type(caminho) ~= "string" or not caminho:match("%.kt$") then
    return nil, "Caminho Kotlin invalido."
  end

  caminho = vim.fs.normalize(caminho)
  local diretorio = vim.fs.dirname(caminho)

  local marcadores = vim.fs.find({
    "build.gradle.kts",
    "build.gradle",
    "pom.xml",
  }, {
    path = diretorio,
    upward = true,
  })

  if #marcadores == 0 then
    return nil, "Projeto Gradle ou Maven nao encontrado."
  end

  local raiz_modulo = vim.fs.dirname(marcadores[1])
  local relativo = vim.fs.relpath(raiz_modulo, diretorio)

  if not relativo then
    return nil, "Diretorio fora do modulo Kotlin."
  end

  local partes = vim.split(relativo, "/", {
    plain = true,
    trimempty = true,
  })

  if #partes < 3
    or partes[1] ~= "src"
    or (partes[2] ~= "main" and partes[2] ~= "test")
    or partes[3] ~= "kotlin" then
    return nil, "Arquivo fora das fontes Kotlin reconhecidas."
  end

  local nomes = {}

  for indice = 4, #partes do
    local nome = partes[indice]

    if not nome:match("^[%a_][%w_]*$") or reservadas[nome] then
      return nil, "Diretorio de pacote invalido: " .. nome
    end

    table.insert(nomes, nome)
  end

  -- String vazia representa o pacote padrao.
  return table.concat(nomes, ".")
end

-- ========================================
-- GERAR PACKAGE EM ARQUIVO NOVO E VAZIO
-- ========================================

function M.gerar_no_arquivo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Caminho invalido."
  end

  caminho = vim.fs.normalize(caminho)

  if not caminho:match("%.kt$") then
    return false, "O arquivo nao possui extensao .kt."
  end

  local uv = vim.uv or vim.loop
  local estado = uv.fs_lstat(caminho)

  if not estado or estado.type ~= "file" then
    return false, "Arquivo Kotlin inexistente ou invalido."
  end

  if estado.size ~= 0 then
    return false, "Arquivo ja possui conteudo. Nenhuma alteracao."
  end

  local pacote, erro = M.obter_pacote(caminho)

  if pacote == nil then
    return false, erro
  end

  if pacote == "" then
    return true, "Pacote padrao; nenhuma declaracao necessaria."
  end

  local fd, erro_abertura = uv.fs_open(caminho, "r+", 420)

  if not fd then
    return false, "Falha ao abrir arquivo: " .. tostring(erro_abertura)
  end

  local atual = uv.fs_fstat(fd)

  if not atual or atual.type ~= "file" or atual.size ~= 0 then
    uv.fs_close(fd)
    return false, "Arquivo nao esta vazio. Nenhuma alteracao."
  end

  local conteudo = "package " .. pacote .. "\n\n"
  local escritos, erro_escrita = uv.fs_write(fd, conteudo, 0)

  uv.fs_close(fd)

  if escritos ~= #conteudo then
    return false, "Falha ao escrever package: " .. tostring(erro_escrita)
  end

  return true, pacote
end

return M
