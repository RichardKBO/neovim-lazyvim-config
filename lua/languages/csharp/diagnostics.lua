-- ========================================
-- C# - DIAGNOSTICOS INLINE DO ROSLYN
-- ========================================

local M = {}

-- ========================================
-- CONFIGURACAO DOS DIAGNOSTICOS
-- ========================================

local function configurar_namespace(namespace)
  if not namespace then
    return
  end

  local informacoes = vim.diagnostic.get_namespace(namespace)

  if not informacoes or not informacoes.name or not informacoes.name:match("^nvim%.lsp%.roslyn%.") then
    return
  end

  -- Aplicar exclusivamente aos
  -- diagnosticos publicados pelo Roslyn.
  vim.diagnostic.config({
    virtual_text = {
      prefix = "●",
      spacing = 2,
      source = "if_many",
    },

    update_in_insert = true,
    underline = true,
  }, namespace)
end

-- ========================================
-- CLIENTE ROSLYN
-- ========================================

local function configurar_cliente(cliente)
  if not cliente or cliente.name ~= "roslyn" then
    return
  end

  -- Diagnosticos enviados pelo servidor.
  local push = vim.lsp.diagnostic.get_namespace(cliente.id, false)

  configurar_namespace(push)

  -- Diagnosticos solicitados ao servidor.
  local pull = vim.lsp.diagnostic.get_namespace(cliente.id, true)

  configurar_namespace(pull)
end

-- ========================================
-- BUFFERS C#
-- ========================================

local function configurar_buffer(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then
    return
  end

  if vim.bo[buffer].filetype ~= "cs" then
    return
  end

  for _, cliente in
    ipairs(vim.lsp.get_clients({
      bufnr = buffer,
      name = "roslyn",
    }))
  do
    configurar_cliente(cliente)
  end

  -- Identificar namespaces que ja possuem
  -- diagnosticos neste buffer.
  --
  -- Isso contempla tambem provedores
  -- de diagnosticos pull com identificadores
  -- especificos.
  local registrados = {}

  for _, diagnostico in ipairs(vim.diagnostic.get(buffer)) do
    local namespace = diagnostico.namespace

    if namespace and not registrados[namespace] then
      registrados[namespace] = true
      configurar_namespace(namespace)
    end
  end
end

-- ========================================
-- INICIALIZACAO
-- ========================================

function M.setup()
  local grupo = vim.api.nvim_create_augroup("CSharpRoslynDiagnostics", { clear = true })

  -- Quando o Roslyn se conectar.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      configurar_buffer(evento.buf)
    end,
  })

  -- Quando novos diagnosticos chegarem.
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = grupo,

    callback = function(evento)
      configurar_buffer(evento.buf)
    end,
  })

  -- Suportar arquivos C# ja abertos.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      configurar_buffer(buffer)
    end
  end
end

return M
