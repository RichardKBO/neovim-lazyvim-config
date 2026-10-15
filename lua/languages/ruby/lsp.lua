local M = {}

function M.setup()
  -- Configuracao de diagnosticos exclusiva do Ruby
  local grupo = vim.api.nvim_create_augroup("RubySolargraphDiagnostics", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      local cliente = vim.lsp.get_client_by_id(evento.data.client_id)

      if not cliente or cliente.name ~= "solargraph" then
        return
      end

      local namespace = vim.lsp.diagnostic.get_namespace(cliente.id)

      vim.diagnostic.config({
        update_in_insert = true,

        virtual_text = {
          prefix = "●",
          spacing = 2,
        },

        underline = true,
        signs = true,
        virtual_lines = false,
      }, namespace)
    end,
  })

  -- Manter somente Solargraph ativo para Ruby
  vim.lsp.enable("ruby_lsp", false)

  vim.lsp.config("solargraph", {
    cmd = { "solargraph", "stdio" },

    filetypes = {
      "ruby",
      "eruby",
    },

    root_markers = {
      "Gemfile",
      ".git",
    },

    settings = {
      solargraph = {
        diagnostics = true,
      },
    },
  })

  vim.lsp.enable("solargraph")
end

return M
