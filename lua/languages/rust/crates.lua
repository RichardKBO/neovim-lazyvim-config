local M = {}

local cargo_projeto = require("languages.rust.cargo")

local function localizar_cargo()
  local executavel = vim.fn.exepath("cargo")

  if executavel == "" then
    return nil, "Cargo nao encontrado no PATH."
  end

  return executavel
end

local function validar_tipo(tipo)
  if tipo ~= "bin" and tipo ~= "lib" then
    return nil, "Tipo invalido. Utilize 'bin' ou 'lib'."
  end

  return true
end

local function validar_caminho_relativo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil, "Informe o caminho da nova crate."
  end

  if caminho:sub(1, 1) == "/" or caminho:find("//", 1, true) or caminho:sub(-1) == "/" then
    return nil, "Caminho relativo invalido."
  end

  for parte in caminho:gmatch("[^/]+") do
    if not parte:match("^[%w_%-]+$") then
      return nil, "Nome de pasta invalido: " .. parte
    end
  end

  return true
end

local function preparar_destino(destino)
  if vim.uv.fs_stat(destino) then
    return nil, "O destino ja existe:\n" .. destino
  end

  local pai = vim.fs.dirname(destino)

  vim.fn.mkdir(pai, "p")

  if vim.fn.isdirectory(pai) ~= 1 then
    return nil, "Nao foi possivel criar:\n" .. pai
  end

  return true
end

local function cargo_new(destino, tipo, diretorio)
  local cargo, erro = localizar_cargo()

  if not cargo then
    return nil, erro
  end

  local valido, erro_tipo = validar_tipo(tipo)

  if not valido then
    return nil, erro_tipo
  end

  local resultado = vim
    .system({
      cargo,
      "new",
      "--" .. tipo,
      destino,
    }, {
      cwd = diretorio,
      text = true,
    })
    :wait()

  if resultado.code ~= 0 then
    local mensagem = resultado.stderr or ""

    if mensagem == "" then
      mensagem = resultado.stdout or ""
    end

    return nil, "Falha ao criar crate:\n" .. mensagem
  end

  return vim.fs.joinpath(destino, "Cargo.toml")
end

local function verificar_workspace(manifesto)
  local linhas = vim.fn.readfile(manifesto)

  for _, linha in ipairs(linhas) do
    if linha:match("^%s*%[workspace%]") then
      return true
    end
  end

  return nil, "O projeto atual nao declara [workspace]."
end

-- Aceita tanto a propria raiz quanto subpastas.
local function dentro_da_raiz(caminho, raiz)
  local caminho_real = vim.uv.fs_realpath(caminho)
  local raiz_real = vim.uv.fs_realpath(raiz)

  if not caminho_real or not raiz_real then
    return false
  end

  return caminho_real == raiz_real or vim.startswith(caminho_real, raiz_real .. "/")
end

-- Encontrar um ancestral existente antes de criar pastas.
local function ancestral_existente(caminho)
  local diretorio = caminho

  while not vim.uv.fs_stat(diretorio) do
    local anterior = vim.fs.dirname(diretorio)

    if anterior == diretorio then
      return nil
    end

    diretorio = anterior
  end

  return diretorio
end

-- Criar uma crate no workspace atual.
function M.criar_no_workspace(caminho, tipo, referencia)
  local valido, erro = validar_caminho_relativo(caminho)

  if not valido then
    return nil, erro
  end

  valido, erro = validar_tipo(tipo)

  if not valido then
    return nil, erro
  end

  local contexto

  contexto, erro = cargo_projeto.contexto(referencia)

  if not contexto then
    return nil, erro
  end

  valido, erro = verificar_workspace(contexto.workspace_manifesto)

  if not valido then
    return nil, erro
  end

  local raiz = contexto.workspace_root

  local destino = vim.fs.normalize(vim.fs.joinpath(raiz, caminho))

  if vim.uv.fs_stat(destino) then
    return nil, "O destino ja existe:\n" .. destino
  end

  -- Verificar a localizacao antes de criar diretorios.
  local ancestral = ancestral_existente(vim.fs.dirname(destino))

  if not ancestral or not dentro_da_raiz(ancestral, raiz) then
    return nil, "O destino esta fora do workspace."
  end

  valido, erro = preparar_destino(destino)

  if not valido then
    return nil, erro
  end

  -- Segunda verificacao: protege contra links simbolicos.
  if not dentro_da_raiz(vim.fs.dirname(destino), raiz) then
    return nil, "O destino esta fora do workspace."
  end

  local manifesto

  manifesto, erro = cargo_new(destino, tipo, raiz)

  if not manifesto then
    return nil, erro
  end

  -- Confirmar que a crate foi registrada no workspace.
  local dados

  dados, erro = cargo_projeto.metadata(contexto.workspace_manifesto)

  if not dados then
    return nil, "Crate criada, mas falhou a verificacao:\n" .. erro
  end

  local pacote_criado = nil

  for _, pacote in ipairs(dados.packages or {}) do
    if vim.fs.normalize(pacote.manifest_path) == vim.fs.normalize(manifesto) then
      pacote_criado = pacote
      break
    end
  end

  local registrado = false

  if pacote_criado then
    for _, membro in ipairs(dados.workspace_members or {}) do
      if membro == pacote_criado.id then
        registrado = true
        break
      end
    end
  end

  if not registrado then
    return nil, "Crate criada, mas nao registrada no workspace:\n" .. manifesto
  end

  return manifesto
end

local function resolver_destino(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil, "Informe o caminho do projeto."
  end

  if caminho:sub(1, 2) == "~/" then
    caminho = vim.fn.expand("~") .. caminho:sub(2)
  elseif caminho:sub(1, 1) ~= "/" then
    caminho = vim.fs.joinpath(vim.fn.getcwd(), caminho)
  end

  return vim.fs.normalize(caminho)
end

local function pai_existente(destino)
  return ancestral_existente(vim.fs.dirname(destino))
end

-- Criar um projeto independente, sem alterar outro workspace.
function M.criar_independente(caminho, tipo)
  local valido, erro = validar_tipo(tipo)

  if not valido then
    return nil, erro
  end

  local destino

  destino, erro = resolver_destino(caminho)

  if not destino then
    return nil, erro
  end

  if vim.uv.fs_stat(destino) then
    return nil, "O destino ja existe:\n" .. destino
  end

  local pai = pai_existente(destino)

  if not pai then
    return nil, "Diretorio pai nao encontrado."
  end

  local manifesto_existente = cargo_projeto.localizar_manifesto(pai)

  if manifesto_existente then
    return nil, "O destino esta dentro de um projeto Cargo.\n" .. "Para adicionar uma crate, use criar_no_workspace."
  end

  valido, erro = preparar_destino(destino)

  if not valido then
    return nil, erro
  end

  return cargo_new(destino, tipo, vim.fs.dirname(destino))
end

return M
