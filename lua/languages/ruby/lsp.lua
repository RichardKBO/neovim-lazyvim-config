-- ========================================
-- RUBY - RUBY LSP
-- Diagnosticos e integracao com Neovim
-- ========================================

local M = {}

function M.setup()
  -- ========================================
  -- DIAGNOSTICOS RUBY
  -- ========================================

  local grupo = vim.api.nvim_create_augroup("RubyLspDiagnostics", {
    clear = true,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      local cliente = vim.lsp.get_client_by_id(evento.data.client_id)

      if not cliente or cliente.name ~= "ruby_lsp" then
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

  -- ========================================
  -- DESATIVAR SOLARGRAPH
  -- ========================================

  vim.lsp.enable("solargraph", false)

  -- ========================================
  -- CONFIGURAR RUBY LSP
  -- ========================================

  vim.lsp.config("ruby_lsp", {
    root_markers = {
      "Gemfile",
      "gems.rb",
      "Rakefile",
      ".ruby-version",
      ".tool-versions",
      ".mise.toml",
      "mise.toml",
      ".git",
    },
  })

  -- ========================================
  -- ATIVAR RUBY LSP
  -- ========================================

  vim.lsp.enable("ruby_lsp")
end

return M
