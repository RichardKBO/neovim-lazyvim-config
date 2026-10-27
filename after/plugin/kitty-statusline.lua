-- ========================================
-- KITTY: STATUSLINE TRANSPARENTE
-- ========================================
-- Remove a inversao de cores da Statusline.
-- Preserva o comportamento do GNOME Terminal.

if vim.env.NVIM_STATUSLINE_STYLE ~= "bubbles_lego" then
  return
end

local function aplicar_transparencia()
  local grupos = {
    "StatusLine",
    "StatusLineNC",
  }

  for _, nome in ipairs(grupos) do
    local destaque = vim.api.nvim_get_hl(0, {
      name = nome,
      link = false,
    })

    vim.api.nvim_set_hl(0, nome, {
      fg = destaque.fg or "#d0d0d0",
      bg = "NONE",
      bold = destaque.bold == true,
      reverse = false,
    })
  end
end

-- Reaplicar quando o tema mudar.
local grupo = vim.api.nvim_create_augroup(
  "KittyStatuslineTransparente",
  { clear = true }
)

vim.api.nvim_create_autocmd("ColorScheme", {
  group = grupo,
  callback = function()
    vim.schedule(aplicar_transparencia)
  end,
  desc = "Manter a Statusline transparente no Kitty",
})

-- Aplicar tambem ao iniciar o Neovim.
vim.schedule(aplicar_transparencia)
