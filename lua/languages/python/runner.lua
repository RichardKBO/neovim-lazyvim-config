local M = {}

local marcadores = {
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Pipfile",
  "poetry.lock",
  "uv.lock",
  ".git",
  ".venv",
  "venv",
}

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, marcadores) or vim.fs.dirname(arquivo)
end

local function encontrar_interpretador(raiz)
  local ambientes = {
    ".venv",
    "venv",
  }

  local windows = vim.fn.has("win32") == 1

  for _, ambiente in ipairs(ambientes) do
    local interpretador

    if windows then
      interpretador = vim.fs.joinpath(raiz, ambiente, "Scripts", "python.exe")
    else
      interpretador = vim.fs.joinpath(raiz, ambiente, "bin", "python")
    end

    if vim.fn.executable(interpretador) == 1 then
      return interpretador
    end
  end

  local python3 = vim.fn.exepath("python3")

  if python3 ~= "" then
    return python3
  end

  local python = vim.fn.exepath("python")

  if python ~= "" then
    return python
  end

  return nil
end

function M.executar(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    vim.notify("Nenhum arquivo Python aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    vim.notify("Arquivo Python não encontrado. Salve o arquivo antes de executar.", vim.log.levels.WARN)
    return
  end

  -- Impedir a execucao de uma versao antiga do arquivo.
  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    vim.notify(
      "Python: salve o arquivo com :w antes de executar.",
      vim.log.levels.WARN
    )
    return
  end

  local raiz = encontrar_raiz(arquivo)
  local interpretador = encontrar_interpretador(raiz)

  if not interpretador then
    vim.notify("Nenhum interpretador Python encontrado.", vim.log.levels.ERROR)
    return
  end

  vim.notify("Python: " .. interpretador .. "\nProjeto: " .. raiz, vim.log.levels.INFO)

  vim.cmd("botright new")

  local sucesso, job = pcall(vim.fn.termopen, { interpretador, arquivo }, { cwd = raiz })

  if not sucesso or job <= 0 then
    vim.cmd("close")

    vim.notify("Falha ao iniciar o terminal Python.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
