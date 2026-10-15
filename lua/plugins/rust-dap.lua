-- Carregador do debugger Rust
-- Configuracao principal em languages/rust/dap.lua
-- Utiliza nvim-dap + CodeLLDB + Cargo

return {
  {
    "mfussenegger/nvim-dap",

    opts = function(_, opts)
      -- Preservar configuracoes compartilhadas do nvim-dap.
      opts = opts or {}

      -- Carregar o debugger especifico do Rust.
      require("languages.rust.dap").setup()

      return opts
    end,
  },
}
