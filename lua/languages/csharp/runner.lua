-- Execução de projetos C# pelo F6
local M = {}

local terminal_buffer = nil

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Localizar o projeto C# mais próximo do arquivo atual.
local function localizar_projeto(arquivo)
  local projetos = vim.fs.find(function(nome)
    return nome:match("%.csproj$") ~= nil
  end, {
    upward = true,
    path = vim.fn.fnamemodify(arquivo, ":h"),
  })

  return projetos[1]
end

-- Identificar namespace, classe e método Executar() no arquivo atual.
local function ler_classe_executora(arquivo)
  local linhas = vim.fn.readfile(arquivo)
  local conteudo = table.concat(linhas, "\n")

  local namespace = conteudo:match("namespace%s+([%w_%.]+)%s*[;{]")
  local classe = conteudo:match("public%s+class%s+([%a_][%w_]*)")
  local metodo_executar = conteudo:match("public%s+static%s+void%s+Executar%s*%(%s*%)")

  if not namespace or not classe or not metodo_executar then
    return nil
  end

  return namespace .. "." .. classe
end

-- Executar um comando e capturar sua saída.
local function executar_comando(comando, diretorio)
  return vim.fn.system(comando)
end

-- Preparar um terminal inferior sem substituir o buffer do código.
local function preparar_terminal()
  -- Guardar a janela do editor antes de procurar o terminal.
  local janela_editor = vim.api.nvim_get_current_win()
  local aba_atual = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

  -- Procurar um terminal apenas na aba atual.
  for _, janela in ipairs(vim.api.nvim_tabpage_list_wins(aba_atual)) do
    if janela ~= janela_editor then
      local buffer_atual = vim.api.nvim_win_get_buf(janela)

      if vim.bo[buffer_atual].buftype == "terminal" then
        janela_terminal = janela
        break
      end
    end
  end

  if janela_terminal then
    -- Reutilizar o espaço da janela de terminal existente.
    vim.api.nvim_set_current_win(janela_terminal)
    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    -- Criar uma divisão inferior sem mexer no buffer do editor.
    vim.api.nvim_set_current_win(janela_editor)
    vim.cmd("botright 12split")
    janela_terminal = vim.api.nvim_get_current_win()
  end

  -- Guardar o buffer antigo antes de criar o novo terminal.
  local buffer_antigo = vim.api.nvim_win_get_buf(janela_terminal)

  if vim.bo[buffer_antigo].buftype == "terminal" then
    local job_id = vim.b[buffer_antigo].terminal_job_id

    -- Interromper a execução anterior, caso ainda esteja ativa.
    if job_id then
      pcall(vim.fn.jobstop, job_id)
    end
  end

  -- Criar um buffer novo exclusivamente para a execução.
  -- Não usar :enew, pois ele pode substituir o buffer errado.
  local novo_buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(janela_terminal, novo_buffer)
  vim.api.nvim_set_current_win(janela_terminal)

  terminal_buffer = novo_buffer

  vim.bo[novo_buffer].bufhidden = "hide"
  vim.bo[novo_buffer].swapfile = false

  return novo_buffer
end

function M.executar(arquivo)
  if not arquivo or arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Salve o arquivo C# antes de executá-lo.", vim.log.levels.ERROR)
    return
  end

  -- Impedir execução com alterações não salvas no arquivo atual.
  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve as alterações antes de executar o C#.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  local projeto = localizar_projeto(arquivo)

  if not projeto then
    notificar("Nenhum arquivo .csproj encontrado.", vim.log.levels.ERROR)
    return
  end

  projeto = vim.fn.fnamemodify(projeto, ":p")

  local diretorio_projeto = vim.fn.fnamemodify(projeto, ":h")

  -- Verificar se o projeto permite executar classes individuais.
  local class_runner = executar_comando({
    "dotnet",
    "msbuild",
    projeto,
    "-getProperty:EnableClassRunner",
  }, diretorio_projeto)

  if vim.v.shell_error ~= 0 then
    notificar("Não foi possível consultar EnableClassRunner:\n" .. class_runner, vim.log.levels.ERROR)
    return
  end

  class_runner = vim.trim(class_runner)

  local classe_completa = nil

  if class_runner:lower() == "true" then
    classe_completa = ler_classe_executora(arquivo)

    if not classe_completa then
      notificar(
        "Não foi possível identificar namespace, classe pública e método Executar() no arquivo atual.",
        vim.log.levels.ERROR
      )
      return
    end
  end

  -- Compilar o projeto em modo Debug.
  notificar("Compilando projeto C#...")

  local resultado = executar_comando({
    "dotnet",
    "build",
    projeto,
    "--configuration",
    "Debug",
  }, diretorio_projeto)

  if vim.v.shell_error ~= 0 then
    notificar("Falha na compilação:\n" .. resultado, vim.log.levels.ERROR)
    return
  end

  -- Consultar o framework de destino.
  local framework = executar_comando({
    "dotnet",
    "msbuild",
    projeto,
    "-getProperty:TargetFramework",
  }, diretorio_projeto)

  if vim.v.shell_error ~= 0 then
    notificar("Não foi possível identificar o TargetFramework:\n" .. framework, vim.log.levels.ERROR)
    return
  end

  framework = vim.trim(framework)

  if framework == "" or framework:find("\n", 1, true) then
    notificar("TargetFramework vazio ou com múltiplos valores.", vim.log.levels.ERROR)
    return
  end

  local nome_projeto = vim.fn.fnamemodify(projeto, ":t:r")

  local dll = diretorio_projeto .. "/bin/Debug/" .. framework .. "/" .. nome_projeto .. ".dll"

  if vim.fn.filereadable(dll) ~= 1 then
    notificar("DLL compilada não encontrada: " .. dll, vim.log.levels.ERROR)
    return
  end

  -- Montar o comando de execução.
  local comando = { "dotnet", dll }

  if classe_completa then
    table.insert(comando, "--executar")
    table.insert(comando, classe_completa)

    notificar("Executando a classe: " .. classe_completa)
  else
    notificar("Executando o projeto C# normalmente.")
  end

  -- Escapar os argumentos para execução segura pelo Bash.
  local argumentos = {}

  for _, argumento in ipairs(comando) do
    table.insert(argumentos, vim.fn.shellescape(argumento))
  end

  local comando_shell = table.concat(argumentos, " ")
    .. "; codigo=$?; printf '\\n\\nExecução finalizada (código %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione qualquer tecla para fechar este terminal...'; "
    .. 'exit "$codigo"'

  -- Preparar o terminal inferior reutilizável.
  preparar_terminal()

  local job_id = vim.fn.termopen({ "bash", "-lc", comando_shell }, {
    cwd = diretorio_projeto,
  })

  if job_id <= 0 then
    notificar("Não foi possível iniciar o terminal C#.", vim.log.levels.ERROR)
    return
  end

  -- Entrar no terminal para acompanhar a execução.
  vim.cmd("startinsert")
end

return M
