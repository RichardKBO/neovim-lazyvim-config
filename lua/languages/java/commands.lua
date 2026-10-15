local M = {}

-- Encontrar o pom.xml mais proximo do arquivo atual.
function M.raiz_maven(arquivo)
  local caminho = arquivo

  if not caminho or caminho == "" then
    caminho = vim.fn.getcwd()
  end

  caminho = vim.fn.fnamemodify(caminho, ":p")

  local diretorio = caminho

  if vim.fn.isdirectory(caminho) ~= 1 then
    diretorio = vim.fs.dirname(caminho)
  end

  local encontrados = vim.fs.find("pom.xml", {
    path = diretorio,
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return vim.fs.dirname(encontrados[1])
end

-- Executar um comando Maven no projeto identificado.
function M.executar_maven(acao, arquivo)
  local permitidos = {
    compile = true,
    test = true,
  }

  if not permitidos[acao] then
    vim.notify("Java Maven: comando nao permitido.", vim.log.levels.ERROR)
    return
  end

  local raiz = M.raiz_maven(arquivo)

  if not raiz then
    vim.notify("Java Maven: nenhum pom.xml encontrado.", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("mvn") ~= 1 then
    vim.notify("Java Maven: comando mvn nao encontrado.", vim.log.levels.ERROR)
    return
  end

  -- Abrir terminal inferior, sem alterar o runner F6.
  local abriu = pcall(vim.cmd, "botright 12new")

  if not abriu then
    vim.notify("Java Maven: nao foi possivel abrir o terminal.", vim.log.levels.ERROR)
    return
  end

  -- Usar lista de argumentos, sem montar shell strings.
  local ok, job = pcall(vim.fn.termopen, { "mvn", acao }, {
    cwd = raiz,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if codigo == 0 then
          vim.notify("Java Maven " .. acao .. ": concluido.", vim.log.levels.INFO)
        else
          vim.notify("Java Maven " .. acao .. ": falhou (codigo " .. codigo .. ").", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or not job or job <= 0 then
    vim.notify("Java Maven: falha ao iniciar o comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
