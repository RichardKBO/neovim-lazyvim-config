return {
  {
    "AlexandrosAlexiou/kotlin.nvim",

    -- Registrar comandos e atalhos Kotlin.
    init = function()
      require("languages.kotlin.menu").setup()
      require("languages.kotlin.keymaps").setup()
    end,

    -- Inicializar o servidor Kotlin LSP externo.
    config = function()
      require("languages.kotlin.lsp").setup()
    end,
  },
}
