-- Debugger Ruby modularizado
-- Utiliza nvim-dap + rdbg
-- Ruby gerenciado pelo mise

local M = {}

function M.setup()
  local dap = require("dap")

  -- Adaptador Ruby
  dap.adapters.ruby = function(callback, config)
    local rdbg = vim.fn.exepath("rdbg")
    local ruby = vim.fn.exepath("ruby")

    if rdbg == "" then
      vim.notify("Debugger rdbg nao encontrado no PATH.", vim.log.levels.ERROR)
      return
    end

    if ruby == "" then
      vim.notify("Executavel Ruby nao encontrado.", vim.log.levels.ERROR)
      return
    end

    callback({
      type = "server",
      host = "127.0.0.1",
      port = "${port}",

      executable = {
        command = rdbg,

        args = {
          "--open",
          "--port",
          "${port}",
          "-c",
          "--",
          ruby,
          config.script,
        },
      },
    })
  end

  -- Configuracao de depuracao Ruby
  dap.configurations.ruby = {
    {
      name = "Ruby: depurar arquivo atual",
      type = "ruby",
      request = "attach",
      localfs = true,
      script = "${file}",
    },
  }
end

return M
