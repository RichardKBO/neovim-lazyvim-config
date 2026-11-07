-- ========================================
-- SWIFT - CONFIGURACAO LOCAL DE INDENTACAO
-- ========================================

-- Preservar o alinhamento correto das chaves.
vim.opt_local.smartindent = false
vim.opt_local.cindent = false
vim.opt_local.autoindent = true

-- Padrao Swift: quatro espacos.
vim.opt_local.expandtab = true
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 4

-- Indentacao automatica durante a digitacao.
_G.SwiftIndentExpr = function()
  local linha = vim.v.lnum
  local anterior = vim.fn.prevnonblank(linha - 1)

  if anterior == 0 then
    return 0
  end

  local texto_anterior = vim.fn.getline(anterior)
  local texto_atual = vim.fn.getline(linha)

  local recuo = vim.fn.indent(anterior)
  local passo = vim.fn.shiftwidth()

  -- Aumentar o recuo apos abrir um bloco
  -- ou uma lista de argumentos.
  local ultimo = texto_anterior:gsub("%s+$", ""):sub(-1)

  if ultimo == "{" or ultimo == "(" or ultimo == "[" then
    recuo = recuo + passo
  end

  -- Reduzir o recuo nas linhas de fechamento.
  local primeiro = texto_atual:match("^%s*(.)")

  if primeiro == "}" or primeiro == ")" or primeiro == "]" then
    recuo = recuo - passo
  end

  return math.max(0, recuo)
end

vim.opt_local.indentexpr = "v:lua.SwiftIndentExpr()"
