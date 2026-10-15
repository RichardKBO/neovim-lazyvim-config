local M = {}

local tipos = {
  { nome = "Nova classe", tipo = "class" },
  { nome = "Nova interface", tipo = "interface" },
  { nome = "Nova data class", tipo = "data" },
  { nome = "Novo object", tipo = "object" },
  { nome = "Novo enum class", tipo = "enum" },
  { nome = "Nova sealed class", tipo = "sealed" },
}

local reservadas = {
  ["as"] = true,
  ["break"] = true,
  ["class"] = true,
  ["continue"] = true,
  ["do"] = true,
  ["else"] = true,
  ["false"] = true,
  ["for"] = true,
  ["fun"] = true,
  ["if"] = true,
  ["in"] = true,
  ["interface"] = true,
  ["is"] = true,
  ["null"] = true,
  ["object"] = true,
  ["package"] = true,
  ["return"] = true,
  ["super"] = true,
  ["this"] = true,
  ["throw"] = true,
  ["true"] = true,
  ["try"] = true,
  ["typealias"] = true,
  ["typeof"] = true,
  ["val"] = true,
  ["var"] = true,
  ["when"] = true,
  ["while"] = true,
}

local function identificador_valido(nome)
  return nome:match("^[%a_][%w_]*$") ~= nil and not reservadas[nome]
end

local function pacote_valido(pacote)
  if pacote == "" then
    return true
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

