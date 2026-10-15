local M = {}

local cargo_projeto = require("languages.rust.cargo")
local terminal = require("languages.rust.terminal")

local comandos = {
  check = "check",
  build = "build",
  test = "test",
  clippy = "clippy",
  fmt_check = "fmt",
}

function M.executar(acao, referencia)
  if not comandos[acao] then
    return nil, "Comando Cargo desconhecido: " .. tostring(acao)
  end

  -- Identificar a crate pelo arquivo atual.
  local contexto, erro = cargo_projeto.contexto(referencia)

  if not contexto then
    return nil, erro
  end

  local cargo = vim.fn.exepath("cargo")

  if cargo == "" then
    return nil, "Cargo nao encontrado no PATH."
  end

  local argumentos = {
    cargo,
    comandos[acao],
    "--manifest-path",
    contexto.manifesto,
  }

  -- Quando o manifesto for virtual, operar
  -- explicitamente sobre os membros do workspace.
  if not contexto.pacote then
    table.insert(argumentos, "--workspace")
  end

  -- Verificar formatacao sem alterar os arquivos.
  if acao == "fmt_check" then
    table.insert(argumentos, "--")
    table.insert(argumentos, "--check")
  end

  -- Evitar executar verificacoes sobre alteracoes
  -- do arquivo atual que ainda nao foram salvas.
  local arquivo = referencia or vim.api.nvim_buf_get_name(0)

  local buffer = vim.fn.bufnr(arquivo)

  if buffer > 0 and vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].modified then
    return nil, "Salve o arquivo com :w antes de executar Cargo."
  end

  return terminal.executar(argumentos, contexto.diretorio)
end

return M
