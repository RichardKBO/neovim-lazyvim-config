local M = {}

local cargo_projeto = require("languages.rust.cargo")

-- Evita duas alteracoes simultaneas no mesmo manifesto.
local operacoes_ativas = {}

local function validar_nome(nome)
  if type(nome) ~= "string" or not nome:match("^[%a_][%w_%-]*$") then
    return nil, "Nome de dependencia invalido."
  end

  return true
end

local function validar_tipo(tipo)
  tipo = tipo or "normal"

  if tipo ~= "normal" and tipo ~= "dev" and tipo ~= "build" then
    return nil, "Tipo de dependencia invalido."
  end

  return tipo
end

local function contexto_editavel(referencia)
  local contexto, erro = cargo_projeto.contexto(referencia)

  if not contexto then
    return nil, erro
  end

  if not contexto.pacote then
    return nil, "Abra um arquivo de uma crate. " .. "O manifesto atual e de um workspace virtual."
  end

  local buffer = vim.fn.bufnr(contexto.manifesto)

  if buffer > 0 and vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].modified then
    return nil, "Salve o Cargo.toml antes de alterar dependencias."
  end

  return contexto
end

local function adicionar_tipo(argumentos, tipo)
  if tipo == "dev" then
    table.insert(argumentos, "--dev")
  elseif tipo == "build" then
    table.insert(argumentos, "--build")
  end
end

local function executar(contexto, acao, argumentos, simular)
  local manifesto = contexto.manifesto

  if operacoes_ativas[manifesto] then
    return nil, "Ja existe uma operacao Cargo em andamento nesta crate."
  end

  local executavel = vim.fn.exepath("cargo")

  if executavel == "" then
    return nil, "Cargo nao encontrado no PATH."
  end

  local comando = {
    executavel,
    acao,
  }

  vim.list_extend(comando, argumentos)

  table.insert(comando, "--manifest-path")
  table.insert(comando, manifesto)

  if simular then
    table.insert(comando, "--dry-run")
  end

  operacoes_ativas[manifesto] = true

  local sucesso, erro = pcall(vim.system, comando, {
    cwd = contexto.diretorio,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      operacoes_ativas[manifesto] = nil

      local saida = vim.trim((resultado.stderr or "") .. "\n" .. (resultado.stdout or ""))

      if resultado.code ~= 0 then
        vim.notify("Rust Cargo: operacao falhou.\n" .. saida, vim.log.levels.ERROR)
        return
      end

      if not simular then
        -- Recarregar manifests abertos quando Cargo
        -- modifica os arquivos externamente.
        local buffer = vim.fn.bufnr(manifesto)

        if buffer > 0 and vim.api.nvim_buf_is_loaded(buffer) and not vim.bo[buffer].modified then
          vim.api.nvim_buf_call(buffer, function()
            vim.cmd("checktime")
          end)
        end
      end

      local titulo = simular and "Simulacao concluida" or "Dependencias atualizadas"

      vim.notify("Rust Cargo: " .. titulo .. ".\n" .. saida, vim.log.levels.INFO)
    end)
  end)

  if not sucesso then
    operacoes_ativas[manifesto] = nil
    return nil, tostring(erro)
  end

  vim.notify("Rust Cargo: executando " .. acao .. "...")

  return true
end

-- Adicionar dependencia do crates.io.
-- Exemplo: adicionar("serde", "1", "normal", nil, true)
function M.adicionar(nome, versao, tipo, referencia, simular)
  local valido, erro = validar_nome(nome)

  if not valido then
    return nil, erro
  end

  tipo, erro = validar_tipo(tipo)

  if not tipo then
    return nil, erro
  end

  if versao ~= nil and type(versao) ~= "string" then
    return nil, "Versao invalida."
  end

  versao = vim.trim(versao or "")

  if versao:find("%s") then
    return nil, "A versao nao pode conter espacos."
  end

  local contexto
  contexto, erro = contexto_editavel(referencia)

  if not contexto then
    return nil, erro
  end

  local dependencia = nome

  if versao ~= "" then
    dependencia = nome .. "@" .. versao
  end

  local argumentos = { dependencia }

  adicionar_tipo(argumentos, tipo)

  return executar(contexto, "add", argumentos, simular == true)
end

-- Adicionar biblioteca local por caminho.
-- Caminhos relativos partem do diretorio da crate.
function M.adicionar_local(caminho, tipo, referencia, simular)
  if type(caminho) ~= "string" or vim.trim(caminho) == "" then
    return nil, "Informe o caminho da biblioteca."
  end

  local contexto, erro = contexto_editavel(referencia)

  if not contexto then
    return nil, erro
  end

  tipo, erro = validar_tipo(tipo)

  if not tipo then
    return nil, erro
  end

  caminho = vim.trim(caminho)

  if caminho:sub(1, 2) == "~/" then
    caminho = vim.fn.expand("~") .. caminho:sub(2)
  elseif not vim.startswith(caminho, "/") then
    caminho = vim.fs.joinpath(contexto.diretorio, caminho)
  end

  local destino = vim.uv.fs_realpath(caminho)

  if not destino or vim.fn.isdirectory(destino) ~= 1 then
    return nil, "Diretorio da biblioteca nao encontrado."
  end

  if vim.fn.filereadable(vim.fs.joinpath(destino, "Cargo.toml")) ~= 1 then
    return nil, "A biblioteca nao possui Cargo.toml."
  end

  if destino == vim.uv.fs_realpath(contexto.diretorio) then
    return nil, "Uma crate nao pode depender de si mesma."
  end

  local argumentos = {
    "--path",
    destino,
  }

  adicionar_tipo(argumentos, tipo)

  return executar(contexto, "add", argumentos, simular == true)
end

-- Remover dependencia existente da crate.
function M.remover(nome, tipo, referencia)
  local valido, erro = validar_nome(nome)

  if not valido then
    return nil, erro
  end

  tipo, erro = validar_tipo(tipo)

  if not tipo then
    return nil, erro
  end

  local contexto
  contexto, erro = contexto_editavel(referencia)

  if not contexto then
    return nil, erro
  end

  local argumentos = { nome }

  adicionar_tipo(argumentos, tipo)

  return executar(contexto, "rm", argumentos, false)
end

return M
