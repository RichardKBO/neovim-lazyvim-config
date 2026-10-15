-- Impedir a instalação automática do CodeLLDB pelo Mason.
-- O CodeLLDB já está instalado manualmente.
-- Preservar as instalações automáticas das demais ferramentas.

return {
  {
    "mason-org/mason.nvim",

    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      opts.ensure_installed = vim.tbl_filter(function(pacote)
        return pacote ~= "codelldb"
      end, opts.ensure_installed)

      return opts
    end,
  },
}
