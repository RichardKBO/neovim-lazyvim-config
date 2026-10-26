local M = {}

local CMAKE = "cmake-4.4.4"

-- ========================================
-- IDENTIFICACAO DO PROJETO
-- ========================================

local function identificar_projeto(raiz)
  if type(raiz) ~= "string" or raiz == "" then
    return nil
  end

  local caminho = vim.uv.fs_realpath(raiz)

  if not caminho then
    return nil
  end

  local cmake = vim.fs.joinpath(caminho, "CMakeLists.txt")

  if vim.fn.filereadable(cmake) ~= 1 then
    return nil
  end

  return caminho
end

-- ========================================
-- ARQUIVO DE ESTADO POR PROJETO
-- ========================================

local function arquivo_estado(raiz)
  local projeto = identificar_projeto(raiz)

  if not projeto then
    return nil, nil
  end

  local pasta = vim.fs.joinpath(vim.fn.stdpath("state"), "cpp-presets")

  local identificador = vim.fn.sha256(projeto)

  local arquivo = vim.fs.joinpath(pasta, identificador .. ".json")

  return arquivo, projeto
end

-- ========================================
-- SALVAR SELECAO
-- ========================================

local function salvar_selecao(raiz, nome)
  local arquivo, projeto = arquivo_estado(raiz)

  if not arquivo or type(nome) ~= "string" or nome == "" then
    vim.notify("C++: projeto ou preset invalido.", vim.log.levels.ERROR)
    return false
  end

  local pasta = vim.fs.dirname(arquivo)

  vim.fn.mkdir(pasta, "p")

  if vim.fn.isdirectory(pasta) ~= 1 then
    vim.notify("C++: nao foi possivel criar a pasta de estado.", vim.log.levels.ERROR)
    return false
  end

  local dados = vim.json.encode({
    raiz = projeto,
    preset = nome,
  })

  local temporario = arquivo .. ".tmp-" .. tostring(vim.uv.hrtime())

  local ok, resultado = pcall(vim.fn.writefile, { dados }, temporario)

  if not ok or resultado ~= 0 then
    vim.fn.delete(temporario)

    vim.notify("C++: falha ao salvar a selecao do preset.", vim.log.levels.ERROR)
    return false
  end

  local sucesso, erro = vim.uv.fs_rename(temporario, arquivo)

  if not sucesso then
    vim.fn.delete(temporario)

    vim.notify("C++: falha ao registrar preset: " .. tostring(erro), vim.log.levels.ERROR)
    return false
  end

  return true
end

-- ========================================
-- LER SELECAO SALVA
-- ========================================

local function ler_selecao(raiz)
  local arquivo, projeto = arquivo_estado(raiz)

  if not arquivo or vim.fn.filereadable(arquivo) ~= 1 then
    return nil
  end

  local ok_leitura, linhas = pcall(vim.fn.readfile, arquivo)

  if not ok_leitura then
    return nil
  end

  local ok_json, dados = pcall(vim.json.decode, table.concat(linhas, "\n"))

  if not ok_json or type(dados) ~= "table" then
    return nil
  end

  if dados.raiz ~= projeto then
    return nil
  end

  if type(dados.preset) ~= "string" then
    return nil
  end

  return dados.preset
end

-- ========================================
-- LISTAR PRESETS DO CMAKE
-- ========================================

function M.listar(raiz, callback)
  if type(callback) ~= "function" then
    vim.notify("C++: callback de presets invalido.", vim.log.levels.ERROR)
    return
  end

  raiz = identificar_projeto(raiz)

  if not raiz then
    vim.notify("C++: raiz CMake invalida.", vim.log.levels.ERROR)
    callback(nil)
    return
  end

  if vim.fn.executable(CMAKE) ~= 1 then
    vim.notify("C++: CMake 4.4.4 indisponivel.", vim.log.levels.ERROR)
    callback(nil)
    return
  end

  local ok, erro = pcall(vim.system, {
    CMAKE,
    "--list-presets=configure",
  }, {
    cwd = raiz,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        vim.notify("C++: falha ao consultar presets:\n" .. (resultado.stderr or ""), vim.log.levels.ERROR)

        callback(nil)
        return
      end

      local opcoes = {}

      for linha in (resultado.stdout or ""):gmatch("[^\r\n]+") do
        local nome = linha:match('^%s*"([^"]+)"')

        if nome then
          local descricao = linha:match('^%s*"[^"]+"%s*%-%s*(.-)%s*$')

          table.insert(opcoes, {
            nome = nome,
            descricao = descricao,
          })
        end
      end

      callback(opcoes)
    end)
  end)

  if not ok then
    vim.notify(
      "C++: falha ao iniciar consulta de presets: " .. tostring(erro),
      vim.log.levels.ERROR
    )
    callback(nil)
  end
