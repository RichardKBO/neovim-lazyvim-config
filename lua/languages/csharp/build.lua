-- ========================================
-- C# - COMPILACAO MODULAR
-- ========================================

local M = {}

-- ========================================
-- IDENTIFICAR ARQUIVO COMPILAVEL
-- ========================================

local function arquivo_compilavel(caminho)
  return caminho:match("%.csproj$")
    or caminho:match("%.sln$")
    or caminho:match("%.slnx$")
end

-- ========================================
-- LOCALIZAR ALVO DE COMPILACAO
-- ========================================

function M.localizar_alvo()
  local arquivo = vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    return nil, "Abra um arquivo de projeto ou solucao C#."
  end

  arquivo = vim.fs.normalize(arquivo)

  if vim.fn.filereadable(arquivo) ~= 1 then
    return nil, "O arquivo atual nao existe no disco."
  end

  -- Compilar diretamente .csproj, .sln ou .slnx.
  if arquivo_compilavel(arquivo) then
    return arquivo
  end

  -- Para arquivos comuns, procurar o .csproj ancestral.
  local diretorio = vim.fs.dirname(arquivo)

  while diretorio do
    local projetos = vim.fn.globpath(
      diretorio,
      "*.csproj",
      false,
      true
    )

    if #projetos > 1 then
      return nil, "Multiplos .csproj encontrados na mesma pasta."
    end

    if #projetos == 1 then
      return vim.fs.normalize(projetos[1])
    end

    local pai = vim.fs.dirname(diretorio)

    if not pai or pai == diretorio then
      break
    end

    diretorio = pai
  end

  return nil, "Nenhum projeto .csproj encontrado."
end

-- ========================================
-- COMPILAR PROJETO OU SOLUCAO
-- ========================================

function M.compilar()
  local alvo, erro = M.localizar_alvo()

  if not alvo then
    vim.notify(erro, vim.log.levels.ERROR)
    return
  end

  vim.cmd("botright new")

  vim.fn.termopen({
    "dotnet",
    "build",
    alvo,
    "--configuration",
    "Debug",
  }, {
    cwd = vim.fs.dirname(alvo),
  })
end

return M
