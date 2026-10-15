local M = {}

-- ========================================
-- DIAGNOSTICOS GLOBAIS DO GO
-- ========================================

-- Configurar somente o Gopls.
local function configurar_cliente(cliente)
  if not cliente or cliente.name ~= "gopls" then
    return
  end

  -- Namespace exclusivo do servidor Gopls.
  local namespace = vim.lsp.diagnostic.get_namespace(cliente.id)

  -- Atualizar diagnosticos durante a digitacao.
  -- Virtual text, sinais e underline continuam
  -- herdando a configuracao global do Neovim.
  vim.diagnostic.config({
    update_in_insert = true,
  }, namespace)
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("GoDiagnosticsInsert", { clear = true })

  -- Configurar automaticamente quando o
  -- Gopls se conectar a um buffer Go.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      if vim.bo[evento.buf].filetype ~= "go" then
        return
      end

      if not evento.data or not evento.data.client_id then
        return
      end

      local cliente = vim.lsp.get_client_by_id(evento.data.client_id)

      configurar_cliente(cliente)
    end,
  })

  -- Aplicar tambem aos clientes Gopls
  -- que ja estiverem conectados.
  for _, cliente in ipairs(vim.lsp.get_clients({ name = "gopls" })) do
    configurar_cliente(cliente)
  end
end

return M
