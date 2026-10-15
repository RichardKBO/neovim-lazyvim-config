return {
  {
    "smjonas/inc-rename.nvim",

    -- Carregar ao utilizar o comando ou atalho
    cmd = "IncRename",

    -- Integrar com a interface do Snacks
    opts = {
      input_buffer_type = "snacks",
    },

    -- Atalho global para renomeação interativa
    keys = {
      {
        "<leader>rn",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Renomear símbolo (LSP)",
      },
    },
  },
}
