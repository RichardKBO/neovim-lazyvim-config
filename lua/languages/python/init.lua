return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          vim.lsp.enable("pyright")
        end,
      })
    end,
  },
}
