-- ========================================
-- C# - CRIACAO MODULAR DE CLASSES
-- ========================================

local M = {}

local namespace_auto = require("languages.csharp.namespace_auto")

-- ========================================
-- CRIAR CLASSE C#
-- ========================================

function M.criar()
  local arquivo_atual = vim.fn.expand("%:p")

  local diretorio_inicial = arquivo_atual ~= ""
    and vim.fs.dirname(arquivo_atual)
    or vim.fn.getcwd()

  -- Escolher a pasta de destino.
  local entrada = vim.fn.input(
    "Diretorio da classe C#: ",
    diretorio_inicial .. "/",
    "dir"
  )

  if entrada == "" then
    vim.notify("Criacao cancelada.", vim.log.levels.WARN)
    return
  end

  local diretorio = vim.fs.normalize(
    vim.fn.fnamemodify(vim.fn.expand(entrada), ":p")
  )

  if vim.fn.isdirectory(diretorio) ~= 1 then
    vim.notify("Diretorio nao encontrado: " .. diretorio, vim.log.levels.ERROR)
    return
  end

  -- Identificar o namespace pelo projeto.
  local namespace, erro = namespace_auto.obter_namespace(diretorio)

  if not namespace then
    vim.notify(erro, vim.log.levels.ERROR)
    return
  end

  -- Solicitar o nome da classe.
  local nome = vim.trim(vim.fn.input("Nome da classe C#: "))

  if nome == "" then
    vim.notify("Criacao cancelada.", vim.log.levels.WARN)
    return
  end

  nome = nome:gsub("%.cs$", "")

  if not nome:match("^[%a_][%w_]*$") then
    vim.notify("Nome de classe invalido.", vim.log.levels.ERROR)
    return
  end

  local caminho = vim.fs.joinpath(diretorio, nome .. ".cs")

  -- Criacao exclusiva: nao sobrescrever arquivos.
  local fd, erro_abertura = vim.uv.fs_open(caminho, "wx", 420)

  if not fd then
    vim.notify(
      "Nao foi possivel criar a classe: " .. tostring(erro_abertura),
      vim.log.levels.ERROR
    )
    return
  end

  -- Classe C# com namespace e estilo Allman.
  local conteudo = table.concat({
    "namespace " .. namespace .. ";",
    "",
    "public class " .. nome,
    "{",
    "}",
    "",
  }, "\n")

  local escritos, erro_escrita = vim.uv.fs_write(fd, conteudo, 0)

  vim.uv.fs_close(fd)

  if escritos ~= #conteudo then
    vim.notify(
      "Erro ao gravar a classe: " .. tostring(erro_escrita),
      vim.log.levels.ERROR
    )
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(caminho))

  vim.notify("Classe criada: " .. namespace .. "." .. nome)
end

return M