-- Encontrar o diretorio de fontes do modulo Gradle.
function M.localizar_fontes(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local diretorio = vim.fn.getcwd()

  if arquivo ~= "" then
    diretorio = vim.fs.dirname(vim.fn.fnamemodify(arquivo, ":p"))
  end

  local builds = vim.fs.find({
    "build.gradle.kts",
    "build.gradle",
  }, {
    path = diretorio,
    upward = true,
  })

  if #builds == 0 then
    return nil
  end

  local modulo = vim.fs.dirname(builds[1])

  return vim.fs.joinpath(modulo, "src", "main", "kotlin")
end

-- Obter o pacote declarado no arquivo aberto.
local function pacote_atual(arquivo)
  if not arquivo or arquivo == "" then
    return ""
  end

  local linhas = {}
  local buffer = vim.api.nvim_get_current_buf()
  local atual = vim.api.nvim_buf_get_name(buffer)

  if vim.fs.normalize(atual) == vim.fs.normalize(arquivo) then
    linhas = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
  else
    local ok, resultado = pcall(vim.fn.readfile, arquivo)

    if ok then
      linhas = resultado
    end
  end

  for _, linha in ipairs(linhas) do
    local pacote = linha:match("^%s*package%s+([%w_%.]+)")

    if pacote then
      return pacote
    end
  end

  return ""
end

-- Gerar o conteudo de cada tipo Kotlin.
local function gerar_conteudo(tipo, pacote, nome, parametros)
  local linhas = {}

  if pacote ~= "" then
    vim.list_extend(linhas, {
      "package " .. pacote,
      "",
    })
  end

  if tipo == "class" then
    vim.list_extend(linhas, {
      "class " .. nome .. " {",
      "",
      "}",
    })
  elseif tipo == "interface" then
    vim.list_extend(linhas, {
      "interface " .. nome .. " {",
      "",
      "}",
    })
  elseif tipo == "data" then
    vim.list_extend(linhas, {
      "data class " .. nome .. "(" .. parametros .. ") {",
      "",
      "}",
    })
  elseif tipo == "object" then
    vim.list_extend(linhas, {
      "object " .. nome .. " {",
      "",
      "}",
    })
  elseif tipo == "enum" then
    vim.list_extend(linhas, {
      "enum class " .. nome .. " {",
      "    EXEMPLO",
      "}",
    })
  elseif tipo == "sealed" then
    vim.list_extend(linhas, {
      "sealed class " .. nome .. " {",
      "",
      "}",
    })
  end

  return linhas
end

-- Criar um arquivo novo sem sobrescrever existentes.
local function escrever_arquivo(arquivo, conteudo)
  -- "wx" significa criar exclusivamente.
  -- Se o arquivo ja existir, a operacao falha.
  local descritor, erro_abertura = vim.uv.fs_open(arquivo, "wx", 420)

  if not descritor then
    return false, erro_abertura
  end

  local texto = table.concat(conteudo, "\n") .. "\n"

  local escritos, erro_escrita = vim.uv.fs_write(descritor, texto, 0)

  local fechado, erro_fechamento = vim.uv.fs_close(descritor)

  if escritos ~= #texto or not fechado then
    -- O arquivo foi criado por esta funcao.
    -- Apagar somente o arquivo incompleto.
    vim.uv.fs_unlink(arquivo)

    return false, erro_escrita or erro_fechamento or "escrita incompleta"
  end

  return true
end

local function criar_arquivo(fontes, tipo, pacote, nome, parametros)
  if not identificador_valido(nome) then
    vim.notify("Kotlin: nome de tipo invalido.", vim.log.levels.ERROR)
    return
  end

  if not pacote_valido(pacote) then
    vim.notify("Kotlin: pacote invalido.", vim.log.levels.ERROR)
    return
  end

  if tipo == "data" and (not parametros or parametros == "") then
    vim.notify("Kotlin: data class exige parametros com val ou var.", vim.log.levels.ERROR)
    return
  end

  local pasta = fontes

  if pacote ~= "" then
    local caminho_pacote = pacote:gsub("%.", "/")

    pasta = vim.fs.joinpath(fontes, caminho_pacote)
  end

  local arquivo = vim.fs.joinpath(pasta, nome .. ".kt")

  -- Verificar previamente se o arquivo existe.
  if vim.uv.fs_lstat(arquivo) then
    vim.notify("Kotlin: arquivo ja existe: " .. arquivo, vim.log.levels.WARN)
    return
  end

  local ok_pasta = pcall(vim.fn.mkdir, pasta, "p")

  if not ok_pasta or vim.fn.isdirectory(pasta) ~= 1 then
    vim.notify("Kotlin: falha ao criar diretorio.", vim.log.levels.ERROR)
    return
  end

  local conteudo = gerar_conteudo(tipo, pacote, nome, parametros)

  local ok, erro = escrever_arquivo(arquivo, conteudo)

  if not ok then
    vim.notify("Kotlin: falha ao criar arquivo: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  vim.notify("Kotlin: criado " .. nome .. ".kt", vim.log.levels.INFO)

  local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(arquivo))

  if not abriu then
    vim.notify("Arquivo criado, mas nao foi possivel abrir: " .. tostring(erro_abrir), vim.log.levels.WARN)
  end
end

function M.criar(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local fontes = M.localizar_fontes(arquivo)

  if not fontes then
    vim.notify("Kotlin: modulo Gradle nao encontrado.", vim.log.levels.WARN)
    return
  end

  local pacote_padrao = pacote_atual(arquivo)

  vim.ui.select(tipos, {
    prompt = "Kotlin - Novo elemento",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    vim.ui.input({
      prompt = "Pacote Kotlin: ",
      default = pacote_padrao,
    }, function(pacote)
      if pacote == nil then
        return
      end

      pacote = vim.trim(pacote)

      if not pacote_valido(pacote) then
        vim.notify("Kotlin: pacote invalido.", vim.log.levels.ERROR)
        return
      end

      vim.ui.input({
        prompt = "Nome do tipo: ",
      }, function(nome)
        if nome == nil then
          return
        end

        nome = vim.trim(nome)

        if not identificador_valido(nome) then
          vim.notify("Kotlin: nome invalido.", vim.log.levels.ERROR)
          return
        end

        if escolha.tipo == "data" then
          vim.ui.input({
            prompt = "Parametros da data class: ",
            default = "val id: Int",
          }, function(parametros)
            if parametros == nil then
              return
            end

            criar_arquivo(fontes, escolha.tipo, pacote, nome, vim.trim(parametros))
          end)

          return
        end

        criar_arquivo(fontes, escolha.tipo, pacote, nome)
      end)
    end)
  end)
end

return M
