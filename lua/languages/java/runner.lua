local M = {}

-- Identificar Maven, Gradle ou Java independente.
local function detectar_projeto(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  local marcadores = vim.fs.find({
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
  }, {
    path = diretorio,
    upward = true,
  })

  if #marcadores == 0 then
    return {
      tipo = "independente",
      raiz = diretorio,
    }
  end

  local marcador = marcadores[1]
  local nome = vim.fs.basename(marcador)
  local pasta = vim.fs.dirname(marcador)

  if nome == "pom.xml" then
    return {
      tipo = "maven",
      raiz = pasta,
    }
  end

  -- Gradle pode possuir subprojetos como app.
  local modulo = pasta

  local settings = vim.fs.find({
    "settings.gradle",
    "settings.gradle.kts",
  }, {
    path = pasta,
    upward = true,
  })

  local raiz = pasta

  if #settings > 0 then
    raiz = vim.fs.dirname(settings[1])
  end

  -- Se encontramos diretamente settings.gradle,
  -- o modulo inicial e a raiz do projeto.
  if nome == "settings.gradle" or nome == "settings.gradle.kts" then
    modulo = raiz
  end

  return {
    tipo = "gradle",
    raiz = raiz,
    modulo = modulo,
  }
end

local function linhas_atuais()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Identificar o package da classe atual.
local function obter_pacote()
  for _, linha in ipairs(linhas_atuais()) do
    local pacote = linha:match("^%s*package%s+([%w_%.]+)%s*;")

    if pacote then
      return pacote
    end
  end

  return nil
end

-- Identificar metodo main no arquivo atual.
local function possui_main()
  local texto = table.concat(linhas_atuais(), "\n")

  return texto:find("void%s+main%s*%(") ~= nil
end

local function classe_atual(arquivo)
  local nome = vim.fn.fnamemodify(arquivo, ":t:r")

  local pacote = obter_pacote()

  if pacote then
    return pacote .. "." .. nome
  end

  return nome
end

-- Executar no terminal inferior.
local function abrir_terminal(comando, diretorio)
  local abriu = pcall(vim.cmd, "botright 12new")

  if not abriu then
    vim.notify("Java: erro ao abrir terminal.", vim.log.levels.ERROR)
    return
  end

  local ok, job = pcall(vim.fn.termopen, comando, {
    cwd = diretorio,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if codigo == 0 then
          vim.notify("Java: execucao concluida.", vim.log.levels.INFO)
        else
          vim.notify("Java: falha na execucao (codigo " .. codigo .. ").", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or not job or job <= 0 then
    vim.notify("Java: nao foi possivel executar comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

-- Maven: preservar o comportamento ja testado.
local function executar_maven(arquivo, raiz)
  local wrapper = vim.fs.joinpath(raiz, "mvnw")

  local maven = "mvn"

  if vim.fn.executable(wrapper) == 1 then
    maven = wrapper
  end

  if vim.fn.executable(maven) ~= 1 then
    vim.notify("Java: Maven nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local comando = {
    maven,
    "-f",
    vim.fs.joinpath(raiz, "pom.xml"),
    "compile",
  }

  if possui_main() then
    local principal = classe_atual(arquivo)

    table.insert(comando, "exec:java")
    table.insert(comando, "-Dexec.mainClass=" .. principal)

    vim.notify("Java Maven: executando " .. principal)
  else
    vim.notify("Java Maven: compilando projeto.")
  end

  abrir_terminal(comando, raiz)
end

-- Construir o caminho da tarefa Gradle.
local function tarefa_gradle(projeto, tarefa)
  local raiz = vim.fs.normalize(projeto.raiz)
  local modulo = vim.fs.normalize(projeto.modulo)

  if raiz == modulo then
    return ":" .. tarefa
  end

  local prefixo = raiz .. "/"

  if modulo:sub(1, #prefixo) ~= prefixo then
    return nil
  end

  local relativo = modulo:sub(#prefixo + 1)

  local caminho_modulo = relativo:gsub("/", ":")

  return ":" .. caminho_modulo .. ":" .. tarefa
end

local function executar_gradle(arquivo, projeto)
  local wrapper = vim.fs.joinpath(projeto.raiz, "gradlew")

  local gradle = "gradle"

  if vim.fn.executable(wrapper) == 1 then
    gradle = wrapper
  end

  if vim.fn.executable(gradle) ~= 1 then
    vim.notify("Java: Gradle nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local tem_main = possui_main()

  local tarefa = tarefa_gradle(projeto, tem_main and "run" or "classes")

  if not tarefa then
    vim.notify("Java: nao foi possivel identificar o modulo Gradle.", vim.log.levels.ERROR)
    return
  end

  local comando = { gradle }

  if tem_main then
    local script = vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "languages", "java", "gradle_run.init.gradle")

    if vim.fn.filereadable(script) ~= 1 then
      vim.notify("Java: script auxiliar Gradle nao encontrado.", vim.log.levels.ERROR)
      return
    end

    local principal = classe_atual(arquivo)

    vim.list_extend(comando, {
      "--no-configuration-cache",
      "--init-script",
      script,
      "-PnvimMainClass=" .. principal,
    })

    vim.notify("Java Gradle: executando " .. principal)
  else
    vim.notify("Java Gradle: compilando modulo.")
  end

  table.insert(comando, tarefa)

  abrir_terminal(comando, projeto.raiz)
end

function M.executar(arquivo)
  if not arquivo or arquivo == "" then
    vim.notify("Java: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  -- Salvar apenas se o buffer foi modificado.
  local ok, erro = pcall(vim.cmd, "silent update")

  if not ok then
    vim.notify("Java: falha ao salvar: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  local projeto = detectar_projeto(arquivo)

  if projeto.tipo == "maven" then
    executar_maven(arquivo, projeto.raiz)
    return
  end

  if projeto.tipo == "gradle" then
    executar_gradle(arquivo, projeto)
    return
  end

  -- Java sem Maven ou Gradle.
  if vim.fn.executable("java") ~= 1 then
    vim.notify("Java: executavel java nao encontrado.", vim.log.levels.ERROR)
    return
  end

  abrir_terminal({ "java", arquivo }, projeto.raiz)
end

return M
