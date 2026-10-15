local M = {}

-- Descobrir o diretorio do arquivo atual.
local function diretorio_atual(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.getcwd()
  end

  local caminho = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.isdirectory(caminho) == 1 then
    return caminho
  end

  return vim.fs.dirname(caminho)
end

-- Identificar a raiz do projeto Gradle.
-- Em projetos com submodulos, priorizar settings.gradle.
function M.raiz_gradle(arquivo)
  local diretorio = diretorio_atual(arquivo)

  local settings = vim.fs.find({
    "settings.gradle",
    "settings.gradle.kts",
  }, {
    path = diretorio,
    upward = true,
  })

  if #settings > 0 then
    return vim.fs.dirname(settings[1])
  end

  -- Suporte a projetos Gradle sem settings.gradle.
  local build = vim.fs.find({
    "build.gradle",
    "build.gradle.kts",
  }, {
    path = diretorio,
    upward = true,
  })

  if #build > 0 then
    return vim.fs.dirname(build[1])
  end

  return nil
end

-- Localizar o Gradle Wrapper ou o Gradle global.
local function executavel_gradle(raiz)
  local wrapper = vim.fs.joinpath(raiz, "gradlew")

  if vim.fn.filereadable(wrapper) == 1 then
    if vim.fn.executable(wrapper) == 1 then
      return wrapper
    end

    return nil, "O Gradle Wrapper existe, mas nao possui permissao de execucao."
  end

  if vim.fn.executable("gradle") == 1 then
    return "gradle"
  end

  return nil, "Gradle nao encontrado."
end

-- Executar Build ou Test usando a raiz do projeto.
function M.executar(acao, arquivo)
  local permitidos = {
    build = true,
    test = true,
  }

  if not permitidos[acao] then
    vim.notify("Java Gradle: comando nao permitido.", vim.log.levels.ERROR)
    return
  end

  local raiz = M.raiz_gradle(arquivo)

  if not raiz then
    vim.notify("Java Gradle: projeto nao encontrado.", vim.log.levels.WARN)
    return
  end

  local gradle, erro = executavel_gradle(raiz)

  if not gradle then
    vim.notify("Java Gradle: " .. erro, vim.log.levels.ERROR)
    return
  end

  -- Executar na raiz do projeto.
  -- O build/test raiz abrange os subprojetos associados.
  local comando = {
    gradle,
    acao,
  }

  local abriu = pcall(vim.cmd, "botright 12new")

  if not abriu then
    vim.notify("Java Gradle: falha ao abrir terminal.", vim.log.levels.ERROR)
    return
  end

  local ok, job = pcall(vim.fn.termopen, comando, {
    cwd = raiz,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if codigo == 0 then
          vim.notify("Java Gradle " .. acao .. ": concluido com sucesso.", vim.log.levels.INFO)
        else
          vim.notify("Java Gradle " .. acao .. ": falhou (codigo " .. codigo .. ").", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or not job or job <= 0 then
    vim.notify("Java Gradle: falha ao iniciar comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
