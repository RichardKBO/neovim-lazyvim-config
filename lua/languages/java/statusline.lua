local M = {}

-- Verifica se o arquivo pertence ao contexto Java.
function M.ativo()
  local arquivo = vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    return false
  end

  if vim.bo.filetype == "java" then
    return true
  end

  return vim.fs.basename(arquivo) == "pom.xml"
end

-- Identifica automaticamente o gerenciador do projeto.
function M.gerenciador()
  if not M.ativo() then
    return nil
  end

  local arquivo = vim.api.nvim_buf_get_name(0)
  local diretorio = vim.fs.dirname(arquivo)

  local encontrados = vim.fs.find({
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
  }, {
    path = diretorio,
    upward = true,
  })

  if #encontrados == 0 then
    return "Avulso"
  end

  local marcador = vim.fs.basename(encontrados[1])

  if marcador == "pom.xml" then
    return "Maven"
  end

  return "Gradle"
end

-- Texto exibido pelo Lualine.
function M.texto()
  local gerenciador = M.gerenciador()

  if not gerenciador then
    return ""
  end

  return "Java | " .. gerenciador
end

return M
