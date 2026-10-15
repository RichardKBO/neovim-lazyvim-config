local M = {}

-- ========================================
-- NOTIFICACOES
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- ========================================
-- DIRETORIO DE EXECUCAO
-- ========================================

-- Utilizar a raiz CMake como cwd durante
-- a depuracao de projetos.
--
-- Em arquivos independentes, utilizar a
-- pasta do proprio arquivo.
local function localizar_cwd(arquivo, fallback)
  local encontrados = vim.fs.find("CMakeLists.txt", {
    path = vim.fs.dirname(arquivo),
    upward = true,
  })

  if #encontrados > 0 then
    return vim.fs.dirname(encontrados[1])
  end

  return vim.fs.dirname(arquivo) or fallback
end

-- ========================================
-- INICIAR CODELLDB
-- ========================================

local function iniciar_debugger(dap, arquivo, executavel, cwd)
  -- Evitar iniciar uma segunda sessao.
  if dap.session() then
    avisar("C++: ja existe uma sessao de depuracao.", vim.log.levels.WARN)
    return
  end

  local diretorio = localizar_cwd(arquivo, cwd)

  -- Configuracao dinamica do CodeLLDB.
  local configuracao = {
    type = "codelldb",
    request = "launch",

    name = "C++: " .. vim.fn.fnamemodify(executavel, ":t"),

    program = executavel,
    cwd = diretorio,

    args = {},
    stopOnEntry = false,
  }

  avisar("C++: iniciando debugger para " .. vim.fn.fnamemodify(executavel, ":t"))

  local ok, erro = pcall(dap.run, configuracao)

  if not ok then
    avisar("C++: falha ao iniciar CodeLLDB: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- ========================================
-- F8 DINAMICO
-- ========================================

function M.depurar(arquivo)
  -- Carregar nvim-dap.
  local ok_dap, dap = pcall(require, "dap")

  if not ok_dap then
    avisar("C++: nvim-dap nao esta disponivel.", vim.log.levels.ERROR)
    return
  end

  -- Se o debugger ja estiver ativo,
  -- continuar a execucao.
  if dap.session() then
    dap.continue()
    return
  end

  -- Verificar o adaptador compartilhado.
  if not dap.adapters.codelldb then
    avisar("C++: adaptador CodeLLDB " .. "nao esta configurado.", vim.log.levels.ERROR)
    return
  end

  -- Capturar o arquivo atual.
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("C++: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  -- Carregar o runner dinamico.
  local ok_runner, runner = pcall(require, "languages.cpp.runner")

  if not ok_runner or type(runner.preparar) ~= "function" then
    avisar("C++: runner.preparar() indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- Preparar o executavel.
  --
  -- O runner identifica a raiz CMake,
  -- configura, compila e retorna o
  -- executavel correspondente ao arquivo.
  --
  -- Para arquivos isolados, utiliza
  -- o compilador diretamente.
  local ok, erro = pcall(runner.preparar, arquivo, function(executavel, cwd)
    iniciar_debugger(dap, arquivo, executavel, cwd)
  end)

  if not ok then
    avisar("C++: falha ao preparar debugger: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

return M
