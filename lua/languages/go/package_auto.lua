-- ========================================
-- GO - PACKAGE AUTOMATICO
-- ========================================

local M = {}
local uv = vim.uv or vim.loop

local reservadas = {}

for palavra in ("break default func interface select case defer go map struct chan else goto package switch const fallthrough if range type continue for import return var"):gmatch("%S+") do
  reservadas[palavra] = true
end

local function nome_valido(nome)
  return type(nome) == "string"
    and nome ~= "_"
    and nome:match("^[%a_][%w_]*$") ~= nil
    and not reservadas[nome]
end

-- ========================================
-- LER PACKAGE DE ARQUIVO EXISTENTE
-- ========================================

local function ler_pacote(caminho)
  local ok, linhas = pcall(vim.fn.readfile, caminho, "", 200)

  if not ok then
    return nil, "Nao foi possivel ler: " .. caminho
  end

  local dentro_comentario = false

  for _, linha in ipairs(linhas) do
    local texto = vim.trim(linha)

    if dentro_comentario then
      local fim = texto:find("*/", 1, true)

      if fim then
        texto = vim.trim(texto:sub(fim + 2))
        dentro_comentario = false
      else
        texto = ""
      end
    end

    while texto:sub(1, 2) == "/*" do
      local fim = texto:find("*/", 3, true)

      if not fim then
        dentro_comentario = true
        texto = ""
        break
      end

      texto = vim.trim(texto:sub(fim + 2))
    end

    if texto:sub(1, 2) ~= "//" then
      local pacote = texto:match("^package%s+([%a_][%w_]*)")

      if nome_valido(pacote) then
        return pacote
      end
    end
  end

  return nil, "Package nao identificado em: " .. caminho
end

-- ========================================
-- IDENTIFICAR PACKAGE NO DIRETORIO
-- ========================================

local function pacote_existente(caminho)
  local diretorio = vim.fs.dirname(caminho)
  local scanner, erro = uv.fs_scandir(diretorio)

  if not scanner then
    return nil, erro
  end

  local comuns = {}
  local testes = {}

  while true do
    local nome, tipo = uv.fs_scandir_next(scanner)

    if not nome then
      break
    end

    if tipo == "file" and nome:match("%.go$") then
      local outro = vim.fs.joinpath(diretorio, nome)

      if outro ~= caminho then
        local pacote, erro_leitura = ler_pacote(outro)

        if not pacote then
          return nil, erro_leitura
        end

        local destino = nome:match("_test%.go$") and testes or comuns
        destino[pacote] = true
      end
    end
  end

  local encontrados = comuns

  if caminho:match("_test%.go$") and next(testes) then
    encontrados = testes
  end

  local pacote = nil

  for nome in pairs(encontrados) do
    if pacote and pacote ~= nome then
      return nil, "Pacotes conflitantes no diretorio."
    end

    pacote = nome
  end

  return pacote
end

-- ========================================
-- DETERMINAR PACKAGE DO NOVO ARQUIVO
-- ========================================

function M.obter_pacote(caminho)
  if type(caminho) ~= "string" or not caminho:match("%.go$") then
    return nil, "Caminho Go invalido."
  end

  caminho = vim.fs.normalize(caminho)

  local pacote, erro = pacote_existente(caminho)

  if erro then
    return nil, erro
  end

  if pacote then
    return pacote
  end

  local diretorio = vim.fs.dirname(caminho)
  local nome_arquivo = vim.fs.basename(caminho)

  local modulos = vim.fs.find("go.mod", {
    path = diretorio,
    upward = true,
  })

  if #modulos > 0 then
    local raiz = vim.fs.dirname(modulos[1])
    local relativo = vim.fs.relpath(raiz, diretorio)

    if nome_arquivo == "main.go" and diretorio == raiz then
      return "main"
    end

    if relativo and relativo:match("^cmd/[^/]+$") then
      return "main"
    end
  end

  local nome = vim.fs.basename(diretorio)

  if not nome_valido(nome) then
    return nil, "Nome de pacote invalido: " .. nome
  end

  return nome
end

-- ========================================
-- ESCREVER SOMENTE EM ARQUIVO VAZIO
-- ========================================

function M.gerar_no_arquivo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Caminho invalido."
  end

  caminho = vim.fs.normalize(caminho)

  if not caminho:match("%.go$") then
    return false, "O arquivo nao possui extensao .go."
  end

  local estado = uv.fs_lstat(caminho)

  if not estado or estado.type ~= "file" then
    return false, "Arquivo Go inexistente ou invalido."
  end

  if estado.size ~= 0 then
    return false, "Arquivo ja possui conteudo. Nenhuma alteracao."
  end

  local pacote, erro = M.obter_pacote(caminho)

  if not pacote then
    return false, erro
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
  local fechado, erro_fechamento = uv.fs_close(fd)

  if escritos ~= #conteudo or not fechado then
    return false, "Falha na escrita: " .. tostring(erro_escrita or erro_fechamento)
  end

  return true, pacote
end

return M
