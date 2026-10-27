-- Diagnósticos em tempo real (inline error)
vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = "●",
  },
  underline = true,
  signs = true,
  update_in_insert = true,
})

-- ========================================
-- K30: cursor minimalista exclusivo do Kitty
-- ========================================
if vim.env.NVIM_STATUSLINE_STYLE == "bubbles_lego" then
  -- Destacar somente o numero da linha atual.
  -- Nao pintar o fundo da linha inteira.
  vim.opt.cursorline = true
  vim.opt.cursorlineopt = "number"
end