end

-- ========================================
-- OBTER PRESET SALVO E VALIDADO
-- ========================================

function M.obter(raiz, callback)
  if type(callback) ~= "function" then
    return
  end

  local salvo = ler_selecao(raiz)

  if not salvo then
    callback(nil)
    return
  end

  -- Confirmar que o preset ainda existe.
  M.listar(raiz, function(opcoes)
    if not opcoes then
      callback(nil, "falha_consulta")
      return
    end

    for _, opcao in ipairs(opcoes) do
      if opcao.nome == salvo then
        callback(salvo)
        return
      end
    end

    vim.notify("C++: preset salvo nao esta mais disponivel: " .. salvo, vim.log.levels.WARN)

    callback(nil)
  end)
end

-- ========================================
-- SELECIONAR E PERSISTIR PRESET
-- ========================================

function M.selecionar(raiz, callback)
  if type(callback) ~= "function" then
    vim.notify("C++: callback de selecao invalido.", vim.log.levels.ERROR)
    return
  end

  M.listar(raiz, function(opcoes)
    if not opcoes then
      callback(nil)
      return
    end

    if #opcoes == 0 then
      vim.notify("C++: nenhum preset de configuracao disponivel.", vim.log.levels.WARN)

      callback(nil)
      return
    end

    local salvo = ler_selecao(raiz)

    vim.ui.select(opcoes, {
      prompt = "C++ - Selecione o preset CMake:",

      format_item = function(item)
        local texto = item.nome

        if item.descricao and item.descricao ~= "" then
          texto = texto .. " - " .. item.descricao
        end

        if item.nome == salvo then
          texto = texto .. " [ATUAL]"
        end

        return texto
      end,
    }, function(escolha)
      if not escolha then
        callback(nil)
        return
      end

      if not salvar_selecao(raiz, escolha.nome) then
        callback(nil)
        return
      end

      vim.notify("C++: preset salvo para este projeto: " .. escolha.nome)

      callback(escolha.nome)
    end)
  end)
end


-- ========================================
-- CONFIGURAR UTILIZANDO O PRESET SELECIONADO
-- ========================================

local configuracao_em_andamento = false

function M.configurar(raiz, callback)
  if type(callback) ~= "function" then
    vim.notify("C++: callback de configuracao invalido.", vim.log.levels.ERROR)
    return
  end

  raiz = identificar_projeto(raiz)

  if not raiz then
    vim.notify("C++: raiz CMake invalida.", vim.log.levels.ERROR)
    callback(nil)
    return
  end

  if configuracao_em_andamento then
    vim.notify("C++: configuracao de preset em andamento.", vim.log.levels.WARN)
    callback(nil)
    return
  end

  configuracao_em_andamento = true

  local function finalizar(nome, saida)
    configuracao_em_andamento = false
    callback(nome, saida)
  end

  local function executar(nome)
    if not nome then
      finalizar(nil)
      return
    end

    vim.notify("C++: configurando preset " .. nome)

    vim.system({
      CMAKE,
      "--preset",
      nome,
    }, {
      cwd = raiz,
      text = true,
    }, function(resultado)
      vim.schedule(function()
        if resultado.code ~= 0 then
          local saida = vim.trim(
            (resultado.stdout or "") .. "\n" .. (resultado.stderr or "")
          )

          vim.notify(
            "C++: falha ao configurar preset " .. nome .. "\n" .. saida,
            vim.log.levels.ERROR
          )

          finalizar(nil)
          return
        end

        vim.notify("C++: preset configurado: " .. nome)
        finalizar(nome, resultado.stdout or "")
      end)
    end)
  end

  M.obter(raiz, function(nome, erro_consulta)
    if erro_consulta then
      finalizar(nil)
      return
    end

    if nome then
      executar(nome)
    else
      M.selecionar(raiz, executar)
    end
  end)
end

return M
