local M = {}

local cargo = require("languages.rust.cargo")

local palavras_reservadas = {
  ["as"] = true,
  ["async"] = true,
  ["await"] = true,
  ["break"] = true,
  ["const"] = true,
  ["continue"] = true,
  ["crate"] = true,
  ["dyn"] = true,
  ["else"] = true,
  ["enum"] = true,
  ["extern"] = true,
  ["false"] = true,
  ["fn"] = true,
  ["for"] = true,
  ["if"] = true,
  ["impl"] = true,
  ["in"] = true,
  ["let"] = true,
  ["loop"] = true,
  ["match"] = true,
  ["mod"] = true,
  ["move"] = true,
  ["mut"] = true,
  ["pub"] = true,
  ["ref"] = true,
  ["return"] = true,
  ["self"] = true,
  ["Self"] = true,
  ["static"] = true,
  ["struct"] = true,
  ["super"] = true,
  ["trait"] = true,
  ["true"] = true,
  ["type"] = true,
  ["unsafe"] = true,
  ["use"] = true,
  ["where"] = true,
  ["while"] = true,
  ["abstract"] = true,
  ["become"] = true,
  ["box"] = true,
  ["do"] = true,
  ["final"] = true,
  ["gen"] = true,
  ["macro"] = true,
  ["override"] = true,
  ["priv"] = true,
  ["try"] = true,
  ["typeof"] = true,
  ["unsized"] = true,
  ["virtual"] = true,
  ["yield"] = true,
}

local function validar_nome(nome)
  if type(nome) ~= "string" or not nome:match("^[a-zA-Z_][a-zA-Z0-9_]*$") or nome == "_" then
    return nil, "Nome de modulo Rust invalido."
  end

  if palavras_reservadas[nome] then
    return nil, "Palavra reservada do Rust: " .. nome
  end

  return true
end

local function dentro_do_projeto(caminho, raiz)
  local real = vim.uv.fs_realpath(caminho)
  local raiz_real = vim.uv.fs_realpath(raiz)

  if not real or not raiz_real then
    return false
  end

  return real == raiz_real or vim.startswith(real, raiz_real .. "/")
end

-- Descobrir onde ficam os filhos de um modulo.
local function diretorio_dos_filhos(arquivo, pacote)
  local nome = vim.fs.basename(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  -- Raizes de targets: main.rs, lib.rs,
  -- src/bin/..., examples/... e tests/...
  for _, target in ipairs(pacote.targets or {}) do
    if vim.fs.normalize(target.src_path) == vim.fs.normalize(arquivo) then
      return diretorio
    end
  end

  -- Para arquivos mod.rs, os filhos sao irmaos.
  if nome == "mod.rs" then
    return diretorio
  end

  -- Para produto.rs, os filhos ficam em produto/.
  local nome_sem_extensao = nome:gsub("%.rs$", "")

  return vim.fs.joinpath(diretorio, nome_sem_extensao)
end

-- Evitar registrar duas vezes o mesmo modulo.
local function ja_declarado(buffer, nome)
  local linhas = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)

  local padrao = "%f[%a]mod%s+" .. nome .. "%f[^%w_]"

  for _, linha in ipairs(linhas) do
    if not linha:match("^%s*//") and linha:find(padrao) then
      return true
    end
  end

  return false
end

-- Criar um modulo Rust vinculado ao arquivo pai.
--
-- formato: "arquivo" ou "pasta"
-- referencia: arquivo .rs pai, opcional
function M.criar(nome, formato, referencia)
  local valido, erro = validar_nome(nome)

  if not valido then
    return nil, erro
  end

  if formato ~= "arquivo" and formato ~= "pasta" then
    return nil, "Formato deve ser 'arquivo' ou 'pasta'."
  end

  local arquivo = referencia or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    return nil, "Abra um arquivo Rust primeiro."
  end

  arquivo = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  if not arquivo:match("%.rs$") or vim.fn.filereadable(arquivo) ~= 1 then
    return nil, "O arquivo pai precisa ser um .rs salvo."
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer < 1 or not vim.api.nvim_buf_is_loaded(buffer) then
    return nil, "Abra o arquivo pai no Neovim."
  end

  if vim.bo[buffer].modified then
    return nil, "Salve o arquivo pai antes de criar o modulo."
  end

  if not vim.bo[buffer].modifiable or vim.bo[buffer].readonly then
    return nil, "O arquivo pai nao permite alteracoes."
  end

  local contexto

  contexto, erro = cargo.contexto(arquivo)

  if not contexto then
    return nil, erro
  end

  if not contexto.pacote then
    return nil, "Nenhuma crate encontrada para este arquivo."
  end

  if not dentro_do_projeto(arquivo, contexto.diretorio) then
    return nil, "O arquivo esta fora do diretorio da crate."
  end

  if ja_declarado(buffer, nome) then
    return nil, "O modulo ja esta declarado: " .. nome
  end

  local base = diretorio_dos_filhos(arquivo, contexto.pacote)

  -- Conferir a localizacao real antes de criar pastas.
  local ancestral = base

  while not vim.uv.fs_stat(ancestral) do
    local anterior = vim.fs.dirname(ancestral)

    if anterior == ancestral then
      return nil, "Diretorio pai invalido."
    end

    ancestral = anterior
  end

  if not dentro_do_projeto(ancestral, contexto.diretorio) then
    return nil, "O destino sairia da crate."
  end

  local caminho_arquivo = vim.fs.joinpath(base, nome .. ".rs")

  local caminho_pasta = vim.fs.joinpath(base, nome)

  -- Recusar nomes existentes ou estruturas ambiguas.
  if vim.uv.fs_stat(caminho_arquivo) or vim.uv.fs_stat(caminho_pasta) then
    return nil, "Ja existe um modulo ou pasta com esse nome."
  end

  local destino

  if formato == "pasta" then
    destino = vim.fs.joinpath(caminho_pasta, "mod.rs")
  else
    destino = caminho_arquivo
  end

  local diretorio_destino = vim.fs.dirname(destino)

  if vim.fn.mkdir(diretorio_destino, "p") == 0 and vim.fn.isdirectory(diretorio_destino) ~= 1 then
    return nil, "Nao foi possivel criar o diretorio."
  end

  local sucesso, resultado = pcall(vim.fn.writefile, { "// Modulo " .. nome }, destino)

  if not sucesso or resultado ~= 0 then
    return nil, "Nao foi possivel criar: " .. destino
  end

  -- Registrar a declaracao no proprio buffer pai.
  vim.api.nvim_buf_set_lines(buffer, -1, -1, false, {
    "",
    "mod " .. nome .. ";",
  })

  -- Salvar o arquivo pai para que o Cargo reconheca
  -- imediatamente o novo modulo.
  local gravou, erro_gravacao = pcall(function()
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd("write")
    end)
  end)

  if not gravou then
    return nil,
      "Modulo criado, mas nao foi possivel salvar " .. "a declaracao no arquivo pai:\n" .. tostring(erro_gravacao)
  end

  return destino
end

return M
