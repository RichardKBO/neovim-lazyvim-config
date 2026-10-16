-- ========================================
-- RUBY - EXECUCAO GLOBAL F6
-- RuboCop + Ruby + Bundler
-- ========================================

local M = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Localizar a raiz do projeto a partir do arquivo atual.
local function encontrar_projeto(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  -- Priorizar projetos que possuem Gemfile.
  local gemfiles = vim.fs.find({
    "Gemfile",
    "gems.rb",
  }, {
    path = diretorio,
    upward = true,
  })

  if #gemfiles > 0 then
    return vim.fs.dirname(gemfiles[1]), gemfiles[1]
  end

  -- Outros marcadores de projetos Ruby.
  local raiz = vim.fs.root(arquivo, {
    "Rakefile",
    ".ruby-version",
    ".tool-versions",
    ".mise.toml",
    "mise.toml",
    ".git",
  })

  return raiz or diretorio, nil
end

-- Executar comando externo no contexto do projeto.
local function executar_comando(argumentos, diretorio)
  local iniciou, processo = pcall(vim.system, argumentos, {
    cwd = diretorio,
    text = true,
  })

  if not iniciou then
    return nil, tostring(processo)
  end

  local terminou, resultado = pcall(function()
    return processo:wait()
  end)

  if not terminou then
    return nil, tostring(resultado)
  end

  return resultado, nil
end

-- Resumir a saida de uma ferramenta para notificacoes.
local function resumir_saida(resultado)
  if not resultado then
    return ""
  end

  local saida = vim.trim((resultado.stderr or "") .. "\n" .. (resultado.stdout or ""))

  if #saida > 400 then
    return saida:sub(1, 400) .. "..."
  end

  return saida
end

-- Verificar se as dependencias do Bundler estao instaladas.
local function verificar_bundler(raiz, gemfile)
  if not gemfile then
    return true
  end

  if vim.fn.executable("bundle") ~= 1 then
    notificar("Projeto com Gemfile, mas Bundler nao foi encontrado no PATH.", vim.log.levels.ERROR)
    return false
  end

  local resultado, erro = executar_comando({
    "bundle",
    "check",
  }, raiz)

  if not resultado then
    notificar("Erro ao verificar Bundler: " .. erro, vim.log.levels.ERROR)
    return false
  end

  if resultado.code ~= 0 then
    notificar(
      "Dependencias Ruby nao instaladas. Execute bundle install na raiz do projeto.\n" .. resumir_saida(resultado),
      vim.log.levels.ERROR
    )
    return false
  end

  return true
end

-- Escolher o RuboCop do projeto quando disponivel.
local function encontrar_comando_rubocop(raiz, gemfile, arquivo)
  if gemfile then
    local resultado = executar_comando({
      "bundle",
      "exec",
      "rubocop",
      "--version",
    }, raiz)

    if resultado and resultado.code == 0 then
      return {
        "bundle",
        "exec",
        "rubocop",
        "--autocorrect",
        arquivo,
      }
    end
  end

  -- Fallback para o RuboCop instalado globalmente.
  if vim.fn.executable("rubocop") == 1 then
    return {
      "rubocop",
      "--autocorrect",
      arquivo,
    }
  end

  return nil
end

-- Executar RuboCop antes do programa Ruby.
local function executar_rubocop(arquivo, raiz, gemfile)
  local comando = encontrar_comando_rubocop(raiz, gemfile, arquivo)

  if not comando then
    notificar("RuboCop nao encontrado. O arquivo Ruby sera executado sem autocorrecao.", vim.log.levels.WARN)
    return
  end

  local resultado, erro = executar_comando(comando, raiz)

  if not resultado then
    notificar("Falha ao executar RuboCop: " .. erro, vim.log.levels.WARN)
    return
  end

  -- O RuboCop pode retornar codigo 1 quando restam
  -- infracoes que nao foram corrigidas automaticamente.
  if resultado.code ~= 0 then
    notificar(
      "RuboCop terminou com avisos ou erros (codigo " .. tostring(resultado.code) .. ").\n" .. resumir_saida(resultado),
      vim.log.levels.WARN
    )
  end
end

-- Recarregar o arquivo apos eventuais correcoes do RuboCop.
local function recarregar_arquivo(arquivo)
  local buffer = vim.fn.bufnr(arquivo)

  if buffer == -1 or not vim.api.nvim_buf_is_loaded(buffer) then
    return
  end

  if vim.bo[buffer].modified then
    notificar("O arquivo possui alteracoes nao salvas e nao sera recarregado.", vim.log.levels.WARN)
    return
  end

  local sucesso, erro = pcall(function()
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd("edit!")
    end)
  end)

  if not sucesso then
    notificar("Nao foi possivel recarregar o arquivo: " .. tostring(erro), vim.log.levels.WARN)
  end
end

-- Preparar ou reutilizar o terminal inferior.
local function preparar_terminal()
  local janela_editor = vim.api.nvim_get_current_win()
  local aba_atual = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

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
    vim.api.nvim_set_current_win(janela_terminal)
    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    vim.api.nvim_set_current_win(janela_editor)
    vim.cmd("botright 12split")
    janela_terminal = vim.api.nvim_get_current_win()
  end

  local buffer_antigo = vim.api.nvim_win_get_buf(janela_terminal)

  if vim.bo[buffer_antigo].buftype == "terminal" then
    local job_id = vim.b[buffer_antigo].terminal_job_id

    if job_id and job_id > 0 then
      pcall(vim.fn.jobstop, job_id)
    end
  end

  local novo_buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(janela_terminal, novo_buffer)
  vim.api.nvim_set_current_win(janela_terminal)

  vim.bo[novo_buffer].bufhidden = "hide"
  vim.bo[novo_buffer].swapfile = false

  return novo_buffer
end

function M.executar(arquivo)
  if not arquivo or arquivo == "" then
    notificar("Nenhum arquivo Ruby aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Arquivo Ruby nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve o arquivo com :w antes de executar.", vim.log.levels.WARN)
    return
  end

  -- Utilizar o Ruby disponivel no ambiente atual.
  local ruby = vim.fn.exepath("ruby")

  if ruby == "" then
    notificar("Executavel Ruby nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local raiz, gemfile = encontrar_projeto(arquivo)

  -- Validar dependencias antes de executar o projeto.
  if not verificar_bundler(raiz, gemfile) then
    return
  end

  -- Preservar o comportamento original: RuboCop antes do Ruby.
  executar_rubocop(arquivo, raiz, gemfile)

  -- Recarregar as possiveis correcoes no buffer correto.
  recarregar_arquivo(arquivo)

  -- Utilizar Bundler nos projetos que possuem Gemfile.
  local comando

  if gemfile then
    comando = "bundle exec ruby " .. vim.fn.shellescape(arquivo)
  else
    comando = vim.fn.shellescape(ruby) .. " " .. vim.fn.shellescape(arquivo)
  end

  local comando_shell = comando
    .. "; codigo=$?; "
    .. "printf '\\n\\nExecucao finalizada (codigo %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione qualquer tecla para fechar este terminal...'; "
    .. 'exit "$codigo"'

  preparar_terminal()

  local opcoes = {
    cwd = raiz,
  }

  -- Garantir que o Bundler use o Gemfile identificado.
  if gemfile then
    opcoes.env = {
      BUNDLE_GEMFILE = gemfile,
    }
  end

  local job_id = vim.fn.termopen({
    "bash",
    "-c",
    comando_shell,
  }, opcoes)

  if job_id <= 0 then
    notificar("Nao foi possivel iniciar o terminal Ruby.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
