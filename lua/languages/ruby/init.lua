-- Integracao do Ruby com o LazyVim
-- A configuracao do LSP fica em languages/ruby/lsp.lua

return {
  {
    "neovim/nvim-lspconfig",

    init = function()
      require("languages.ruby.lsp").setup()
    end,
  },
}
