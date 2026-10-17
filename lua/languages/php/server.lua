-- ========================================
-- PHP - SERVIDOR HTTP
-- ========================================

local M = {}

local servidor = nil
local endereco = "127.0.0.1:8765"

local function avisar(mensagem, nivel)
  vim.notify(
    mensagem,
    nivel or vim.log.levels.INFO,
    { title = "PHP - Servidor HTTP" }
  )
end

local function esta_ativo()
  if not servidor then
    return false
  end

  return vim.fn.jobwait({ servidor.id }, 0)[1] == -1
end

local function identificar_projeto(arquivo)
  local diretorio = vim.fs.dirname(
    vim.fn.fnamemodify(arquivo, ":p")
  )

  if vim.fs.basename(diretorio) == "public" then
    return vim.fs.dirname(diretorio), diretorio
  end

  local raiz = vim.fs.root(arquivo, {
    "composer.json",
    ".git",
  }) or diretorio

  local public = vim.fs.joinpath(raiz, "public")
  local docroot = vim.fn.isdirectory(public) == 1 and public or raiz

  return raiz, docroot
end

function M.iniciar(arquivo)
  if not arquivo or arquivo == "" then
    avisar("Abra um arquivo PHP primeiro.", vim.log.levels.WARN)
    return
  end

  local php = vim.fn.exepath("php")

  if php == "" then
    avisar("PHP nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local raiz, docroot = identificar_projeto(arquivo)

  if esta_ativo() then
    if servidor.encerrando then
      avisar("Aguarde o encerramento do servidor atual.", vim.log.levels.WARN)
      return
    end

    if servidor.raiz == raiz then
      if not servidor.live_iniciado then
        avisar("Servidor PHP inicializando. Aguarde o Live Server.")
        return
      end

      local live = require("languages.php.live")

      if live.ativo() then
        avisar("Servidor PHP e Live Server ja ativos.")
      else
        avisar("PHP ativo. Tentando reiniciar o Live Server.")
        live.iniciar(raiz, "http://" .. endereco)
      end

      return
    end

    if servidor.confirmando_troca then
      avisar("Ja existe uma confirmacao de troca aberta.", vim.log.levels.WARN)
      return
    end

    local anterior = servidor
    local opcao_trocar = "Trocar para: " .. raiz

    anterior.confirmando_troca = true

    vim.ui.select({
      opcao_trocar,
      "Cancelar",
    }, {
      prompt = "Servidor atual: " .. anterior.raiz .. ". Deseja trocar?",
    }, function(escolha)
      if servidor ~= anterior then
        avisar(
          "O servidor mudou antes da confirmacao. Tente novamente.",
          vim.log.levels.WARN
        )
        return
      end

      anterior.confirmando_troca = false

      if escolha ~= opcao_trocar then
        avisar("Troca cancelada. Servidor atual mantido.")
        return
      end

      if not esta_ativo() then
        avisar(
          "O servidor anterior ja terminou. Pressione F6 novamente.",
          vim.log.levels.WARN
        )
        return
      end

      anterior.proximo_arquivo = arquivo
      anterior.encerrando = true

      if vim.fn.jobstop(anterior.id) ~= 1 then
        anterior.proximo_arquivo = nil
        anterior.encerrando = false
        avisar(
          "Nao foi possivel encerrar o servidor anterior.",
          vim.log.levels.ERROR
        )
        return
      end

      avisar("Encerrando servidor anterior para iniciar: " .. raiz)
    end)

    return
  end

  local registro = {
    id = 0,
    encerrando = false,
    docroot = docroot,
    raiz = raiz,
  }

  local ultima_saida = ""

  -- Iniciar BrowserSync apenas apos o PHP anunciar que esta pronto.
  local function iniciar_live_quando_pronto()
    if registro.live_iniciado then
      return
    end

    registro.live_iniciado = true

    vim.schedule(function()
      if servidor == registro
          and not registro.encerrando
          and esta_ativo() then
        require("languages.php.live").iniciar(
          raiz,
          "http://" .. endereco
        )
      end
    end)
  end

  local id = vim.fn.jobstart({
    php,
    "-d",
    "xdebug.start_with_request=trigger",
    "-d",
    "xdebug.client_host=127.0.0.1",
    "-d",
    "xdebug.client_port=9003",
    "-S",
    endereco,
    "-t",
    docroot,
  }, {
    cwd = raiz,
    env = {
      XDEBUG_MODE = "debug",
    },

    on_stderr = function(_, linhas)
      for _, linha in ipairs(linhas or {}) do
        if linha ~= "" then
          ultima_saida = linha

          if linha:find("Development Server", 1, true)
              and linha:find("started", 1, true) then
            iniciar_live_quando_pronto()
          end
        end
      end
    end,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if servidor ~= registro then
          return
        end

        servidor = nil

        -- Encerrar BrowserSync antes de concluir a troca de projeto.
        local function concluir_encerramento()
          if registro.encerrando then
            if registro.proximo_arquivo then
              avisar("Servidor anterior encerrado. Iniciando novo projeto.")
              M.iniciar(registro.proximo_arquivo)
            else
              avisar("Servidor HTTP encerrado.")
            end
          elseif codigo ~= 0 then
            avisar(
              "Servidor falhou: " .. ultima_saida,
              vim.log.levels.ERROR
            )
          else
            avisar("Servidor HTTP finalizado.")
          end
        end

        local live = require("languages.php.live")

        if not live.parar(concluir_encerramento) then
          avisar(
            "Falha ao encerrar BrowserSync. Troca interrompida.",
            vim.log.levels.ERROR
          )
        end
      end)
    end,
  })

  if id <= 0 then
    avisar("Nao foi possivel iniciar o servidor.", vim.log.levels.ERROR)
    return
  end

  registro.id = id
  servidor = registro

  avisar(
    "Inicializacao solicitada: http://" .. endereco ..
    "\nDiretorio: " .. docroot
  )
end

function M.parar()
  if not esta_ativo() then
    servidor = nil
    avisar("Nenhum servidor gerenciado pelo Neovim esta ativo.")
    return
  end

  servidor.encerrando = true
  vim.fn.jobstop(servidor.id)
end

function M.status()
  if esta_ativo() then
    avisar(
      "Servidor gerenciado ativo: http://" .. endereco ..
      "\nDiretorio: " .. servidor.docroot
    )
  else
    servidor = nil
    avisar("Nenhum servidor gerenciado pelo Neovim esta ativo.")
  end
end

return M
