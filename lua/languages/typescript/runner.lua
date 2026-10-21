-- ========================================
-- TYPESCRIPT - RUNNER CONTEXTUAL
-- ========================================

local M = {}

local terminal = {
  buffer = nil,
  job = nil,
}

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, {
    "package.json",
    "tsconfig.json",
  }) or vim.fs.dirname(arquivo)
end

local function encontrar_tsx(raiz)
  local executavel = vim.fs.joinpath(raiz, "node_modules", ".bin", "tsx")

  if vim.fn.executable(executavel) == 1 then
    return executavel
  end

  return nil
end

local function limpar_terminal_anterior()
  if terminal.job then
    local resultado = vim.fn.jobwait({ terminal.job }, 0)

    if resultado[1] == -1 then
      pcall(vim.fn.jobstop, terminal.job)
    end
  end

  if terminal.buffer and vim.api.nvim_buf_is_valid(terminal.buffer) then
    pcall(vim.api.nvim_buf_delete, terminal.buffer, {
      force = true,
    })
  end

  terminal.buffer = nil
  terminal.job = nil
end

function M.executar(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    vim.notify("Nenhum arquivo TypeScript aberto.", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified then
    vim.notify("Salve o arquivo TypeScript antes de executar.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    vim.notify("Arquivo TypeScript não encontrado.", vim.log.levels.ERROR)
    return
  end

  local raiz = encontrar_raiz(arquivo)
  local tsx = encontrar_tsx(raiz)

  if not tsx then
    vim.notify("TSX não encontrado no projeto: " .. raiz .. "\nInstale com: npm install -D tsx", vim.log.levels.ERROR)
    return
  end

  limpar_terminal_anterior()

  vim.notify("TypeScript: " .. vim.fn.fnamemodify(arquivo, ":t") .. "\nProjeto: " .. raiz, vim.log.levels.INFO)

  vim.cmd("botright 12new")

  local buffer = vim.api.nvim_get_current_buf()

  local sucesso, job = pcall(vim.fn.termopen, { tsx, arquivo }, { cwd = raiz })

  if not sucesso or type(job) ~= "number" or job <= 0 then
    vim.api.nvim_buf_delete(buffer, { force = true })
    vim.notify("Falha ao executar TypeScript.", vim.log.levels.ERROR)
    return
  end

  terminal.buffer = buffer
  terminal.job = job

  vim.cmd("startinsert")
end

return M
