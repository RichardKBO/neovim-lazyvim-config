-- ========================================
-- TYPESCRIPT - DEBUGGER CONTEXTUAL
-- ========================================

local M = {}

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "TypeScript - DAP",
  })
end

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, {
    "package.json",
    "tsconfig.json",
  }) or vim.fs.dirname(arquivo)
end

function M.depurar(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    avisar("Nenhum arquivo TypeScript aberto.", vim.log.levels.WARN)
    return
  end

  if vim.bo.modified then
    avisar("Salve o arquivo antes de depurar.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    avisar("Arquivo TypeScript não encontrado.", vim.log.levels.ERROR)
    return
  end

  if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "ts" then
    avisar("O debugger atual aceita arquivos .ts.", vim.log.levels.WARN)
    return
  end

  local raiz = encontrar_raiz(arquivo)

  local tsx = vim.fs.joinpath(raiz, "node_modules", "tsx", "package.json")

  if vim.fn.filereadable(tsx) ~= 1 then
    avisar("TSX local não encontrado.\nProjeto: " .. raiz .. "\nInstale com: npm install -D tsx", vim.log.levels.ERROR)
    return
  end

  local node = vim.fn.exepath("node")

  if node == "" then
    avisar("Node.js não encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local dap = require("dap")

  if not dap.adapters["pwa-node"] then
    avisar("Adaptador pwa-node não configurado.", vim.log.levels.ERROR)
    return
  end

  if dap.session() then
    avisar("Encerre a sessão DAP anterior antes de iniciar outra.", vim.log.levels.WARN)
    return
  end

  local configuracao = {
    type = "pwa-node",
    request = "launch",

    name = "TypeScript - " .. vim.fn.fnamemodify(arquivo, ":t"),

    program = arquivo,
    cwd = raiz,

    runtimeExecutable = node,
    runtimeArgs = {
      "--import=tsx",
    },

    sourceMaps = true,

    skipFiles = {
      "<node_internals>/**",
      "**/node_modules/**",
    },

    resolveSourceMapLocations = {
      raiz .. "/**",
      "!**/node_modules/**",
    },
  }

  avisar("Arquivo: " .. arquivo .. "\nProjeto: " .. raiz .. "\nNode: " .. node)

  dap.run(configuracao)
end

return M
