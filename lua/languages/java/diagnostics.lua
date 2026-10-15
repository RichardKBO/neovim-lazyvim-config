local M = {}

local function configurar_cliente(cliente)
  if not cliente or cliente.name ~= "jdtls" then
    return
  end

  -- Configurar somente os diagnosticos deste JDTLS.
  local namespace = vim.lsp.diagnostic.get_namespace(cliente.id)

  vim.diagnostic.config({
    update_in_insert = true,
  }, namespace)
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("JavaDiagnosticsInsert", { clear = true })

  -- Aplicar quando o JDTLS conectar ao buffer.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      if vim.bo[evento.buf].filetype ~= "java" then
        return
      end

      local cliente = vim.lsp.get_client_by_id(evento.data.client_id)

      configurar_cliente(cliente)
    end,
  })

  -- Tambem considerar clientes ja conectados.
  for _, cliente in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
    configurar_cliente(cliente)
  end
end

return M
