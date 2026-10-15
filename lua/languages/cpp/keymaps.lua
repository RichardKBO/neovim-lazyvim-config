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
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[C / C++ / CMAKE]",
    "  Espaco + c p   Abrir CPPMenu",
    "  :CPPMenu       Gerenciar projetos C++",
    "  F5             Adicionar/remover breakpoint",
    "  F6             Executar arquivo atual",
    "  F7             Gerar/atualizar CMake",
    "  F8             Depurar arquivo atual / continuar",
    "",
  }
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
-- ATALHOS LOCAIS C/C++
-- ========================================

local function aplicar(buffer)
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
  local grupo = vim.api.nvim_create_augroup("CppDebuggerKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = { "cpp", "c" },

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
