local M = {}

-- ========================================
-- ESTADO
-- ========================================

local em_execucao = {}

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
-- LOCALIZAR MODULO GO
-- ========================================

local function localizar_modulo(arquivo)
  if not arquivo or arquivo == "" then
    return nil
  end

  local caminho = normalizar(arquivo)
  local diretorio = vim.fs.dirname(caminho)

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
-- PROTEGER ARQUIVOS NAO SALVOS
-- ========================================

local function dependencias_modificadas(raiz)
  local mod = vim.fs.joinpath(raiz, "go.mod")
  local sum = vim.fs.joinpath(raiz, "go.sum")

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buffer) and vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].modified then
      local arquivo = vim.api.nvim_buf_get_name(buffer)

      if arquivo ~= "" then
        arquivo = normalizar(arquivo)

        if arquivo == mod or arquivo == sum then
          return vim.fn.fnamemodify(arquivo, ":t")
        end
      end
    end
  end

  return nil
end

-- ========================================
-- EXECUTAR GO MOD TIDY
-- ========================================

local function executar_tidy(raiz)
  if em_execucao[raiz] then
    avisar("Go: gerenciamento de dependencias ja em andamento.", vim.log.levels.WARN)
    return
  end

  local pendente = dependencias_modificadas(raiz)

  if pendente then
    avisar("Go: salve " .. pendente .. " antes de organizar as dependencias.", vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(vim.fs.joinpath(raiz, "go.mod")) ~= 1 then
    avisar("Go: go.mod nao encontrado.", vim.log.levels.ERROR)
    return
  end

  em_execucao[raiz] = true

  local abriu, erro = pcall(vim.cmd, "botright 12new")

  if not abriu then
    em_execucao[raiz] = nil

    avisar("Go: falha ao abrir terminal: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  local ok, processo = pcall(vim.fn.termopen, {
    "go",
    "mod",
    "tidy",
  }, {
    cwd = raiz,

    on_exit = function(_, codigo)
      vim.schedule(function()
        em_execucao[raiz] = nil

        if codigo == 0 then
          -- Atualizar buffers caso arquivos
          -- de dependencias tenham mudado.
          vim.cmd("checktime")

          avisar("Go: dependencias organizadas com sucesso!\n" .. raiz)
        else
          avisar("Go: falha em go mod tidy. Codigo: " .. tostring(codigo), vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or processo <= 0 then
    em_execucao[raiz] = nil

    avisar("Go: nao foi possivel iniciar go mod tidy: " .. tostring(processo), vim.log.levels.ERROR)
    return
  end

  avisar("Go: organizando dependencias em " .. raiz)

  vim.cmd("startinsert")
end

-- ========================================
-- GERENCIAMENTO CONTEXTUAL
-- ========================================

function M.organizar(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local raiz = localizar_modulo(arquivo)

  if not raiz then
    avisar("Go: nenhum modulo go.mod encontrado.", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("go") ~= 1 then
    avisar("Go: comando go nao encontrado.", vim.log.levels.ERROR)
    return
  end

  if em_execucao[raiz] then
    avisar("Go: gerenciamento de dependencias ja em andamento.", vim.log.levels.WARN)
    return
  end

  local pendente = dependencias_modificadas(raiz)

  if pendente then
    avisar("Go: salve " .. pendente .. " antes de continuar.", vim.log.levels.WARN)
    return
  end

  -- Nao executar automaticamente.
  -- Exigir confirmacao explicita.
  vim.ui.select({
    "Cancelar",
    "Executar go mod tidy",
  }, {
    prompt = "Go: organizar dependencias em " .. raiz .. "?",
  }, function(escolha)
    if escolha ~= "Executar go mod tidy" then
      return
    end

    executar_tidy(raiz)
  end)
end

return M
