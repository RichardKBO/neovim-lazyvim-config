return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          on_attach = function(client, bufnr)
            client.server_capabilities.semanticTokensProvider = nil
          end,
        },
      },
    },
  },
}
