local M = {}

-- ========================================
-- IDENTIFICAR CONTEXTO C/C++
-- ========================================

function M.eh_contexto_cpp(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  local tipo = vim.bo[buffer].filetype

  return tipo == "cpp" or tipo == "c"
end

-- ========================================
-- IDENTIFICAR CMakeLists.txt
-- ========================================

local function eh_cmake_principal(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  if vim.bo[buffer].filetype ~= "cmake" then
    return false
  end

  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if arquivo == "" then
    return false
  end

  return vim.fn.fnamemodify(arquivo, ":t") == "CMakeLists.txt"
end

-- ========================================
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[C / C++ / CMAKE]",
    "  Espaco + c p   Abrir CPPMenu",
    "  :CPPMenu       Gerenciar projetos C++",
    "  F5             Adicionar/remover breakpoint",
    "  F6             Executar arquivo atual",
    "  F7             Configurar projeto CMake atual",
    "  F8             Depurar arquivo atual / continuar",
    "",
  }
end

-- ========================================
-- CONFIGURACAO CMAKE INTELIGENTE
-- ========================================

local function configurar_cpp()
  local ok, runner = pcall(require, "languages.cpp.runner")

  if not ok then
    vim.notify("C++: runner.lua indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- Identificar o projeto pelo arquivo atual.
  -- Nao depender do cwd global do Neovim.
  runner.configurar(vim.api.nvim_buf_get_name(0))
end

-- ========================================
-- DEBUGGER DINAMICO
-- ========================================

local function depurar_cpp()
  local ok, debugger = pcall(require, "languages.cpp.debugger")

  if not ok then
    vim.notify("C++: debugger.lua indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- O debugger identifica o arquivo atual,
  -- localiza o projeto, compila e inicia
  -- o CodeLLDB automaticamente.
  --
  -- Se ja existir uma sessao,
  -- continua a depuracao.
  debugger.depurar(vim.api.nvim_buf_get_name(0))
end

-- ========================================
-- ATALHOS LOCAIS C/C++ E CMAKE
-- ========================================

local function aplicar(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  -- CMakeLists.txt recebe somente o F7.
  if eh_cmake_principal(buffer) then
    vim.keymap.set("n", "<F7>", configurar_cpp, {
      buffer = buffer,
      silent = true,
      desc = "CMake: configurar projeto do arquivo atual",
    })

    return
  end

  -- Preservar os atalhos C/C++ existentes.
  if not M.eh_contexto_cpp(buffer) then
    return
  end

  -- Abrir CPPMenu.
  vim.keymap.set("n", "<leader>cp", function()
    require("languages.cpp.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "C++: abrir CPPMenu",
  })

  -- F7 inteligente para C/C++.
  vim.keymap.set("n", "<F7>", configurar_cpp, {
    buffer = buffer,
    silent = true,
    desc = "C++: configurar projeto CMake atual",
  })

  -- F8 dinamico para C/C++.
  vim.keymap.set("n", "<F8>", depurar_cpp, {
    buffer = buffer,
    silent = true,
    desc = "C++: depurar arquivo atual / continuar",
  })
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup("CppDebuggerKeymaps", {
    clear = true,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = { "cpp", "c", "cmake" },

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar tambem aos buffers ja carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      aplicar(buffer)
    end
  end
end

return M
