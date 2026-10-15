-- Runner Rust modularizado
-- F6 executa a crate correspondente ao arquivo atual
-- Suporta projetos Cargo independentes e workspaces

local M = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Localizar o manifesto mais proximo do arquivo.
local function localizar_manifesto(arquivo)
  local resultados = vim.fs.find("Cargo.toml", {
    upward = true,
    path = vim.fs.dirname(arquivo),
  })

  return resultados[1]
end

-- Consultar o Cargo para identificar o projeto corretamente.
local function obter_metadata(cargo, manifesto)
  local resultado = vim.fn.system({
    cargo,
    "metadata",
    "--no-deps",
    "--format-version",
    "1",
    "--manifest-path",
    manifesto,
  })

  if vim.v.shell_error ~= 0 then
    notificar("Erro ao consultar Cargo:\n" .. resultado, vim.log.levels.ERROR)
    return nil
  end

  local ok, metadata = pcall(vim.json.decode, resultado)

  if not ok or type(metadata) ~= "table" then
    notificar("Resposta invalida do Cargo.", vim.log.levels.ERROR)
    return nil
  end

  return metadata
end

-- Encontrar o package correspondente ao manifesto.
local function localizar_package(metadata, manifesto)
  local caminho = vim.fs.normalize(manifesto)

  for _, package in ipairs(metadata.packages or {}) do
    if vim.fs.normalize(package.manifest_path) == caminho then
      return package
    end
  end

  return nil
end

-- Abrir ou reutilizar o terminal inferior do Neovim.
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

  vim.bo[novo_buffer].bufhidden = "wipe"
  vim.bo[novo_buffer].swapfile = false
end

-- Executar um binario selecionado do package.
local function executar_binario(cargo, manifesto, binario)
  local diretorio = vim.fs.dirname(manifesto)

  local comando = vim.fn.shellescape(cargo)
    .. " run --manifest-path "
    .. vim.fn.shellescape(manifesto)
    .. " --bin "
    .. vim.fn.shellescape(binario.name)

  local comando_shell = comando
    .. "; codigo=$?; "
    .. "printf '\\n\\nExecucao finalizada (codigo %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione qualquer tecla para fechar este terminal...'; "
    .. 'exit "$codigo"'

  preparar_terminal()

  local job_id = vim.fn.termopen({
    "bash",
    "-lc",
    comando_shell,
  }, {
    cwd = diretorio,
  })

  if job_id <= 0 then
    notificar("Nao foi possivel iniciar o terminal Rust.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

function M.executar(arquivo)
  if not arquivo or arquivo == "" then
    notificar("Nenhum arquivo Rust aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Arquivo Rust nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve o arquivo com :w antes de executar.", vim.log.levels.WARN)
    return
  end

  local cargo = vim.fn.exepath("cargo")

  if cargo == "" then
    notificar("Cargo nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local manifesto = localizar_manifesto(arquivo)

  if not manifesto then
    notificar("Cargo.toml nao encontrado. Este runner executa projetos Cargo.", vim.log.levels.WARN)
    return
  end

  local metadata = obter_metadata(cargo, manifesto)

  if not metadata then
    return
  end

  local package = localizar_package(metadata, manifesto)

  if not package then
    notificar("O manifesto encontrado nao representa uma crate executavel.", vim.log.levels.ERROR)
    return
  end

  -- Identificar os binarios existentes na crate.
  local binarios = {}

  for _, target in ipairs(package.targets or {}) do
    for _, kind in ipairs(target.kind or {}) do
      if kind == "bin" then
        table.insert(binarios, target)
        break
      end
    end
  end

  if #binarios == 0 then
    notificar(
      "Esta crate nao possui binario. Para bibliotecas, utilize cargo test ou cargo check.",
      vim.log.levels.WARN
    )
    return
  end

  -- Identificar o binario correspondente ao arquivo aberto.
  local arquivo_normalizado = vim.fs.normalize(arquivo)

  for _, binario in ipairs(binarios) do
    if vim.fs.normalize(binario.src_path) == arquivo_normalizado then
      executar_binario(cargo, manifesto, binario)
      return
    end
  end

  -- Com apenas um binario, executar automaticamente.
  if #binarios == 1 then
    executar_binario(cargo, manifesto, binarios[1])
    return
  end

  -- Se houver varios binarios, permitir escolher.
  local janela_editor = vim.api.nvim_get_current_win()

  vim.ui.select(binarios, {
    prompt = "Selecione o binario Rust:",

    format_item = function(item)
      return item.name
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    if vim.api.nvim_win_is_valid(janela_editor) then
      vim.api.nvim_set_current_win(janela_editor)
    end

    executar_binario(cargo, manifesto, escolhido)
  end)
end

return M
