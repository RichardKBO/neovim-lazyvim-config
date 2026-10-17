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

function M.iniciar(arquivo)
  if esta_ativo() then
    avisar("Servidor ja iniciado em http://" .. endereco)
    return
  end

  if not arquivo or arquivo == "" then
    avisar("Abra um arquivo PHP primeiro.", vim.log.levels.WARN)
    return
  end

  local php = vim.fn.exepath("php")

  if php == "" then
    avisar("PHP nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.root(arquivo, {
    "composer.json",
    ".git",
  }) or vim.fs.dirname(arquivo)

  local public = vim.fs.joinpath(raiz, "public")
  local docroot = vim.fn.isdirectory(public) == 1 and public or raiz

  local registro = {
    id = 0,
    encerrando = false,
    docroot = docroot,
  }

  local ultima_saida = ""

  local id = vim.fn.jobstart({
    php,
    "-S",
    endereco,
    "-t",
    docroot,
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
        if servidor ~= registro then
          return
        end

        servidor = nil

        if registro.encerrando then
          avisar("Servidor HTTP encerrado.")
        elseif codigo ~= 0 then
          avisar(
            "Servidor falhou: " .. ultima_saida,
            vim.log.levels.ERROR
          )
        else
          avisar("Servidor HTTP finalizado.")
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
