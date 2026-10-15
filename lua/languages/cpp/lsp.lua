-- Configuração modular do LSP para C/C++
-- Utiliza clangd.

local M = {}

function M.setup()
  -- Evitar registrar o mesmo autocmd mais de uma vez.
  local grupo = vim.api.nvim_create_augroup("LanguagesCppLsp", {
    clear = true,
  })

  -- Habilitar clangd automaticamente para arquivos C/C++.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = {
      "c",
      "cpp",
      "objc",
      "objcpp",
    },
    callback = function()
      vim.lsp.enable("clangd")
    end,
  })
end

return M
