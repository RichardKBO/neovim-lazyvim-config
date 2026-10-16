-- ========================================
-- RUBY - DEBUGGER GLOBAL F8
-- nvim-dap + rdbg
-- Ruby gerenciado pelo mise/PATH
-- ========================================

local M = {}

-- Localizar a raiz do projeto a partir do arquivo atual.
local function encontrar_raiz(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  -- Priorizar projetos com Gemfile.
  local gemfiles = vim.fs.find({
    "Gemfile",
    "gems.rb",
  }, {
    path = diretorio,
    upward = true,
  })

  if #gemfiles > 0 then
    return vim.fs.dirname(gemfiles[1])
  end

  -- Outros marcadores de projetos Ruby.
  local raiz = vim.fs.root(arquivo, {
    "Rakefile",
    ".ruby-version",
    ".tool-versions",
    ".mise.toml",
    "mise.toml",
    ".git",
  })

  return raiz or diretorio
end

function M.setup()
  local dap = require("dap")

  -- Adaptador Ruby contextual.
  dap.adapters.ruby = function(callback, config)
    local rdbg = vim.fn.exepath("rdbg")
    local ruby = vim.fn.exepath("ruby")

    if rdbg == "" then
      vim.notify("Debugger rdbg nao encontrado no PATH.", vim.log.levels.ERROR)
      return
    end

    if ruby == "" then
      vim.notify("Executavel Ruby nao encontrado no PATH.", vim.log.levels.ERROR)
      return
    end

    -- Arquivo recebido da configuracao DAP.
    local arquivo = config.script

    if type(arquivo) ~= "string" or arquivo == "" then
      vim.notify("Nenhum arquivo Ruby definido para depuracao.", vim.log.levels.ERROR)
      return
    end

    arquivo = vim.fn.fnamemodify(arquivo, ":p")

    -- Identificar a raiz independentemente do :pwd.
    local raiz = encontrar_raiz(arquivo)

    -- Preservar o comando original do rdbg.
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
          arquivo,
        },

        -- Executar no contexto do projeto atual.
        cwd = raiz,
      },
    })
  end

  -- Configuracao de depuracao Ruby.
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
