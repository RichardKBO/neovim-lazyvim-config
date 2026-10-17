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


-- ========================================
-- DEPURACAO HTTP - XDEBUG
-- ========================================

function M.escutar_http()
  local dap = require("dap")

  dap.run({
    name = "PHP: aguardar Xdebug HTTP",
    type = "php",
    request = "launch",
    hostname = "127.0.0.1",
    port = 9003,
    stopOnEntry = false,
  })
end

-- ========================================
-- DEPURACAO INTELIGENTE - CLI / HTTP
-- ========================================

function M.depurar(arquivo)
  local dap = require("dap")

  -- Continuar uma sessao ja existente.
  if dap.session() then
    dap.continue()
    return
  end

  if type(arquivo) ~= "string" or arquivo == "" then
    vim.notify(
      "PHP: nenhum arquivo aberto para depurar.",
      vim.log.levels.WARN
    )
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")
  local diretorio = vim.fs.dirname(arquivo)

  -- Entrada de aplicacao PHP web.
  if vim.fs.basename(arquivo) == "index.php"
      and vim.fs.basename(diretorio) == "public" then
    M.escutar_http()
    return
  end

  -- Arquivos PHP executados pelo terminal.
  dap.continue()
end

return M
