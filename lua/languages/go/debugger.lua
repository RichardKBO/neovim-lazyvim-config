local M = {}

local preparando = false

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

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

local function comando(argumentos, cwd, callback)
  local ok, erro = pcall(function()
    vim.system(argumentos, {
      cwd = cwd,
      text = true,
    }, function(resultado)
      vim.schedule(function()
        callback(resultado)
      end)
    end)
  end)

  if not ok then
    preparando = false
    vim.notify("Go: falha ao executar comando: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

local function erro_comando(etapa, resultado)
  preparando = false

  local mensagem = vim.trim((resultado.stderr or "") .. "\n" .. (resultado.stdout or ""))

  avisar("Go: erro em " .. etapa .. "\n" .. mensagem, vim.log.levels.ERROR)
end

-- Iniciar a depuracao usando o pacote correto.
local function iniciar(dap, programa, diretorio)
  preparando = false

  if dap.session() then
    avisar("Go: ja existe uma sessao de depuracao.", vim.log.levels.WARN)
    return
  end

  local configuracao = {
    type = "go",
    request = "launch",
    name = "Go: Debug dinamico",

    program = programa,

    -- Diretorio do programa.
    cwd = diretorio,

    -- Diretorio utilizado pelo Delve
    -- para encontrar o go.mod e compilar.
    dlvCwd = diretorio,

    mode = "debug",
    outputMode = "remote",
  }

  avisar("Go: iniciando Delve em " .. diretorio)

  local ok, erro = pcall(dap.run, configuracao)

  if not ok then
    avisar("Go: falha ao iniciar Delve: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- Identificar o pacote do arquivo atual.
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
        erro_comando("identificacao do pacote", resultado)
        return
      end

      callback(vim.trim(resultado.stdout or ""))
    end
  )
end

-- Encontrar os programas executaveis
-- existentes dentro de um modulo Go.
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
        erro_comando("localizacao dos programas", resultado)
        return
      end

      local programas = {}
      local vistos = {}

      for linha in ((resultado.stdout or "") .. "\n"):gmatch("(.-)\n") do
        local diretorio = vim.trim(linha)

        if diretorio ~= "" and not vistos[diretorio] then
          vistos[diretorio] = true

          table.insert(programas, vim.fs.normalize(diretorio))
        end
      end

      table.sort(programas)
      callback(programas)
    end
  )
end

-- Verificar programa Go independente,
-- sem modulo go.mod.
local function arquivo_tem_main(arquivo)
  local ok, linhas = pcall(vim.fn.readfile, arquivo)

  if not ok then
    return false
  end

  for _, linha in ipairs(linhas) do
    if linha:match("^%s*package%s+main%s*$") then
      return true
    end
  end

  return false
end

-- ========================================
-- DEBUGGER DINAMICO
-- ========================================

function M.depurar(arquivo)
  local ok_dap, dap = pcall(require, "dap")

  if not ok_dap then
    avisar("Go: nvim-dap indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- F8 continua uma sessao existente.
  if dap.session() then
    dap.continue()
    return
  end

  if preparando then
    avisar("Go: aguarde a preparacao do debugger.", vim.log.levels.WARN)
    return
  end

  if not dap.adapters.go then
    avisar("Go: adaptador Delve nao configurado.", vim.log.levels.ERROR)
    return
  end

  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("Go: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = normalizar(arquivo)

  if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "go" then
    avisar("Go: o arquivo atual nao e Go.", vim.log.levels.WARN)
    return
  end

  if arquivo:match("_test%.go$") then
    avisar("Go: depuracao de testes sera configurada " .. "separadamente.", vim.log.levels.WARN)
    return
  end

  -- Salvar o arquivo atual.
  local atual = vim.api.nvim_buf_get_name(0)

  if atual ~= "" and normalizar(atual) == arquivo then
    local ok, erro = pcall(vim.cmd, "update")

    if not ok then
      avisar("Go: erro ao salvar: " .. tostring(erro), vim.log.levels.ERROR)
      return
    end
  end

  if vim.fn.filereadable(arquivo) ~= 1 then
    avisar("Go: arquivo nao encontrado no disco.", vim.log.levels.ERROR)
    return
  end

  preparando = true

  local diretorio = vim.fs.dirname(arquivo)
  local raiz = localizar_modulo(arquivo)

  -- Arquivo independente, sem go.mod.
  if not raiz then
    if not arquivo_tem_main(arquivo) then
      preparando = false

      avisar("Go: arquivo isolado nao pertence " .. "ao pacote main.", vim.log.levels.WARN)
      return
    end

    iniciar(dap, arquivo, diretorio)
    return
  end

  -- Descobrir se o pacote atual e executavel.
  identificar_pacote(diretorio, function(pacote)
    if pacote == "main" then
      iniciar(dap, ".", diretorio)
      return
    end

    -- Arquivo de biblioteca:
    -- localizar programas do mesmo modulo.
    encontrar_programas(raiz, function(programas)
      if #programas == 0 then
        preparando = false

        avisar("Go: nenhum pacote main encontrado " .. "neste modulo.", vim.log.levels.WARN)
        return
      end

      if #programas == 1 then
        iniciar(dap, ".", programas[1])
        return
      end

      -- Se houver multiplos executaveis,
      -- permitir selecionar o programa.
      preparando = false

      vim.ui.select(programas, {
        prompt = "Go: selecionar programa para depurar",
        format_item = function(item)
          return item
        end,
      }, function(escolha)
        if escolha then
          iniciar(dap, ".", escolha)
        end
      end)
    end)
  end)
end

return M
