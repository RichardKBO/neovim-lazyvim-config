-- ========================================
-- RUBY - DEBUGGER GLOBAL F8
-- nvim-dap + rdbg + Bundler
-- Ruby gerenciado pelo mise/PATH
-- ========================================

local M = {}

-- Localizar a raiz do projeto a partir do arquivo atual.
local function encontrar_projeto(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  -- Priorizar projetos que possuem Gemfile.
  local gemfiles = vim.fs.find({
    "Gemfile",
    "gems.rb",
  }, {
    path = diretorio,
    upward = true,
  })

  if #gemfiles > 0 then
    return vim.fs.dirname(gemfiles[1]), gemfiles[1]
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

  return raiz or diretorio, nil
end

-- Verificar se rdbg esta disponivel no Bundler do projeto.
local function verificar_rdbg_bundler(raiz)
  local sucesso, resultado = pcall(function()
    return vim
      .system({
        "bundle",
        "exec",
        "rdbg",
        "--version",
      }, {
        cwd = raiz,
        text = true,
      })
      :wait(10000)
  end)

  return sucesso and resultado ~= nil and resultado.code == 0
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

    local arquivo = config.script

    if type(arquivo) ~= "string" or arquivo == "" then
      vim.notify("Nenhum arquivo Ruby definido para depuracao.", vim.log.levels.ERROR)
      return
    end

    arquivo = vim.fn.fnamemodify(arquivo, ":p")

    if vim.fn.filereadable(arquivo) ~= 1 then
      vim.notify("Arquivo Ruby nao encontrado.", vim.log.levels.ERROR)
      return
    end

    -- Descobrir o contexto do arquivo atual.
    local raiz, gemfile = encontrar_projeto(arquivo)

    -- Preservar o depurador externo como padrao.
    local comando = rdbg

    local argumentos = {
      "--open",
      "--port",
      "${port}",
      "-c",
      "--",
      ruby,
      arquivo,
    }

    if gemfile then
      local bundle = vim.fn.exepath("bundle")

      if bundle ~= "" and verificar_rdbg_bundler(raiz) then
        -- O projeto disponibiliza seu proprio rdbg.
        -- Executar o depurador no ambiente Bundler.
        comando = bundle

        argumentos = {
          "exec",
          "rdbg",
          "--open",
          "--port",
          "${port}",
          "-c",
          "--",
          ruby,
          arquivo,
        }
      else
        -- Preservar a depuracao basica.
        -- As gems isoladas do projeto podem nao estar acessiveis.
        vim.notify(
          "rdbg indisponivel no bundle. F8 usara o depurador externo sem ativar as dependencias do Gemfile.",
          vim.log.levels.WARN
        )
      end
    end

    callback({
      type = "server",
      host = "127.0.0.1",
      port = "${port}",

      executable = {
        command = comando,
        args = argumentos,

        -- Identificar a raiz independentemente do :pwd.
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
