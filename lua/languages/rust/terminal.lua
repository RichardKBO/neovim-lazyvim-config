local M = {}

-- Terminal exclusivo para comandos Cargo.
-- Mantem a configuracao de execucao separada do menu.

local function preparar_terminal()
  local aba = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

  -- Procurar um terminal Cargo ja existente na aba.
  for _, janela in ipairs(vim.api.nvim_tabpage_list_wins(aba)) do
    local buffer = vim.api.nvim_win_get_buf(janela)

    if vim.b[buffer].rust_cargo_terminal then
      janela_terminal = janela
      break
    end
  end

  if janela_terminal then
    vim.api.nvim_set_current_win(janela_terminal)
    vim.api.nvim_win_set_height(janela_terminal, 12)
  else
    vim.cmd("botright 12split")
    janela_terminal = vim.api.nvim_get_current_win()
  end

  local buffer_antigo = vim.api.nvim_win_get_buf(janela_terminal)

  -- Encerrar o processo anterior, se ainda estiver ativo.
  if vim.bo[buffer_antigo].buftype == "terminal" then
    local job = vim.b[buffer_antigo].terminal_job_id

    if job and job > 0 then
      pcall(vim.fn.jobstop, job)
    end
  end

  local novo_buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_win_set_buf(janela_terminal, novo_buffer)

  vim.b[novo_buffer].rust_cargo_terminal = true
  vim.bo[novo_buffer].bufhidden = "wipe"
  vim.bo[novo_buffer].swapfile = false

  return janela_terminal
end

-- Executar argumentos sem concatenar entrada do usuario
-- diretamente em um comando de shell.
function M.executar(argumentos, diretorio)
  if type(argumentos) ~= "table" or #argumentos == 0 then
    return nil, "Nenhum comando informado."
  end

  if not diretorio or vim.fn.isdirectory(diretorio) ~= 1 then
    return nil, "Diretorio Cargo invalido."
  end

  local partes = {}

  for _, argumento in ipairs(argumentos) do
    if type(argumento) ~= "string" then
      return nil, "Argumento de comando invalido."
    end

    table.insert(partes, vim.fn.shellescape(argumento))
  end

  local comando = table.concat(partes, " ")

  local script = comando
    .. "; codigo=$?; "
    .. "printf '\\n\\nCargo finalizado (codigo %s).\\n' \"$codigo\"; "
    .. "read -n 1 -s -r -p 'Pressione uma tecla para finalizar...'; "
    .. 'exit "$codigo"'

  preparar_terminal()

  local job = vim.fn.termopen({
    "bash",
    "-lc",
    script,
  }, {
    cwd = diretorio,
  })

  if job <= 0 then
    return nil, "Nao foi possivel iniciar o terminal."
  end

  vim.cmd("startinsert")

  return true
end

return M
