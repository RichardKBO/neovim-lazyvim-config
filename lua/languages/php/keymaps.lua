-- ========================================
-- PHP - ATALHOS CONTEXTUAIS
-- ========================================

local M = {}

-- ========================================
-- IDENTIFICAR CONTEXTO PHP
-- ========================================

function M.eh_contexto_php(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  return vim.bo[buffer].filetype == "php"
end

-- ========================================
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[PHP]",
    "  Espaco + p h   Abrir PHPMenu",
    "  :PHPMenu        Gerenciar projetos PHP",
    "  F5              Adicionar/remover breakpoint",
    "  F6              Executar arquivo atual",
    "  F8              Depurar arquivo / continuar",
    "",
  }
end

-- ========================================
-- ATALHOS LOCAIS PHP
-- ========================================

local function aplicar(buffer)
  if not M.eh_contexto_php(buffer) then
    return
  end

  -- Abrir PHPMenu somente em buffers PHP.
  vim.keymap.set("n", "<leader>ph", function()
    require("languages.php.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "PHP: abrir PHPMenu",
  })
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup(
    "PHPMenuKeymaps",
    { clear = true }
  )

  -- Aplicar ao abrir arquivos PHP.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = "php",

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar aos buffers PHP ja carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      aplicar(buffer)
    end
  end
end

return M
