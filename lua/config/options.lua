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
