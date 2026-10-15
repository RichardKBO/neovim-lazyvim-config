local M = {}

-- ========================================
-- MODULOS GO
-- ========================================

local projetos = require("languages.go.projects")
local runner = require("languages.go.runner")
local debugger = require("languages.go.debugger")

-- ========================================
-- UTILITARIOS
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

-- Identificar o diretorio do arquivo.
local function diretorio_atual(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.getcwd()
  end

  local caminho = normalizar(arquivo)

  if vim.fn.isdirectory(caminho) == 1 then
    return caminho
  end

  return vim.fs.dirname(caminho)
end

-- ========================================
-- DETECTAR RAIZ DO MODULO
-- ========================================

function M.raiz_modulo(arquivo)
  local diretorio = diretorio_atual(arquivo)

  local encontrados = vim.fs.find("go.mod", {
    path = diretorio,
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return vim.fs.dirname(encontrados[1])
end

-- ========================================
-- TERMINAL DE COMANDOS GO
-- ========================================

local function executar_terminal(argumentos, diretorio)
  if vim.fn.executable("go") ~= 1 then
    avisar("Go: comando go nao encontrado.", vim.log.levels.ERROR)
    return
  end

  if not diretorio or vim.fn.isdirectory(diretorio) ~= 1 then
    avisar("Go: diretorio do modulo indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- Abrir terminal integrado.
  vim.cmd("botright 12new")

  local processo = vim.fn.termopen(argumentos, {
    cwd = diretorio,
  })

  if processo <= 0 then
    avisar("Go: nao foi possivel iniciar o comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

-- ========================================
-- COMPILAR MODULO
-- ========================================

local function compilar_modulo(raiz)
  avisar("Go: compilando modulo em " .. raiz)

  executar_terminal({
    "go",
    "build",
    "./...",
  }, raiz)
end

-- ========================================
-- TESTAR MODULO
-- ========================================

local function testar_modulo(raiz)
  avisar("Go: executando testes em " .. raiz)

  executar_terminal({
    "go",
    "test",
    "./...",
  }, raiz)
end

-- ========================================
-- MENU INTERATIVO
-- ========================================

function M.abrir()
  -- Capturar o arquivo antes de abrir
  -- a janela de selecao.
  local arquivo = vim.api.nvim_buf_get_name(0)

  local extensao = ""

  if arquivo ~= "" then
    extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()
  end

  local raiz = M.raiz_modulo(arquivo)

  local opcoes = {
    {
      nome = "Criar novo projeto Go",
      executar = function()
        projetos.criar()
      end,
    },
  }

  -- Operacoes relativas ao arquivo Go.
  if extensao == "go" then
    table.insert(opcoes, {
      nome = "Executar programa/pacote (F6)",
      executar = function()
        runner.executar(arquivo)
      end,
    })

    table.insert(opcoes, {
      nome = "Depurar programa/pacote (F8)",
      executar = function()
        debugger.depurar(arquivo)
      end,
    })
  end

  -- Operacoes relativas ao modulo Go.
  if raiz then
    table.insert(opcoes, {
      nome = "Compilar modulo (go build ./...)",
      executar = function()
        compilar_modulo(raiz)
      end,
    })

    table.insert(opcoes, {
      nome = "Testar modulo (go test ./...)",
      executar = function()
        testar_modulo(raiz)
      end,
    })
  end

  vim.ui.select(opcoes, {
    prompt = "Go - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      escolha.executar()
    end
  end)
end

-- ========================================
-- REGISTRAR :GoMenu
-- ========================================

function M.setup()
  vim.api.nvim_create_user_command("GoMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos Go",
  })
end

return M
