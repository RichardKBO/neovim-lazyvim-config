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
-- IDENTIFICAR CONFIGURACAO DO BUILD
-- ========================================

local function identificar_tipo_build(executavel)
  local diretorio = vim.fs.dirname(executavel)

  -- Procurar o CMakeCache.txt a partir da
  -- pasta que contem o executavel.
  while diretorio do
    local cache = vim.fs.joinpath(diretorio, "CMakeCache.txt")

    if vim.fn.filereadable(cache) == 1 then
      local ok, linhas = pcall(vim.fn.readfile, cache)

      if not ok then
        avisar("C++: falha ao ler configuracao do build.", vim.log.levels.WARN)
        return nil
      end

      for _, linha in ipairs(linhas) do
        local tipo = linha:match("^CMAKE_BUILD_TYPE:[^=]*=(.*)$")

        if tipo then
          return vim.trim(tipo)
        end
      end

      return nil
    end

    local pai = vim.fs.dirname(diretorio)

    if not pai or pai == diretorio then
      break
    end

    diretorio = pai
  end

  return nil
end

-- ========================================
-- INICIAR CODELLDB
-- ========================================

local function iniciar_debugger(dap, arquivo, executavel, cwd)
  if dap.session() then
    avisar("C++: ja existe uma sessao de depuracao.", vim.log.levels.WARN)
    return
  end

  local diretorio = localizar_cwd(arquivo, cwd)

  local configuracao = {
    type = "codelldb",
    request = "launch",

    name = "C++: " .. vim.fn.fnamemodify(executavel, ":t"),

    program = executavel,
    cwd = diretorio,

    args = {},
    stopOnEntry = false,
  }

  local function executar_debugger()
    -- Verificar novamente porque a confirmacao
    -- pode acontecer depois de outra sessao iniciar.
    if dap.session() then
      avisar("C++: ja existe uma sessao de depuracao.", vim.log.levels.WARN)
      return
    end

    avisar("C++: iniciando debugger para " .. vim.fn.fnamemodify(executavel, ":t"))

    local ok, erro = pcall(dap.run, configuracao)

    if not ok then
      avisar("C++: falha ao iniciar CodeLLDB: " .. tostring(erro), vim.log.levels.ERROR)
    end
  end

  -- Consultar a configuracao efetiva do build,
  -- sem depender apenas do nome do preset.
  local tipo = identificar_tipo_build(executavel)

  if tipo == "Release" or tipo == "MinSizeRel" then
    local opcoes = {
      "Cancelar depuracao",
      "Depurar mesmo assim",
    }

    vim.ui.select(opcoes, {
      prompt = "C++: build " .. tipo .. " pode dificultar a depuracao. Deseja continuar?",
    }, function(escolha)
      if escolha ~= opcoes[2] then
        avisar("C++: depuracao cancelada. " .. "Configuracao " .. tipo .. " preservada.", vim.log.levels.WARN)
        return
      end

      executar_debugger()
    end)

    return
  end

  executar_debugger()
end

-- ========================================
-- F8 DINAMICO
-- ========================================

function M.depurar(arquivo)
  local ok_dap, dap = pcall(require, "dap")

  if not ok_dap then
    avisar("C++: nvim-dap nao esta disponivel.", vim.log.levels.ERROR)
    return
  end

  -- Continuar a sessao existente.
  if dap.session() then
    dap.continue()
    return
  end

  if not dap.adapters.codelldb then
    avisar("C++: adaptador CodeLLDB nao esta configurado.", vim.log.levels.ERROR)
    return
  end

  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("C++: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  local ok_runner, runner = pcall(require, "languages.cpp.runner")

  if not ok_runner or type(runner.preparar) ~= "function" then
    avisar("C++: runner.preparar() indisponivel.", vim.log.levels.ERROR)
    return
  end

  local ok, erro = pcall(runner.preparar, arquivo, function(executavel, cwd)
    iniciar_debugger(dap, arquivo, executavel, cwd)
  end)

  if not ok then
    avisar("C++: falha ao preparar debugger: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

return M
