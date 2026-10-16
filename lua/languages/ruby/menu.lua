-- ========================================
-- RUBY - MENU GLOBAL
-- Ruby + Bundler + nvim-dap
-- ========================================

local M = {}

-- ========================================
-- IDENTIFICAR O PROJETO
-- ========================================

local function encontrar_projeto(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

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

-- ========================================
-- INFORMACOES DO AMBIENTE
-- ========================================

local function mostrar_informacoes(arquivo)
  local raiz, gemfile = encontrar_projeto(arquivo)

  local ruby = vim.fn.exepath("ruby")
  local bundle = vim.fn.exepath("bundle")

  vim.notify(
    table.concat({
      "Arquivo: " .. arquivo,
      "Projeto: " .. raiz,
      "Ruby: " .. (ruby ~= "" and ruby or "Nao encontrado"),
      "Bundler: " .. (bundle ~= "" and bundle or "Nao encontrado"),
      "Gemfile: " .. (gemfile or "Nao encontrado"),
    }, "\n"),
    vim.log.levels.INFO,
    { title = "Ruby - Ambiente atual" }
  )
end

-- ========================================
-- VERIFICAR DEPENDENCIAS BUNDLER
-- ========================================

local function verificar_bundler(arquivo)
  local raiz, gemfile = encontrar_projeto(arquivo)

  if not gemfile then
    vim.notify("Ruby: projeto sem Gemfile.", vim.log.levels.WARN)
    return
  end

  local bundle = vim.fn.exepath("bundle")

  if bundle == "" then
    vim.notify("Ruby: Bundler nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  vim.system({
    bundle,
    "check",
  }, {
    cwd = raiz,
    env = {
      BUNDLE_GEMFILE = gemfile,
    },
    text = true,
  }, function(resultado)
    vim.schedule(function()
      local saida = vim.trim((resultado.stdout or "") .. "\n" .. (resultado.stderr or ""))

      if resultado.code == 0 then
        vim.notify("Dependencias satisfeitas.\n" .. saida, vim.log.levels.INFO, { title = "Ruby - Bundler" })
      else
        vim.notify("Problema nas dependencias.\n" .. saida, vim.log.levels.ERROR, { title = "Ruby - Bundler" })
      end
    end)
  end)
end

-- ========================================
-- MENU INTERATIVO
-- ========================================

function M.abrir()
  local janela = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if vim.bo[buffer].filetype ~= "ruby" or arquivo == "" then
    vim.notify("RubyMenu: abra um arquivo Ruby primeiro.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  local opcoes = {
    -- ====================================
    -- PROJETO E ESTRUTURA
    -- ====================================
    {
      nome = "Criar novo projeto Ruby (Simples / Bundler)",
      executar = function()
        require("languages.ruby.projects").criar()
      end,
    },
    {
      nome = "Novo elemento Ruby (Classe, Modulo, Arquivo)",
      executar = function()
        require("languages.ruby.types").criar(arquivo)
      end,
    },

    -- ====================================
    -- EXECUCAO E DEPURACAO
    -- ====================================
    {
      nome = "Executar arquivo atual (F6)",
      executar = function()
        require("languages.ruby.runner").executar(arquivo)
      end,
    },
    {
      nome = "Depurar arquivo atual (F8)",
      executar = function()
        require("dap").continue()
      end,
    },

    -- ====================================
    -- INFORMACOES DO PROJETO
    -- ====================================
    {
      nome = "Informacoes do Ruby e projeto",
      executar = function()
        mostrar_informacoes(arquivo)
      end,
    },

    -- ====================================
    -- BUNDLER
    -- ====================================
    {
      nome = "Verificar dependencias Bundler",
      executar = function()
        verificar_bundler(arquivo)
      end,
    },
  }

  vim.ui.select(opcoes, {
    prompt = "Ruby - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(janela) then
        vim.notify("RubyMenu: janela original indisponivel.", vim.log.levels.WARN)
        return
      end

      if vim.api.nvim_win_get_buf(janela) ~= buffer then
        vim.notify("RubyMenu: o arquivo original mudou.", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(janela)

      escolha.executar()
    end)
  end)
end

-- ========================================
-- REGISTRAR :RubyMenu
-- ========================================

function M.setup()
  vim.api.nvim_create_user_command("RubyMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos Ruby",
  })
end

return M
