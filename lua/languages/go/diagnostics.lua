local M = {}

-- ========================================
-- DIAGNOSTICOS DISCRETOS DO GO
-- ========================================

local function aparencia_discreta()
  local severidade = vim.diagnostic.severity

  return {
    -- Destacar somente erros reais.
    underline = {
      severity = severidade.ERROR,
    },

    -- Preservar os indicadores na margem.
    signs = true,

    -- Nao criar linhas virtuais adicionais.
    virtual_lines = false,

    -- Mostrar mensagens somente na linha do cursor.
    virtual_text = {
      current_line = true,
      spacing = 1,
      prefix = "·",

      format = function(diagnostico)
        local mensagem = diagnostico.message

        -- Resumir sugestoes muito longas.
        if diagnostico.severity == severidade.HINT
            and #mensagem > 42 then
          return mensagem:sub(1, 39) .. "..."
        end

        return mensagem
      end,
    },
  }
end

-- ========================================
-- CONFIGURACAO DO GOPLS
-- ========================================

local function configurar_cliente(cliente)
  if not cliente or cliente.name ~= "gopls" then
    return
  end

  local namespace = vim.lsp.diagnostic.get_namespace(cliente.id)

  local opcoes = aparencia_discreta()

  -- Preservar atualizacao durante a digitacao.
  opcoes.update_in_insert = true

  vim.diagnostic.config(opcoes, namespace)
end

function M.setup()
  -- ========================================
  -- GOLANGCI-LINT
  -- ========================================

  -- O nvim-lint utiliza o nome do linter
  -- como namespace. Personalizar somente Go.
  local namespace_linter =
    vim.api.nvim_create_namespace("golangcilint")

  vim.diagnostic.config(
    aparencia_discreta(),
    namespace_linter
  )

  -- ========================================
  -- GOPLS
  -- ========================================

  local grupo = vim.api.nvim_create_augroup(
    "GoDiagnosticsInsert",
    { clear = true }
  )

  vim.api.nvim_create_autocmd("LspAttach", {
    group = grupo,

    callback = function(evento)
      if vim.bo[evento.buf].filetype ~= "go" then
        return
      end

      if not evento.data or not evento.data.client_id then
        return
      end

      local cliente =
        vim.lsp.get_client_by_id(evento.data.client_id)

      configurar_cliente(cliente)
    end,
  })

  -- Atender tambem clientes ja conectados.
  for _, cliente in ipairs(
    vim.lsp.get_clients({ name = "gopls" })
  ) do
    configurar_cliente(cliente)
  end
end

return M
