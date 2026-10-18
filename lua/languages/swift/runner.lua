-- ========================================
-- SWIFT - RUNNER
-- Execucao de projetos SwiftPM pelo F6
-- ========================================

local M = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Encontrar o Package.swift mais proximo do arquivo.
local function localizar_manifesto(arquivo)
  local resultados = vim.fs.find("Package.swift", {
    upward = true,
    path = vim.fs.dirname(arquivo),
  })

  return resultados[1]
end

-- Consultar os metadados reais do SwiftPM.
local function obter_metadata(swift, raiz)
  local resultado = vim
    .system({
      swift,
      "package",
      "describe",
      "--type",
      "json",
    }, {
      cwd = raiz,
      text = true,
    })
    :wait()

  if resultado.code ~= 0 then
    notificar(
      "SwiftPM: erro ao consultar projeto:\n" .. (resultado.stderr or resultado.stdout or ""),
      vim.log.levels.ERROR
    )
    return nil
  end

  local ok, metadata = pcall(vim.json.decode, resultado.stdout or "")

  if not ok or type(metadata) ~= "table" then
    notificar("SwiftPM: metadados invalidos.", vim.log.levels.ERROR)
    return nil
  end

  return metadata
end

-- Identificar os produtos executaveis.
local function obter_executaveis(metadata)
  local executaveis = {}

  for _, produto in ipairs(metadata.products or {}) do
    if type(produto.type) == "table" and produto.type.executable ~= nil then
      table.insert(executaveis, produto)
    end
  end

  return executaveis
end

-- Descobrir qual produto contem o arquivo atual.
local function localizar_produto_do_arquivo(metadata, executaveis, raiz, arquivo)
  local arquivo_atual = vim.fs.normalize(arquivo)
  local produtos_encontrados = {}

  for _, target in ipairs(metadata.targets or {}) do
    if target.type == "executable" then
      local pertence = false

      for _, fonte in ipairs(target.sources or {}) do
        local caminho = vim.fs.normalize(vim.fs.joinpath(raiz, target.path, fonte))

        if caminho == arquivo_atual then
          pertence = true
          break
        end
      end

      if pertence then
        for _, produto in ipairs(executaveis) do
          for _, nome_target in ipairs(produto.targets or {}) do
            if nome_target == target.name then
              table.insert(produtos_encontrados, produto)
              break
            end
          end
        end
      end
    end
  end

  if #produtos_encontrados == 1 then
    return produtos_encontrados[1]
  end

  return nil
end

-- Abrir ou reutilizar somente um terminal do runner Swift.
local function preparar_terminal()
  local janela_editor = vim.api.nvim_get_current_win()
  local aba_atual = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

  -- Procurar exclusivamente terminais criados pelo runner Swift.
  -- Terminais de outras ferramentas nao devem ser reutilizados.
  for _, janela in ipairs(vim.api.nvim_tabpage_list_wins(aba_atual)) do
    if janela ~= janela_editor then
      local buffer = vim.api.nvim_win_get_buf(janela)

      if vim.bo[buffer].buftype == "terminal" and vim.b[buffer].swift_runner_terminal == true then
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

  -- Encerrar somente o processo pertencente ao runner Swift.
  if vim.bo[buffer_antigo].buftype == "terminal" and vim.b[buffer_antigo].swift_runner_terminal == true then
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

  return novo_buffer
end

-- Compilar e executar o produto selecionado.
local function executar_produto(swift, raiz, produto)
  local comando_swift = vim.fn.shellescape(swift)
  local nome_produto = vim.fn.shellescape(produto.name)

  local comando = comando_swift
    .. " build --product "
    .. nome_produto
    .. " && diretorio_binario=$("
    .. comando_swift
    .. " build --show-bin-path)"
    .. ' && "$diretorio_binario"/'
    .. nome_produto

  local comando_shell = comando
    .. "; codigo=$?; "
    .. "printf '\\nExecucao Swift finalizada (codigo %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione qualquer tecla para fechar este terminal...'; "
    .. 'exit "$codigo"'

  local buffer_terminal = preparar_terminal()

  local job_id = vim.fn.termopen({
    "bash",
    "-lc",
    comando_shell,
  }, {
    cwd = raiz,
  })

  if job_id <= 0 then
    notificar("Nao foi possivel iniciar o terminal Swift.", vim.log.levels.ERROR)
    return
  end

  -- Identificar o terminal como propriedade do runner Swift.
  -- Somente terminais com esta marca podem ser reutilizados pelo F6.
  vim.b[buffer_terminal].swift_runner_terminal = true

  vim.cmd("startinsert")
end

function M.executar(arquivo)
  if not arquivo or arquivo == "" then
    notificar("Nenhum arquivo Swift aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Arquivo Swift nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve o arquivo com :w antes de executar.", vim.log.levels.WARN)
    return
  end

  local swift = vim.fn.exepath("swift")

  if swift == "" then
    notificar("Swift nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local manifesto = localizar_manifesto(arquivo)

  if not manifesto then
    notificar("Package.swift nao encontrado. Este runner executa projetos SwiftPM.", vim.log.levels.WARN)
    return
  end

  local raiz = vim.fs.dirname(manifesto)
  local metadata = obter_metadata(swift, raiz)

  if not metadata then
    return
  end

  local executaveis = obter_executaveis(metadata)

  if #executaveis == 0 then
    notificar("Este pacote Swift nao possui produto executavel.", vim.log.levels.WARN)
    return
  end

  local produto = localizar_produto_do_arquivo(metadata, executaveis, raiz, arquivo)

  if produto then
    executar_produto(swift, raiz, produto)
    return
  end

  if #executaveis == 1 then
    executar_produto(swift, raiz, executaveis[1])
    return
  end

  local janela_editor = vim.api.nvim_get_current_win()

  vim.ui.select(executaveis, {
    prompt = "Selecione o executavel Swift:",

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

    executar_produto(swift, raiz, escolhido)
  end)
end

return M
