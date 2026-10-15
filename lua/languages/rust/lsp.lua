local M = {}

-- Diagnosticos inline exclusivos do Rust Analyzer.
local opcoes_diagnosticos = {
  update_in_insert = true,

  virtual_text = {
    prefix = "●",
    spacing = 2,
  },

  underline = true,
  signs = true,
}

-- Identifica e configura todos os namespaces de um
-- cliente Rust Analyzer, incluindo diagnosticos push e pull.
local function configurar_diagnosticos(client)
  local prefixo = "nvim.lsp.rust_analyzer." .. client.id

  for namespace, info in pairs(vim.diagnostic.get_namespaces()) do
    local nome = info.name or ""

    if nome == prefixo or vim.startswith(nome, prefixo .. ".") then
      vim.diagnostic.config(opcoes_diagnosticos, namespace)
    end
  end
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("RustDiagnosticsInline", { clear = true })

  -- Mantem a ativacao do Rust Analyzer para arquivos Rust.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = "rust",

    callback = function()
      vim.lsp.enable("rust_analyzer")
    end,
  })

  -- Aplica as configuracoes quando o Rust Analyzer conecta.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      local client = vim.lsp.get_client_by_id(evento.data.client_id)

      if not client or client.name ~= "rust_analyzer" then
        return
      end

      configurar_diagnosticos(client)

      -- Alguns namespaces so aparecem quando os
      -- primeiros diagnosticos sao publicados.
      vim.api.nvim_create_autocmd("DiagnosticChanged", {
        group = grupo,
        buffer = evento.buf,

        callback = function()
          if not vim.lsp.get_client_by_id(client.id) then
            return
          end

          configurar_diagnosticos(client)
        end,
      })
    end,
  })
end

return M
