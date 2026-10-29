local M = {}

-- ========================================
-- MODULOS GO
-- ========================================

local projetos = require("languages.go.projects")
local runner = require("languages.go.runner")
local debugger = require("languages.go.debugger")
local dependencias = require("languages.go.dependencies")
local informacoes = require("languages.go.info")

-- ========================================
-- UTILITARIOS
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

-- ========================================
-- IDENTIFICAR DIRETORIO
-- ========================================

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
-- ANALISAR PACOTE COM GOLANGCI-LINT
-- ========================================

local function analisar_pacote(buffer)
  -- Garantir que o buffer original
  -- ainda existe e esta carregado.
  if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
    avisar("Go: buffer original indisponivel.", vim.log.levels.WARN)
    return
  end

  if vim.bo[buffer].filetype ~= "go" then
    avisar("Go: o buffer original nao e Go.", vim.log.levels.WARN)
    return
  end

  -- Evitar analisar alteracoes nao salvas.
  if vim.bo[buffer].modified then
    avisar("Go: salve o arquivo antes de executar o lint.", vim.log.levels.WARN)
    return
  end

  -- Reutilizar a configuracao contextual
  -- existente em plugins/go-lint.lua.
  local ok, erro = pcall(function()
    vim.api.nvim_buf_call(buffer, function()
      require("lint").try_lint("golangcilint")
    end)
  end)

  if not ok then
    avisar("Go: falha ao solicitar lint: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  -- A analise e assincrona.
  -- Esta mensagem nao indica sucesso final.
  avisar("Go: analise do pacote solicitada.")
end

-- ========================================
-- MENU INTERATIVO
-- ========================================

function M.abrir()
  -- Capturar arquivo e buffer antes
  -- de abrir a janela de selecao.
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  local extensao = ""

  if arquivo ~= "" then
    extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()
  end

  local raiz = M.raiz_modulo(arquivo)

  -- ========================================
  -- CRIACAO DE PROJETOS
  -- ========================================

  local opcoes = {
    {
      nome = "Criar novo projeto Go",
      executar = function()
        projetos.criar()
      end,
    },
  }

  -- ========================================
  -- OPERACOES DO ARQUIVO GO
  -- ========================================

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

  -- ========================================
  -- OPERACOES DO MODULO GO
  -- ========================================

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

    -- Selecao explicita de executaveis.
    -- Funciona mesmo dentro de main.go.
    if extensao == "go" then
      table.insert(opcoes, {
        nome = "Selecionar e executar programa",
        executar = function()
          runner.selecionar_programa(arquivo)
        end,
      })
    end
  end

  -- ========================================
  -- LINT CONTEXTUAL
  -- ========================================

  if extensao == "go" then
    table.insert(opcoes, {
      nome = "Analisar pacote atual (golangci-lint)",
      executar = function()
        analisar_pacote(buffer)
      end,
    })
  end

  -- ========================================
  -- GERENCIAMENTO DE DEPENDENCIAS
  -- ========================================

  if raiz then
    table.insert(opcoes, {
      nome = "Organizar dependencias (go mod tidy)",
      executar = function()
        dependencias.organizar(arquivo)
      end,
    })
  end

  -- ========================================
  -- INFORMACOES DO MODULO GO
  -- ========================================

  -- Disponibilizar somente quando
  -- houver um modulo Go identificado.
  --
  -- A consulta e a janela ficam
  -- inteiramente no modulo info.lua.
  if raiz then
    table.insert(opcoes, {
      nome = "Informacoes do modulo Go",
      executar = function()
        informacoes.mostrar(arquivo)
      end,
    })
  end

  -- ========================================
  -- EXIBIR MENU
  -- ========================================

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
