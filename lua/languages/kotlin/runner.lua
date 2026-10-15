local M = {}

-- Ler o arquivo Kotlin salvo.
local function ler_linhas(arquivo)
  local ok, linhas = pcall(vim.fn.readfile, arquivo)

  if not ok then
    return nil
  end

  return linhas
end

-- Verificar se existe uma funcao main no arquivo.
local function possui_main(linhas)
  for _, linha in ipairs(linhas) do
    if
      linha:match("^%s*fun%s+main%s*%(")
      or linha:match("^%s*suspend%s+fun%s+main%s*%(")
      or linha:match("^%s*public%s+fun%s+main%s*%(")
    then
      return true
    end
  end

  return false
end

-- Descobrir o package e a classe JVM gerada
-- para uma funcao main de nivel superior.
local function classe_principal(arquivo, linhas)
  local nome = vim.fn.fnamemodify(arquivo, ":t:r")
  local pacote = ""

  local classe = nome .. "Kt"

  for _, linha in ipairs(linhas) do
    local encontrado = linha:match("^%s*package%s+([%w_%.]+)")

    if encontrado then
      pacote = encontrado
    end

    -- Respeitar nomes JVM personalizados.
    local jvm_nome = linha:match('@file%s*:%s*JvmName%s*%(%s*"([%w_]+)"')

    if jvm_nome then
      classe = jvm_nome
    end
  end

  if pacote ~= "" then
    return pacote .. "." .. classe
  end

  return classe
end

-- Encontrar o projeto Gradle correspondente
-- ao arquivo Kotlin atualmente aberto.
local function detectar_gradle(arquivo)
  local diretorio = vim.fs.dirname(arquivo)

  local settings = vim.fs.find({
    "settings.gradle.kts",
    "settings.gradle",
  }, {
    path = diretorio,
    upward = true,
  })[1]

  local build = vim.fs.find({
    "build.gradle.kts",
    "build.gradle",
  }, {
    path = diretorio,
    upward = true,
  })[1]

  if not build then
    return nil
  end

  local modulo = vim.fs.normalize(vim.fs.dirname(build))

  local raiz = modulo

  if settings then
    raiz = vim.fs.normalize(vim.fs.dirname(settings))
  end

  local relativo = ""

  if modulo ~= raiz then
    local prefixo = raiz .. "/"

    if modulo:sub(1, #prefixo) ~= prefixo then
      return nil
    end

    relativo = modulo:sub(#prefixo + 1)
  end

  local prefixo_tarefa = ":"

  if relativo ~= "" then
    prefixo_tarefa = ":" .. relativo:gsub("/", ":") .. ":"
  end

  return {
    raiz = raiz,
    modulo = modulo,
    prefixo_tarefa = prefixo_tarefa,
  }
end

-- Preferir o Gradle Wrapper do projeto.
local function obter_gradle(raiz)
  local wrapper = vim.fs.joinpath(raiz, "gradlew")

  if vim.fn.filereadable(wrapper) == 1 then
    if vim.fn.executable(wrapper) == 1 then
      return wrapper
    end

    vim.notify("Kotlin: Gradle Wrapper sem permissao de execucao.", vim.log.levels.ERROR)

    return nil
  end

  if vim.fn.executable("gradle") == 1 then
    return "gradle"
  end

  vim.notify("Kotlin: Gradle nao encontrado.", vim.log.levels.ERROR)

  return nil
end

-- Abrir um terminal inferior para executar comandos.
local function abrir_terminal(comando, diretorio)
  local abriu = pcall(vim.cmd, "botright 12new")

  if not abriu then
    vim.notify("Kotlin: falha ao abrir terminal.", vim.log.levels.ERROR)
    return
  end

  local ok, job = pcall(vim.fn.termopen, comando, {
    cwd = diretorio,

    on_exit = function(_, codigo)
      vim.schedule(function()
        if codigo == 0 then
          vim.notify("Kotlin: comando concluido com sucesso.", vim.log.levels.INFO)
        else
          vim.notify("Kotlin: comando falhou (codigo " .. codigo .. ").", vim.log.levels.ERROR)
        end
      end)
    end,
  })

  if not ok or not job or job <= 0 then
    vim.notify("Kotlin: falha ao iniciar comando.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

-- Executar um arquivo pertencente a um projeto Gradle.
local function executar_gradle(arquivo, linhas, projeto)
  local gradle = obter_gradle(projeto.raiz)

  if not gradle then
    return
  end

  local tem_main = possui_main(linhas)

  local tarefa = projeto.prefixo_tarefa .. (tem_main and "run" or "classes")

  local comando = {
    gradle,
    "--console=plain",
  }

  if tem_main then
    local init_script =
      vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "languages", "kotlin", "gradle_run.init.gradle")

    if vim.fn.filereadable(init_script) ~= 1 then
      vim.notify("Kotlin: script auxiliar Gradle nao encontrado.", vim.log.levels.ERROR)
      return
    end

    local principal = classe_principal(arquivo, linhas)

    vim.list_extend(comando, {
      "--no-configuration-cache",
      "--init-script",
      init_script,
      "-PnvimKotlinMainClass=" .. principal,
    })

    vim.notify("Kotlin Gradle: executando " .. principal, vim.log.levels.INFO)
  else
    vim.notify("Kotlin Gradle: arquivo sem main; compilando modulo.", vim.log.levels.INFO)
  end

  table.insert(comando, tarefa)

  abrir_terminal(comando, projeto.raiz)
end

-- Executar um arquivo Kotlin independente.
local function executar_independente(arquivo, linhas)
  if vim.fn.executable("kotlinc") ~= 1 then
    vim.notify("Kotlin: compilador kotlinc nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local tem_main = possui_main(linhas)

  if tem_main and vim.fn.executable("java") ~= 1 then
    vim.notify("Kotlin: executavel java nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local jar = vim.fn.tempname() .. ".jar"

  local principal = ""

  if tem_main then
    principal = classe_principal(arquivo, linhas)
  end

  -- Os argumentos sao passados separadamente,
  -- evitando problemas com espacos nos caminhos.
  local script = [[
arquivo="$1"
jar="$2"
classe="$3"

trap 'rm -f "$jar"' EXIT

if [ -n "$classe" ]; then
  kotlinc "$arquivo" -include-runtime -d "$jar" &&
    java -cp "$jar" "$classe"
else
  kotlinc "$arquivo" -d "$jar"
fi
]]

  if tem_main then
    vim.notify("Kotlin: executando " .. principal, vim.log.levels.INFO)
  else
    vim.notify("Kotlin: arquivo sem main; apenas compilando.", vim.log.levels.INFO)
  end

  abrir_terminal({
    "sh",
    "-c",
    script,
    "kotlin-f6",
    arquivo,
    jar,
    principal,
  }, vim.fs.dirname(arquivo))
end

-- Ponto de entrada utilizado pelo F6 global.
function M.executar(arquivo)
  if not arquivo or arquivo == "" then
    vim.notify("Kotlin: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = vim.fs.normalize(vim.fn.fnamemodify(arquivo, ":p"))

  -- Salvar o arquivo antes de compilar.
  local salvou, erro = pcall(vim.cmd, "silent update")

  if not salvou then
    vim.notify("Kotlin: falha ao salvar arquivo: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  local linhas = ler_linhas(arquivo)

  if not linhas then
    vim.notify("Kotlin: nao foi possivel ler o arquivo.", vim.log.levels.ERROR)
    return
  end

  local projeto = detectar_gradle(arquivo)

  if projeto then
    executar_gradle(arquivo, linhas, projeto)
    return
  end

  executar_independente(arquivo, linhas)
end

return M
