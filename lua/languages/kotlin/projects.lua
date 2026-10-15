local M = {}

local criando = false

local function identificador_valido(nome)
  return nome:match("^[%a_][%w_]*$") ~= nil
end

local function pacote_valido(pacote)
  local partes = vim.split(pacote, ".", {
    plain = true,
    trimempty = false,
  })

  if #partes == 0 then
    return false
  end

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

  if not pacote_valido(dados.pacote) then
    return "Pacote Kotlin invalido."
  end

  local versao = tonumber(dados.java)

  if not versao or versao < 17 or versao % 1 ~= 0 then
    return "Versao Java invalida."
  end

  return nil
end

function M.gerar(dados)
  if criando then
    vim.notify("Kotlin: uma criacao ja esta em andamento.", vim.log.levels.WARN)
    return
  end

  local erro = validar(dados)

  if erro then
    vim.notify(erro, vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable("gradle") ~= 1 then
    vim.notify("Kotlin: Gradle nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local pai = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dados.destino), ":p"))

  if vim.fn.isdirectory(pai) ~= 1 then
    vim.notify("Kotlin: pasta de destino nao existe.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.joinpath(pai, dados.nome)

  -- Proteger projetos existentes.
  if vim.uv.fs_lstat(raiz) then
    vim.notify("Kotlin: projeto ja existe: " .. raiz, vim.log.levels.ERROR)
    return
  end

  local comando = {
    "gradle",
    "init",
    "--into",
    raiz,
    "--type",
    "kotlin-application",
    "--dsl",
    "kotlin",
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

  criando = true

  vim.notify("Kotlin: criando projeto " .. dados.nome)

  local iniciou, erro_inicio = pcall(function()
    vim.system(comando, {
      cwd = pai,
      text = true,
    }, function(resultado)
      vim.schedule(function()
        criando = false

        if resultado.code ~= 0 then
          local saida = (resultado.stdout or "") .. "\n" .. (resultado.stderr or "")

          vim.notify("Kotlin: falha ao criar projeto.\n" .. saida:sub(-1600), vim.log.levels.ERROR)
          return
        end

        vim.notify("Kotlin: projeto criado em " .. raiz, vim.log.levels.INFO)

        -- Gradle pode criar o subprojeto app.
        local caminho_pacote = dados.pacote:gsub("%.", "/")

        local principal = vim.fs.joinpath(raiz, "app", "src", "main", "kotlin", caminho_pacote, "App.kt")

        if vim.fn.filereadable(principal) == 1 then
          local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(principal))

          if not abriu then
            vim.notify("Projeto criado, mas App.kt nao abriu: " .. tostring(erro_abrir), vim.log.levels.WARN)
          end
        else
          vim.notify("Projeto criado. Abra os arquivos pelo Explorer.", vim.log.levels.INFO)
        end
      end)
    end)
  end)

  if not iniciou then
    criando = false

    vim.notify("Kotlin: erro ao iniciar Gradle: " .. tostring(erro_inicio), vim.log.levels.ERROR)
  end
end

function M.criar()
  local dados = {}

  local perguntas = {
    {
      chave = "nome",
      texto = "Nome do projeto Kotlin: ",
      padrao = "",
    },
    {
      chave = "destino",
      texto = "Criar dentro da pasta: ",
      padrao = vim.fn.expand("~/Projetos/Kotlin"),
    },
    {
      chave = "pacote",
      texto = "Pacote Kotlin: ",
      padrao = "com.richard",
    },
    {
      chave = "java",
      texto = "Versao do Java: ",
      padrao = "21",
    },
  }

  local function perguntar(indice)
    local pergunta = perguntas[indice]

    if not pergunta then
      M.gerar(dados)
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
