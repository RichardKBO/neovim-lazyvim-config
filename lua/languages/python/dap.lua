-- Debugger Python modularizado
-- Utiliza nvim-dap + debugpy
-- Prioriza o .venv do projeto

local M = {}

-- Encontrar o Python do ambiente virtual mais proximo.
local function localizar_python(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.exepath("python3")
  end

  local diretorio = vim.fn.fnamemodify(arquivo, ":p:h")

  while diretorio and diretorio ~= "" do
    local candidato = diretorio .. "/.venv/bin/python"

    if vim.fn.executable(candidato) == 1 then
      return candidato
    end

    local diretorio_pai = vim.fn.fnamemodify(diretorio, ":h")

    if diretorio_pai == diretorio then
      break
    end

    diretorio = diretorio_pai
  end

  -- Utilizar o Python global caso nao exista .venv.
  return vim.fn.exepath("python3")
end

-- Configurar o debugger Python.
function M.setup()
  local dap = require("dap")

  -- Adaptador debugpy.
  dap.adapters.python = function(callback, config)
    local arquivo = vim.fn.expand("%:p")

    if type(config.program) == "string" and config.program ~= "" and not config.program:find("${", 1, true) then
      arquivo = config.program
    end

    local python = localizar_python(arquivo)

    if not python or python == "" then
      vim.notify("Executavel Python nao encontrado.", vim.log.levels.ERROR)
      return
    end

    callback({
      type = "executable",
      command = python,

      args = {
        "-Xfrozen_modules=off",
        "-m",
        "debugpy.adapter",
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

      pythonPath = function()
        local arquivo = vim.fn.expand("%:p")
        return localizar_python(arquivo)
      end,

      console = "integratedTerminal",
      justMyCode = true,
    },
  }
end

return M
