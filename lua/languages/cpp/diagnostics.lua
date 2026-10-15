local M = {}

-- Identificar buffers C e C++.
local function eh_cpp(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  local tipo = vim.bo[buffer].filetype

  return tipo == "c" or tipo == "cpp" or tipo == "objc" or tipo == "objcpp"
end

-- Configurar diagnosticos somente do Clangd.
local function configurar_cliente(cliente)
  if not cliente or cliente.name ~= "clangd" then
    return
  end

  -- Obter o namespace de diagnosticos do Clangd.
  local namespace = vim.lsp.diagnostic.get_namespace(cliente.id)

  -- Atualizar erros e avisos tambem durante
  -- a digitacao, como no Java.
  --
  -- O virtual_text continua herdando a
  -- configuracao global do Neovim.
  vim.diagnostic.config({
    update_in_insert = true,
  }, namespace)
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("CppDiagnosticsInsert", { clear = true })

  -- Configurar quando o Clangd conectar
  -- a um buffer C/C++.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      if not eh_cpp(evento.buf) then
        return
      end

      if not evento.data or not evento.data.client_id then
        return
      end

      local cliente = vim.lsp.get_client_by_id(evento.data.client_id)

      configurar_cliente(cliente)
    end,
  })

  -- Suportar clientes Clangd ja conectados.
  for _, cliente in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
    configurar_cliente(cliente)
  end
end

return M
