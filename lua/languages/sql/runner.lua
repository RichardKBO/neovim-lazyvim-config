-- Executor modular SQL
-- Suporta SQLite e MySQL pelo F6.
-- Reutiliza um único terminal inferior por aba.

local M = {}

local terminais = {}

local function notificar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

-- Localizar bancos SQLite na pasta do arquivo.
local function localizar_bancos(diretorio)
  local bancos = {}

  for _, nome in ipairs(vim.fn.readdir(diretorio)) do
    if nome:match("%.db$") or nome:match("%.sqlite$") or nome:match("%.sqlite3$") then
      local caminho = diretorio .. "/" .. nome

      if vim.fn.filereadable(caminho) == 1 then
        table.insert(bancos, caminho)
      end
    end
  end

  table.sort(bancos)
  return bancos
end

-- Preparar uma única janela inferior para o terminal SQL.
local function preparar_terminal()
  local janela_editor = vim.api.nvim_get_current_win()
  local aba = vim.api.nvim_get_current_tabpage()
  local janela_terminal = terminais[aba]

  -- Reutilizar apenas a janela criada pelo executor SQL.
  if
    janela_terminal
    and vim.api.nvim_win_is_valid(janela_terminal)
    and vim.api.nvim_win_get_tabpage(janela_terminal) == aba
  then
    vim.api.nvim_set_current_win(janela_terminal)
    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    vim.api.nvim_set_current_win(janela_editor)
    vim.cmd("botright 12split")

    janela_terminal = vim.api.nvim_get_current_win()
    terminais[aba] = janela_terminal
  end

  -- Encerrar o processo anterior antes de reutilizar a janela.
  local buffer_antigo = vim.api.nvim_win_get_buf(janela_terminal)

  if vim.bo[buffer_antigo].buftype == "terminal" then
    local job_id = vim.b[buffer_antigo].terminal_job_id

    if job_id then
      pcall(vim.fn.jobstop, job_id)
    end
  end

  -- Criar um buffer novo para cada execução.
  local novo_buffer = vim.api.nvim_create_buf(false, true)

  vim.bo[novo_buffer].bufhidden = "wipe"
  vim.bo[novo_buffer].swapfile = false

  vim.api.nvim_win_set_buf(janela_terminal, novo_buffer)

  return janela_editor
end

-- Executar um comando no terminal inferior.
local function executar_terminal(comando, diretorio)
  local janela_editor = preparar_terminal()

  local job = vim.fn.termopen({
    "bash",
    "-lc",
    comando,
  }, {
    cwd = diretorio,
  })

  if job <= 0 then
    notificar("Não foi possível iniciar o terminal SQL.", vim.log.levels.ERROR)

    vim.api.nvim_set_current_win(janela_editor)
    return
  end

  -- Manter o foco no terminal para interação com MySQL.
  vim.cmd("startinsert")
end

-- Executar arquivo SQL no SQLite.
local function executar_sqlite(arquivo, diretorio)
  local bancos = localizar_bancos(diretorio)

  if #bancos == 0 then
    notificar("Nenhum banco SQLite encontrado na pasta do arquivo.", vim.log.levels.ERROR)
    return
  end

  local function executar(banco)
    if not banco then
      return
    end

    local comando = "sqlite3 " .. vim.fn.shellescape(banco) .. " < " .. vim.fn.shellescape(arquivo)

    executar_terminal(comando, diretorio)
  end

  if #bancos == 1 then
    executar(bancos[1])
  else
    vim.ui.select(bancos, {
      prompt = "Selecione o banco SQLite:",
      format_item = function(banco)
        return vim.fn.fnamemodify(banco, ":t")
      end,
    }, executar)
  end
end

-- Executar arquivo SQL no MySQL.
local function executar_mysql(arquivo, diretorio)
  -- Manter usuário root e solicitação interativa de senha.
  local comando = "mysql -u root -p < " .. vim.fn.shellescape(arquivo)

  executar_terminal(comando, diretorio)
end

-- Identificar SQLite ou MySQL pelo diretório.
local function identificar_ambiente(diretorio)
  local partes = vim.split(vim.fs.normalize(diretorio), "/", { plain = true })

  for _, parte in ipairs(partes) do
    if parte == "SQLite" then
      return "sqlite"
    elseif parte == "MySQL" then
      return "mysql"
    end
  end

  return nil
end

-- Executar o arquivo SQL atualmente aberto.
function M.executar(arquivo)
  if not arquivo or arquivo == "" or vim.fn.filereadable(arquivo) ~= 1 then
    notificar("Salve o arquivo SQL antes de executar.", vim.log.levels.ERROR)
    return
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  -- Impedir execução de alterações não salvas.
  local buffer = vim.fn.bufnr(arquivo)

  if buffer ~= -1 and vim.bo[buffer].modified then
    notificar("Salve as alterações antes de executar o SQL.", vim.log.levels.WARN)
    return
  end

  local diretorio = vim.fn.fnamemodify(arquivo, ":h")
  local ambiente = identificar_ambiente(diretorio)

  if ambiente == "sqlite" then
    executar_sqlite(arquivo, diretorio)
  elseif ambiente == "mysql" then
    executar_mysql(arquivo, diretorio)
  else
    notificar("Não foi possível identificar SQLite ou MySQL pelo diretório.", vim.log.levels.WARN)
  end
end

return M
