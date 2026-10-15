local M = {}

-- Identificar o diretorio de partida.
local function obter_diretorio(arquivo)
  if not arquivo or arquivo == "" then
    return vim.fn.getcwd()
  end

  return vim.fs.dirname(vim.fs.normalize(arquivo))
end

-- Localizar a raiz do projeto Gradle.
-- Prioriza settings.gradle(.kts), inclusive
-- em projetos com varios modulos.
function M.raiz_gradle(arquivo)
  local diretorio = obter_diretorio(arquivo)

  local settings = vim.fs.find({
    "settings.gradle.kts",
    "settings.gradle",
  }, {
    path = diretorio,
    upward = true,
  })

  if #settings > 0 then
    return vim.fs.dirname(settings[1])
  end

  -- Projetos Gradle sem settings.gradle.
  local build = vim.fs.find({
    "build.gradle.kts",
    "build.gradle",
  }, {
    path = diretorio,
    upward = true,
  })

  if #build > 0 then
    return vim.fs.dirname(build[1])
  end

  return nil
end

-- Preferir o Gradle Wrapper do projeto.
local function obter_gradle(raiz)
  local wrapper = vim.fs.joinpath(raiz, "gradlew")

  if vim.fn.filereadable(wrapper) == 1 then
    if vim.fn.executable(wrapper) == 1 then
      return wrapper
    end

    vim.notify("Kotlin Gradle: wrapper sem permissao de execucao.", vim.log.levels.ERROR)

    return nil
  end

  if vim.fn.executable("gradle") == 1 then
    return "gradle"
  end

  vim.notify("Kotlin Gradle: executavel nao encontrado.", vim.log.levels.ERROR)

  return nil
end

-- Executar Build ou Test no terminal inferior.
function M.executar(acao, arquivo)
  if acao ~= "build" and acao ~= "test" then
    vim.notify("Kotlin Gradle: comando invalido.", vim.log.levels.ERROR)
    return
  end

  local raiz = M.raiz_gradle(arquivo)

  if not raiz then
    vim.notify("Kotlin Gradle: projeto nao encontrado.", vim.log.levels.WARN)
    return
  end

  local gradle = obter_gradle(raiz)

  if not gradle then
    return
  end

  local comando = {
    gradle,
    "--console=plain",
    acao,
  }

  local abriu = pcall(vim.cmd, "botright 12new")

  if not abriu then
    vim.notify("Kotlin Gradle: falha ao abrir terminal.", vim.log.levels.ERROR)
    return
  end

  local ok, job = pcall(vim.fn.termopen, comando, {
    cwd = raiz,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if codigo == 0 then
          vim.notify("Kotlin Gradle " .. acao .. ": concluido com sucesso.", vim.log.levels.INFO)
        else
          vim.notify("Kotlin Gradle " .. acao .. ": falhou (codigo " .. codigo .. ").", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or not job or job <= 0 then
    vim.notify("Kotlin Gradle: erro ao executar comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

return M
