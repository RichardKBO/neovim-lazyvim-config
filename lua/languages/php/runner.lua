-- ========================================
-- PHP - EXECUCAO GLOBAL F6
-- ========================================
-- Executar o arquivo PHP atualmente aberto.
-- Validar sintaxe antes da execucao.
-- Reconhecer projetos Composer automaticamente.

local M = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, {
    "composer.json",
    ".git",
  }) or vim.fs.dirname(arquivo)
end

function M.executar(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    notificar("Nenhum arquivo PHP aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "php" then
    notificar("O arquivo atual nao e PHP.", vim.log.levels.WARN)
    return
  end

  if vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Arquivo PHP nao encontrado. Salve antes de executar.", vim.log.levels.ERROR)
    return
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve o arquivo com :w antes de executar.", vim.log.levels.WARN)
    return
  end

  local php = vim.fn.exepath("php")

  if php == "" then
    notificar("PHP nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local raiz = encontrar_raiz(arquivo)

  -- Passar executavel e arquivo como argumentos.
  -- Evitar interpolacao de caminhos no shell.
  local script = [[
"$1" -l "$2" && "$1" "$2"
codigo=$?
printf '\nExecucao finalizada (codigo %s).\n' "$codigo"
read -r -n 1 -s -p 'Pressione uma tecla para finalizar...'
exit "$codigo"
]]

  vim.cmd("botright 12new")

  local sucesso, job = pcall(vim.fn.termopen, {
    "bash",
    "-c",
    script,
    "php-runner",
    php,
    arquivo,
  }, {
    cwd = raiz,
  })

  if not sucesso or type(job) ~= "number" or job <= 0 then
    vim.cmd("close")
    notificar("Falha ao iniciar o terminal PHP.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
