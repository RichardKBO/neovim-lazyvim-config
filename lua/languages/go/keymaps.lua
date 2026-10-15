local M = {}

-- ========================================
-- IDENTIFICAR CONTEXTO GO
-- ========================================

function M.eh_contexto_go(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  return vim.bo[buffer].filetype == "go"
end

-- ========================================
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[GO]",
    "  Espaco + g m   Abrir GoMenu",
    "  :GoMenu        Gerenciar projetos Go",
    "  F5             Adicionar/remover breakpoint",
    "  F6             Executar pacote atual",
    "  F8             Depurar pacote / continuar",
    "",
  }
end

-- ========================================
-- DEBUGGER DINAMICO
-- ========================================

local function depurar_go(buffer)
  local ok, debugger = pcall(require, "languages.go.debugger")

  if not ok then
    vim.notify("Go: debugger.lua indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- Localizar, compilar e depurar o pacote
  -- correspondente ao arquivo aberto.
  -- Se houver uma sessao, continuar.
  debugger.depurar(vim.api.nvim_buf_get_name(buffer))
end

-- ========================================
-- ATALHOS LOCAIS GO
-- ========================================

local function aplicar(buffer)
  if not M.eh_contexto_go(buffer) then
    return
  end

  -- Abrir GoMenu.
  vim.keymap.set("n", "<leader>gm", function()
    require("languages.go.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "Go: abrir GoMenu",
  })

  -- F8 dinamico com Delve.
  vim.keymap.set("n", "<F8>", function()
    depurar_go(buffer)
  end, {
    buffer = buffer,
    silent = true,
    desc = "Go: depurar pacote atual / continuar",
  })
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup("GoDebuggerKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = "go",

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar aos buffers Go ja carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      aplicar(buffer)
    end
  end
end

return M
