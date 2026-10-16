-- ========================================
-- RUBY - ATALHOS CONTEXTUAIS
-- ========================================

local M = {}

-- ========================================
-- IDENTIFICAR CONTEXTO RUBY
-- ========================================

function M.eh_contexto_ruby(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  return vim.bo[buffer].filetype == "ruby"
end

-- ========================================
-- CENTRAL DE ATALHOS
-- ========================================

function M.linhas_ajuda()
  return {
    "[RUBY]",
    "  Espaco + r m   Abrir RubyMenu",
    "  :RubyMenu       Gerenciar projetos Ruby",
    "  F5              Adicionar/remover breakpoint",
    "  F6              Executar arquivo atual",
    "  F8              Depurar arquivo / continuar",
    "  gd              Ir para definicao",
    "  gr              Buscar referencias (Snacks)",
    "  Ctrl + o        Voltar a posicao anterior",
    "  Ctrl + Espaco   Abrir autocomplete",
    "",
  }
end

-- ========================================
-- ATALHOS LOCAIS RUBY
-- ========================================

local function aplicar(buffer)
  if not M.eh_contexto_ruby(buffer) then
    return
  end

  -- Abrir RubyMenu somente em buffers Ruby.
  vim.keymap.set("n", "<leader>rm", function()
    require("languages.ruby.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "Ruby: abrir RubyMenu",
  })
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup("RubyMenuKeymaps", { clear = true })

  -- Aplicar ao abrir arquivos Ruby.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = "ruby",

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar aos buffers Ruby ja carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      aplicar(buffer)
    end
  end
end

return M
