-- Transparencia integrada aos temas do Neovim.
-- Preserva as cores de sintaxe e os destaques existentes.

local grupo = vim.api.nvim_create_augroup("TransparenciaTemas", {
  clear = true,
})

local function aplicar_transparencia()
  vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
end

-- Reaplicar a transparencia sempre que um tema for carregado.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = grupo,
  callback = function()
    vim.schedule(aplicar_transparencia)
  end,
  desc = "Manter fundo transparente ao trocar de tema",
})

-- Aplicar tambem ao iniciar o Neovim.
vim.schedule(aplicar_transparencia)
