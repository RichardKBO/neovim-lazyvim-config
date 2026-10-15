local M = {}

local ocupado = false

-- ========================================
-- UTILITARIOS
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

-- Localizar o go.mod mais proximo do
-- arquivo aberto, independentemente do cwd.
local function localizar_modulo(arquivo)
  local encontrados = vim.fs.find("go.mod", {
    path = vim.fs.dirname(arquivo),
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return vim.fs.dirname(encontrados[1])
end

-- ========================================
-- EXECUCAO DE COMANDOS
-- ========================================

local function comando(argumentos, cwd, callback)
  local ok, erro = pcall(vim.system, argumentos, {
    cwd = cwd,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      callback(resultado)
    end)
  end)

  if not ok then
    ocupado = false

    avisar("Go: erro ao executar comando: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- Mostrar falhas sem esconder as mensagens
-- produzidas pelas ferramentas Go.
local function falha(etapa, resultado)
  ocupado = false

  local saida = (resultado.stdout or "") .. "\n" .. (resultado.stderr or "")

  avisar("Go: falha em " .. etapa, vim.log.levels.ERROR)

  if vim.trim(saida) ~= "" then
    vim.fn.setqflist({}, "r", {
      title = "Go - " .. etapa,
      lines = vim.split(saida, "\n", {
        trimempty = true,
      }),
    })

    vim.cmd("copen")
  end
end

-- ========================================
-- TERMINAL GO
-- ========================================

local function executar_terminal(argumentos, cwd)
  ocupado = false

  vim.cmd("botright 12new")

  local processo = vim.fn.termopen(argumentos, {
    cwd = cwd,
  })

  if processo <= 0 then
    avisar("Go: falha ao iniciar terminal.", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

-- ========================================
-- IDENTIFICAR PACOTE ATUAL
-- ========================================

local function identificar_pacote(diretorio, callback)
  comando(
    {
      "go",
      "list",
      "-f",
      "{{.Name}}",
      ".",
    },
    diretorio,
    function(resultado)
      if resultado.code ~= 0 then
        falha("identificacao do pacote", resultado)
        return
      end

      callback(vim.trim(resultado.stdout or ""))
    end
  )
end

-- ========================================
-- ENCONTRAR PROGRAMAS DO MODULO
-- ========================================

local function encontrar_programas(raiz, callback)
  comando(
    {
      "go",
      "list",
      "-f",
      '{{if eq .Name "main"}}{{.Dir}}{{end}}',
      "./...",
    },
    raiz,
    function(resultado)
      if resultado.code ~= 0 then
        falha("localizacao dos programas", resultado)
        return
      end

      local programas = {}
      local vistos = {}

      local saida = resultado.stdout or ""

      for linha in (saida .. "\n"):gmatch("(.-)\n") do
        local diretorio = vim.trim(linha)

        if diretorio ~= "" and not vistos[diretorio] then
          vistos[diretorio] = true

          table.insert(programas, {
            nome = vim.fn.fnamemodify(diretorio, ":t"),
            diretorio = vim.fs.normalize(diretorio),
          })
        end
      end

      table.sort(programas, function(a, b)
        return a.diretorio < b.diretorio
      end)

      callback(programas)
    end
  )
end

-- ========================================
-- EXECUTAR PACOTE COMPLETO
-- ========================================

local function executar_pacote(diretorio)
  avisar("Go F6: executando pacote em " .. diretorio)

  -- go run . considera os arquivos Go
  -- compilaveis do pacote, em vez de
  -- executar somente o arquivo aberto.
  executar_terminal({
    "go",
    "run",
    ".",
  }, diretorio)
end

-- ========================================
-- EXECUTAR ARQUIVO INDEPENDENTE
-- ========================================

local function executar_isolado(arquivo)
  avisar("Go F6: executando arquivo independente.")

  executar_terminal({
    "go",
    "run",
    arquivo,
  }, vim.fs.dirname(arquivo))
end

-- ========================================
-- RUNNER DINAMICO
-- ========================================

function M.executar(arquivo)
  if ocupado then
    avisar("Go: aguarde a operacao anterior.", vim.log.levels.WARN)
    return
  end

  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("Go: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = normalizar(arquivo)

  if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "go" then
    avisar("Go: arquivo atual nao e .go.", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("go") ~= 1 then
    avisar("Go: compilador nao encontrado.", vim.log.levels.ERROR)
    return
  end

  -- Salvar alteracoes do arquivo atual.
  local atual = vim.api.nvim_buf_get_name(0)

  if atual ~= "" and normalizar(atual) == arquivo then
    local ok, erro = pcall(vim.cmd, "update")

    if not ok then
      avisar("Go: falha ao salvar arquivo: " .. tostring(erro), vim.log.levels.ERROR)
      return
    end
  end

  if vim.fn.filereadable(arquivo) ~= 1 then
    avisar("Go: arquivo nao encontrado no disco.", vim.log.levels.ERROR)
    return
  end

  ocupado = true

  local diretorio = vim.fs.dirname(arquivo)
  local raiz = localizar_modulo(arquivo)

  -- Arquivo sem go.mod.
  if not raiz then
    executar_isolado(arquivo)
    return
  end

  -- Descobrir se o arquivo pertence
  -- diretamente a um pacote main.
  identificar_pacote(diretorio, function(pacote)
    if pacote == "main" then
      executar_pacote(diretorio)
      return
    end

    -- Arquivo de biblioteca:
    -- procurar programas executaveis do modulo.
    encontrar_programas(raiz, function(programas)
      if #programas == 0 then
        ocupado = false

        avisar("Go: este modulo nao possui " .. "um pacote main executavel.", vim.log.levels.WARN)
        return
      end

      -- Apenas um programa principal:
      -- executar automaticamente.
      if #programas == 1 then
        executar_pacote(programas[1].diretorio)
        return
      end

      -- Multiplos programas principais:
      -- deixar o usuario escolher.
      ocupado = false

      vim.ui.select(programas, {
        prompt = "Go: escolher programa para executar",

        format_item = function(item)
          return item.diretorio
        end,
      }, function(escolha)
        if escolha then
          executar_pacote(escolha.diretorio)
        end
      end)
    end)
  end)
end

return M
