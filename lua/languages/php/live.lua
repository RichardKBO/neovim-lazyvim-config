-- ========================================
-- PHP - LIVE SERVER / BROWSERSYNC
-- ========================================

local M = {}

local processo = nil

local function avisar(mensagem, nivel)
  vim.notify(
    mensagem,
    nivel or vim.log.levels.INFO,
    { title = "PHP - Live Server" }
  )
end

local function esta_ativo(registro)
  return registro
    and registro.id
    and vim.fn.jobwait({ registro.id }, 0)[1] == -1
end

local function porta_disponivel(porta)
  local uv = vim.uv or vim.loop
  local socket = uv.new_tcp()

  if not socket then
    return false
  end

  local sucesso, disponivel = pcall(function()
    local bind_ok = socket:bind("127.0.0.1", porta)

    if not bind_ok then
      return false
    end

    local listen_ok = socket:listen(1, function() end)

    return listen_ok ~= nil and listen_ok ~= false
  end)

  socket:close()

  return sucesso and disponivel == true
end

function M.iniciar(raiz, url_php)
  if esta_ativo(processo) then
    if processo.raiz == raiz then
      return true
    end

    avisar(
      "Live Server de outro projeto ainda esta ativo.",
      vim.log.levels.WARN
    )
    return false
  end

  if not porta_disponivel(3000) then
    avisar(
      "Porta 3000 ocupada. Live Server nao iniciado.",
      vim.log.levels.ERROR
    )
    return false
  end

  local executavel = vim.fn.exepath("browser-sync")

  if executavel == "" then
    avisar(
      "BrowserSync nao encontrado no PATH.",
      vim.log.levels.ERROR
    )
    return false
  end

  local registro = {
    id = nil,
    raiz = raiz,
    encerrando = false,
    callbacks = {},
  }

  local ultima_saida = ""

  local id = vim.fn.jobstart({
    executavel,
    "start",
    "--proxy", url_php,
    "--port", "3000",
    "--host", "127.0.0.1",
    "--listen", "127.0.0.1",
    "--files",
    "public/**/*",
    "src/**/*",
    "resources/**/*",
    "templates/**/*",
    "views/**/*",
    "assets/**/*",
    "--open", "local",
    "--no-ui",
    "--no-online",
    "--no-notify",
    "--no-ghost-mode",
  }, {
    cwd = raiz,

    on_stderr = function(_, linhas)
      for _, linha in ipairs(linhas or {}) do
        if linha ~= "" then
          ultima_saida = linha
        end
      end
    end,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if processo == registro then
          processo = nil
        end

        if not registro.encerrando and codigo ~= 0 then
          avisar(
            "BrowserSync falhou: " .. ultima_saida,
            vim.log.levels.ERROR
          )
        end

        for _, callback in ipairs(registro.callbacks) do
          callback()
        end
      end)
    end,
  })

  if id <= 0 then
    avisar(
      "Nao foi possivel iniciar o BrowserSync.",
      vim.log.levels.ERROR
    )
    return false
  end

  registro.id = id
  processo = registro

  avisar("Inicializacao do Live Server solicitada.")
  return true
end

function M.parar(ao_encerrar)
  local registro = processo

  if not esta_ativo(registro) then
    processo = nil

    if ao_encerrar then
      vim.schedule(ao_encerrar)
    end

    return true
  end

  if ao_encerrar then
    table.insert(registro.callbacks, ao_encerrar)
  end

  if registro.encerrando then
    return true
  end

  registro.encerrando = true

  if vim.fn.jobstop(registro.id) ~= 1 then
    registro.encerrando = false
    registro.callbacks = {}

    avisar(
      "Falha ao encerrar o BrowserSync.",
      vim.log.levels.ERROR
    )
    return false
  end

  return true
end

function M.ativo()
  return esta_ativo(processo) or false
end

return M
