-- Execucao de arquivos Ruby pelo F6
-- Terminal inferior reutilizavel, seguindo o padrao do C#

local M = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Preparar ou reutilizar o terminal inferior.
local function preparar_terminal()
  local janela_editor = vim.api.nvim_get_current_win()
  local aba_atual = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

  -- Procurar um terminal existente somente na aba atual.
  for _, janela in ipairs(vim.api.nvim_tabpage_list_wins(aba_atual)) do
    if janela ~= janela_editor then
      local buffer = vim.api.nvim_win_get_buf(janela)

      if vim.bo[buffer].buftype == "terminal" then
        janela_terminal = janela
        break
      end
    end
  end

  if janela_terminal then
    -- Reutilizar a janela de terminal existente.
    vim.api.nvim_set_current_win(janela_terminal)
    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    -- Criar terminal horizontal na parte inferior.
    vim.api.nvim_set_current_win(janela_editor)
    vim.cmd("botright 12split")
    janela_terminal = vim.api.nvim_get_current_win()
  end

  local buffer_antigo = vim.api.nvim_win_get_buf(janela_terminal)

  -- Interromper uma execucao anterior nesse terminal.
  if vim.bo[buffer_antigo].buftype == "terminal" then
    local job_id = vim.b[buffer_antigo].terminal_job_id

    if job_id and job_id > 0 then
      pcall(vim.fn.jobstop, job_id)
    end
  end

  -- Criar um buffer exclusivo para a nova execucao.
  local novo_buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(janela_terminal, novo_buffer)
  vim.api.nvim_set_current_win(janela_terminal)

  vim.bo[novo_buffer].bufhidden = "hide"
  vim.bo[novo_buffer].swapfile = false

  return novo_buffer
end

function M.executar(arquivo)
  -- Validar o arquivo atual.
  if not arquivo or arquivo == "" then
    notificar("Nenhum arquivo Ruby aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Arquivo Ruby nao encontrado.", vim.log.levels.ERROR)
    return
  end

  -- Impedir execucao com alteracoes nao salvas.
  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve o arquivo com :w antes de executar.", vim.log.levels.WARN)
    return
  end

  -- Identificar o Ruby ativo no ambiente.
  local ruby = vim.fn.exepath("ruby")

  if ruby == "" then
    notificar("Executavel Ruby nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local diretorio = vim.fn.fnamemodify(arquivo, ":h")

  -- Preservar a correcao automatica existente do RuboCop.
  if vim.fn.executable("rubocop") == 1 then
    vim.fn.system({
      "rubocop",
      "--autocorrect",
      arquivo,
    })

    -- Recarregar possiveis correcoes no editor.
    vim.cmd("edit!")
  end

  -- Montar o comando com o Ruby e o arquivo atuais.
  local comando = vim.fn.shellescape(ruby) .. " " .. vim.fn.shellescape(arquivo)

  -- Exibir o codigo de saida e aguardar uma tecla.
  local comando_shell = comando
    .. "; codigo=$?; "
    .. "printf '\\n\\nExecucao finalizada (codigo %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione qualquer tecla para fechar este terminal...'; "
    .. 'exit "$codigo"'

  -- Preparar terminal inferior reutilizavel.
  preparar_terminal()

  -- Executar no terminal integrado do Neovim.
  local job_id = vim.fn.termopen({
    "bash",
    "-lc",
    comando_shell,
  }, {
    cwd = diretorio,
  })

  if job_id <= 0 then
    notificar("Nao foi possivel iniciar o terminal Ruby.", vim.log.levels.ERROR)
    return
  end

  -- Entrar automaticamente no terminal.
  vim.cmd("startinsert")
end

return M
