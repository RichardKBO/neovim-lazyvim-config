-- ========================================
-- PHP - DEBUGGER GLOBAL F8
-- nvim-dap + PHP Debug Adapter + Xdebug
-- ========================================

local M = {}

local function encontrar_raiz()
  local arquivo = vim.api.nvim_buf_get_name(0)

  return vim.fs.root(arquivo, {
    "composer.json",
    ".git",
  }) or vim.fs.dirname(arquivo)
end

function M.setup()
  local dap = require("dap")
  local adaptador = vim.fn.exepath("php-debug-adapter")

  if adaptador == "" then
    vim.notify(
      "PHP Debug Adapter nao encontrado no PATH.",
      vim.log.levels.ERROR
    )
    return
  end

  dap.adapters.php = {
    type = "executable",
    command = adaptador,
  }

  dap.configurations.php = {
    {
      name = "PHP: depurar arquivo atual",
      type = "php",
      request = "launch",

      program = "${file}",
      cwd = encontrar_raiz,

      runtimeExecutable = "php",
      runtimeArgs = {
        "-d",
        "xdebug.start_with_request=yes",
      },

      port = 0,
      stopOnEntry = false,

      env = {
        XDEBUG_MODE = "debug",
        XDEBUG_CONFIG = "client_host=127.0.0.1 client_port=${port}",
      },
    },
  }
end

return M
