local M = {}

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function()
      vim.lsp.enable("gopls")
    end,
  })
end

return M
