-- ========================================
-- C# - NAMESPACE AUTOMATICO
-- ========================================

local M = {}

-- ========================================
-- IDENTIFICAR NAMESPACE PELO PROJETO
-- ========================================

function M.obter_namespace(diretorio)
  local atual = vim.fs.normalize(diretorio)
  local projeto = nil

  while atual do
    local projetos = vim.fn.globpath(atual, "*.csproj", false, true)

    if #projetos > 1 then
      return nil, "Existem varios .csproj na mesma pasta. Nao e seguro escolher automaticamente."
    end

    if #projetos == 1 then
      projeto = projetos[1]
      break
    end

    local pai = vim.fs.dirname(atual)

    if not pai or pai == atual then
      break
    end

    atual = pai
  end

  if not projeto then
    return nil, "Nenhum projeto .csproj encontrado."
  end

  local resultado = vim.fn.system({
    "dotnet",
    "msbuild",
    projeto,
    "-getProperty:RootNamespace",
  })

  if vim.v.shell_error ~= 0 then
    return nil, "Nao foi possivel consultar o RootNamespace:\n" .. resultado
  end

  local namespace = vim.trim(resultado)

  if namespace == "" or namespace:find("\n", 1, true) then
    return nil, "RootNamespace invalido ou vazio."
  end

  local raiz_projeto = vim.fs.dirname(projeto)
  local relativo = vim.fs.relpath(raiz_projeto, diretorio)

  if relativo and relativo ~= "" and relativo ~= "." then
    for pasta in relativo:gmatch("[^/\\]+") do
      if not pasta:match("^[%a_][%w_]*$") then
        return nil, "A pasta '" .. pasta .. "' nao e um identificador C# valido."
      end

      namespace = namespace .. "." .. pasta
    end
  end

  return namespace
end

-- ========================================
-- GERAR NAMESPACE EM ARQUIVO NOVO E VAZIO
-- ========================================

function M.gerar_no_arquivo(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return false, "Caminho do arquivo invalido."
  end

  caminho = vim.fs.normalize(caminho)

  if not caminho:match("%.cs$") then
    return false, "O arquivo nao possui extensao .cs."
  end

  local uv = vim.uv or vim.loop
  local informacoes = uv.fs_lstat(caminho)

  if not informacoes or informacoes.type ~= "file" then
    return false, "O arquivo nao existe ou nao e um arquivo comum."
  end

  if informacoes.size ~= 0 then
    return false, "O arquivo ja possui conteudo. Nenhuma alteracao realizada."
  end

  local diretorio = vim.fs.dirname(caminho)
  local namespace, erro = M.obter_namespace(diretorio)

  if not namespace then
    return false, erro
  end

  local conteudo = "namespace " .. namespace .. ";\n\n"

  local arquivo, erro_abertura = uv.fs_open(caminho, "r+", 420)

  if not arquivo then
    return false, "Nao foi possivel abrir o arquivo: " .. tostring(erro_abertura)
  end

  local estado = uv.fs_fstat(arquivo)

  if not estado or estado.type ~= "file" or estado.size ~= 0 then
    uv.fs_close(arquivo)
    return false, "O arquivo nao esta vazio. Nenhuma alteracao realizada."
  end

  local escritos, erro_escrita = uv.fs_write(arquivo, conteudo, 0)
  uv.fs_close(arquivo)

  if escritos ~= #conteudo then
    return false, "Falha ao escrever namespace: " .. tostring(erro_escrita)
  end

  return true, namespace
end

return M
