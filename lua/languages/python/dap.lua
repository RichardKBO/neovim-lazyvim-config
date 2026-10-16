-- ========================================
-- PYTHON - DEPURADOR GLOBAL
-- nvim-dap + debugpy (Mason)
-- ========================================

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

-- Identificar a raiz do projeto pelo arquivo atual.
local function encontrar_raiz(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.getcwd()
  end

  return vim.fs.root(arquivo, marcadores) or vim.fs.dirname(arquivo)
end

-- Encontrar o Python que executara o projeto.
local function encontrar_python_projeto(arquivo)
  local raiz = encontrar_raiz(arquivo)
  local windows = vim.fn.has("win32") == 1

  for _, ambiente in ipairs({ ".venv", "venv" }) do
    local python

    if windows then
      python = vim.fs.joinpath(raiz, ambiente, "Scripts", "python.exe")
    else
      python = vim.fs.joinpath(raiz, ambiente, "bin", "python")
    end

    if vim.fn.executable(python) == 1 then
      return python
    end
  end

  -- Respeitar o PATH, incluindo mise e outros gerenciadores.
  for _, comando in ipairs({ "python3", "python" }) do
    local python = vim.fn.exepath(comando)

    if python ~= "" then
      return python
    end
  end

  vim.notify("Nenhum interpretador Python encontrado.", vim.log.levels.ERROR)

  return "python3"
end

-- Localizar o Python do debugpy instalado pelo Mason.
local function encontrar_python_mason()
  local base = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "debugpy", "venv")

  local python

  if vim.fn.has("win32") == 1 then
    python = vim.fs.joinpath(base, "Scripts", "python.exe")
  else
    python = vim.fs.joinpath(base, "bin", "python")
  end

  if vim.fn.executable(python) == 1 then
    return python
  end

  return nil
end

-- Registrar o adaptador e as configuracoes de depuracao.
function M.setup()
  local dap = require("dap")

  -- Adaptador centralizado: nao depende da .venv do projeto.
  dap.adapters.python = function(callback, _)
    local python_mason = encontrar_python_mason()

    if not python_mason then
      vim.notify("debugpy do Mason nao encontrado. Instale com :MasonInstall debugpy", vim.log.levels.ERROR)
      return
    end

    callback({
      type = "executable",
      command = python_mason,
      args = {
        "-Xfrozen_modules=off",
        "-m",
        "debugpy.adapter",
      },
      options = {
        source_filetype = "python",
      },
    })
  end

  -- Depurar o arquivo Python atualmente aberto.
  dap.configurations.python = {
    {
      name = "Python: depurar arquivo atual",
      type = "python",
      request = "launch",

      program = "${file}",

      -- Interpretador do projeto, separado do adaptador.
      pythonPath = function()
        local arquivo = vim.api.nvim_buf_get_name(0)
        return encontrar_python_projeto(arquivo)
      end,

      -- Executar na raiz identificada do projeto.
      cwd = function()
        local arquivo = vim.api.nvim_buf_get_name(0)
        return encontrar_raiz(arquivo)
      end,

      console = "integratedTerminal",
      justMyCode = true,
    },
  }
end

return M
