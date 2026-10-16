-- ========================================
-- PYTHON - MENU GLOBAL
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

-- ========================================
-- IDENTIFICAR O PROJETO
-- ========================================

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, marcadores) or vim.fs.dirname(arquivo)
end

-- ========================================
-- IDENTIFICAR O INTERPRETADOR
-- ========================================

local function encontrar_python(raiz)
  local windows = vim.fn.has("win32") == 1

  for _, ambiente in ipairs({ ".venv", "venv" }) do
    local python

    if windows then
      python = vim.fs.joinpath(raiz, ambiente, "Scripts", "python.exe")
    else
      python = vim.fs.joinpath(raiz, ambiente, "bin", "python")
    end

    if vim.fn.executable(python) == 1 then
      return python, ambiente
    end
  end

  for _, comando in ipairs({ "python3", "python" }) do
    local python = vim.fn.exepath(comando)

    if python ~= "" then
      return python, "PATH"
    end
  end

  return nil, nil
end

-- ========================================
-- INFORMACOES DO PROJETO
-- ========================================

local function mostrar_informacoes(arquivo)
  local raiz = encontrar_raiz(arquivo)
  local python, origem = encontrar_python(raiz)

  if not python then
    vim.notify("Python: nenhum interpretador encontrado.", vim.log.levels.ERROR)
    return
  end

  vim.notify(
    table.concat({
      "Arquivo: " .. arquivo,
      "Projeto: " .. raiz,
      "Interpretador: " .. python,
      "Origem: " .. origem,
    }, "\n"),
    vim.log.levels.INFO,
    { title = "Python - Ambiente atual" }
  )
end

-- ========================================
-- MENU INTERATIVO
-- ========================================

function M.abrir()
  local janela = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if vim.bo[buffer].filetype ~= "python" or arquivo == "" then
    vim.notify("PythonMenu: abra um arquivo Python primeiro.", vim.log.levels.WARN)
    return
  end

  local opcoes = {
    {
      nome = "Executar arquivo atual (F6)",
      executar = function()
        require("languages.python.runner").executar(arquivo)
      end,
    },
    {
      nome = "Depurar arquivo atual (F8)",
      executar = function()
        require("dap").continue()
      end,
    },
    {
      nome = "Informacoes do interpretador e projeto",
      executar = function()
        mostrar_informacoes(arquivo)
      end,
    },
  }

  vim.ui.select(opcoes, {
    prompt = "Python - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(janela) then
        vim.notify("PythonMenu: janela original indisponivel.", vim.log.levels.WARN)
        return
      end

      if vim.api.nvim_win_get_buf(janela) ~= buffer then
        vim.notify("PythonMenu: o arquivo original mudou.", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(janela)

      escolha.executar()
    end)
  end)
end

-- ========================================
-- REGISTRAR :PythonMenu
-- ========================================

function M.setup()
  vim.api.nvim_create_user_command("PythonMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos Python",
  })
end

return M
