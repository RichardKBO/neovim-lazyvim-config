local M = {}

-- ========================================
-- IDENTIFICAR CONTEXTO PYTHON
-- ========================================

function M.eh_contexto_python(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  return vim.bo[buffer].filetype == "python"
end

-- ========================================
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[PYTHON]",
    "  Espaco + p m   Abrir PythonMenu",
    "  :PythonMenu     Gerenciar projetos Python",
    "  F5              Adicionar/remover breakpoint",
    "  F6              Executar arquivo atual",
    "  F8              Depurar arquivo / continuar",
    "",
  }
end

-- ========================================
-- ATALHOS LOCAIS PYTHON
-- ========================================

local function aplicar(buffer)
  if not M.eh_contexto_python(buffer) then
    return
  end

  -- Abrir PythonMenu no buffer atual.
  vim.keymap.set("n", "<leader>pm", function()
    require("languages.python.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "Python: abrir PythonMenu",
  })
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup("PythonMenuKeymaps", { clear = true })

  -- Aplicar ao abrir arquivos Python.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = "python",

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar aos buffers Python ja carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      aplicar(buffer)
    end
  end
end

return M
