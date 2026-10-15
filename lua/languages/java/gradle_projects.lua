local M = {}

local executando = false

local function identificador_valido(nome)
  return nome:match("^[%a_][%w_]*$") ~= nil
end

local function pacote_valido(pacote)
  if pacote == "" then
    return false
  end

  local partes = vim.split(pacote, ".", {
    plain = true,
    trimempty = false,
  })

  for _, parte in ipairs(partes) do
    if not identificador_valido(parte) then
      return false
    end
  end

  return true
end

local function validar(dados)
  if not dados.nome:match("^[%w][%w_%-]*$") then
    return "Nome do projeto invalido."
  end

  if dados.destino == "" then
    return "Informe a pasta de destino."
  end

  if not pacote_valido(dados.pacote) then
    return "Pacote Java invalido."
  end

  local versao = tonumber(dados.java)

  if not versao or versao < 8 or versao % 1 ~= 0 then
    return "Versao Java invalida."
  end

  return nil
end

function M.gerar(dados)
  if executando then
    vim.notify("Java Gradle: uma criacao ja esta em andamento.", vim.log.levels.WARN)
    return
  end

  local erro = validar(dados)

  if erro then
    vim.notify(erro, vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable("gradle") ~= 1 then
    vim.notify("Java Gradle: comando gradle nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local pai = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dados.destino), ":p"))

  if vim.fn.isdirectory(pai) ~= 1 then
    vim.notify("Java Gradle: pasta de destino nao existe.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.joinpath(pai, dados.nome)

  -- Nunca sobrescrever projetos existentes.
  if vim.uv.fs_lstat(raiz) then
    vim.notify("Java Gradle: projeto ja existe: " .. raiz, vim.log.levels.ERROR)
    return
  end

  local comando = {
    "gradle",
    "init",
    "--into",
    raiz,
    "--type",
    "java-application",
    "--dsl",
    dados.dsl,
    "--test-framework",
    "junit-jupiter",
    "--project-name",
    dados.nome,
    "--package",
    dados.pacote,
    "--java-version",
    dados.java,
    "--no-split-project",
    "--use-defaults",
    "--console=plain",
  }

  executando = true

  vim.notify("Java Gradle: criando projeto " .. dados.nome .. ". Aguarde a conclusao.")

  local ok, erro_inicio = pcall(function()
    vim.system(comando, {
      cwd = pai,
      text = true,
    }, function(resultado)
      vim.schedule(function()
        executando = false

        if resultado.code ~= 0 then
          local detalhes = ((resultado.stdout or "") .. "\n" .. (resultado.stderr or ""))

          vim.notify(
            "Java Gradle: falha na criacao.\n" .. detalhes:sub(-1800) .. "\nVerifique os arquivos em: " .. raiz,
            vim.log.levels.ERROR
          )
          return
        end

        local caminho_pacote = dados.pacote:gsub("%.", "/")

        local principal = vim.fs.joinpath(raiz, "app", "src", "main", "java", caminho_pacote, "App.java")

        vim.notify("Java Gradle: projeto criado em " .. raiz, vim.log.levels.INFO)

        if vim.fn.filereadable(principal) == 1 then
          local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(principal))

          if not abriu then
            vim.notify(
              "Projeto criado, mas nao foi possivel abrir App.java: " .. tostring(erro_abrir),
              vim.log.levels.WARN
            )
          end
        else
          vim.notify("Projeto criado. Abra seus arquivos pelo Explorer.", vim.log.levels.WARN)
        end
      end)
    end)
  end)

  if not ok then
    executando = false

    vim.notify("Java Gradle: nao foi possivel iniciar: " .. tostring(erro_inicio), vim.log.levels.ERROR)
  end
end

function M.criar()
  local dados = {}

  local perguntas = {
    {
      chave = "nome",
      texto = "Nome do projeto Gradle: ",
      padrao = "",
    },
    {
      chave = "destino",
      texto = "Criar dentro da pasta: ",
      padrao = vim.fn.getcwd(),
    },
    {
      chave = "pacote",
      texto = "Pacote Java: ",
      padrao = "com.richard",
    },
    {
      chave = "java",
      texto = "Versao Java: ",
      padrao = "25",
    },
  }

  local function perguntar(indice)
    local pergunta = perguntas[indice]

    if not pergunta then
      vim.ui.select({
        { nome = "Groovy DSL (build.gradle)", valor = "groovy" },
        { nome = "Kotlin DSL (build.gradle.kts)", valor = "kotlin" },
      }, {
        prompt = "Java Gradle - Linguagem do build",

        format_item = function(item)
          return item.nome
        end,
      }, function(escolha)
        if escolha then
          dados.dsl = escolha.valor
          M.gerar(dados)
        end
      end)

      return
    end

    vim.ui.input({
      prompt = pergunta.texto,
      default = pergunta.padrao,
    }, function(valor)
      if valor == nil then
        return
      end

      dados[pergunta.chave] = vim.trim(valor)

      perguntar(indice + 1)
    end)
  end

  perguntar(1)
end

return M
