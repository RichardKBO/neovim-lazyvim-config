local M = {}

-- ========================================
-- UTILITARIOS
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

-- ========================================
-- LOCALIZAR MODULO GO
-- ========================================

local function localizar_modulo(arquivo)
  if not arquivo or arquivo == "" then
    return nil
  end

  local diretorio = vim.fs.dirname(normalizar(arquivo))

  local encontrados = vim.fs.find("go.mod", {
    path = diretorio,
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return vim.fs.dirname(encontrados[1])
end

-- ========================================
-- LER INFORMACOES DO GO.MOD
-- ========================================

local function ler_modulo(raiz)
  local arquivo = vim.fs.joinpath(raiz, "go.mod")

  local ok, linhas = pcall(vim.fn.readfile, arquivo)

  if not ok then
    return "Indisponivel", "Indisponivel"
  end

  local modulo = "Nao identificado"
  local versao = "Nao identificada"

  for _, linha in ipairs(linhas) do
    local nome = linha:match("^%s*module%s+(%S+)")
    local go = linha:match("^%s*go%s+([%d%.]+)")

    if nome then
      modulo = nome
    end

    if go then
      versao = go
    end
  end

  return modulo, versao
end

-- ========================================
-- CONSULTAS GO
-- ========================================

local function consultar(argumentos, raiz, callback)
  local ok, erro = pcall(vim.system, argumentos, {
    cwd = raiz,
    text = true,

    -- Evitar downloads e atualizacoes
    -- durante consultas informativas.
    env = {
      GOPROXY = "off",
      GOTOOLCHAIN = "local",
    },
  }, function(resultado)
    vim.schedule(function()
      callback(resultado)
    end)
  end)

  if not ok then
    vim.schedule(function()
      callback({
        code = -1,
        stdout = "",
        stderr = tostring(erro),
      })
    end)
  end
end

local function mensagem_erro(resultado)
  local texto = vim.trim((resultado.stderr or "") .. "\n" .. (resultado.stdout or ""))

  if texto == "" then
    return "Consulta indisponivel"
  end

  return vim.split(texto, "\n")[1]
end

-- ========================================
-- JANELA DE INFORMACOES
-- ========================================

local function exibir(dados)
  local linhas = {
    "GO - INFORMACOES DO MODULO",
    "",
    "Modulo: " .. dados.modulo,
    "Raiz: " .. dados.raiz,
    "Pacote atual: " .. dados.pacote,
    "",
    "Go declarado: " .. dados.versao,
    "Go instalado: " .. dados.instalado,
    "",
    "EXECUTAVEIS DISPONIVEIS",
    "",
  }

  if #dados.programas == 0 then
    table.insert(linhas, "Nenhum executavel encontrado.")
  else
    for indice, programa in ipairs(dados.programas) do
      local relativo = vim.fs.relpath(dados.raiz, programa)

      table.insert(linhas, string.format("%d. %s", indice, relativo and ("./" .. relativo) or programa))
    end
  end

  if dados.erro_programas then
    table.insert(linhas, "")
    table.insert(linhas, "Aviso: " .. dados.erro_programas)
  end

  table.insert(linhas, "")
  table.insert(linhas, "Pressione q ou Esc para fechar.")

  local buffer = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, linhas)

  vim.bo[buffer].modifiable = false
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].filetype = "text"

  local largura = math.max(20, math.min(90, vim.o.columns - 4))

  local altura = math.max(1, math.min(#linhas, vim.o.lines - 4))

  local janela = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = largura,
    height = altura,

    row = math.max(0, math.floor((vim.o.lines - altura) / 2)),

    col = math.max(0, math.floor((vim.o.columns - largura) / 2)),

    style = "minimal",
    border = "rounded",
    title = " Go - Informacoes ",
    title_pos = "center",
  })

  vim.wo[janela].wrap = true

  local function fechar()
    if vim.api.nvim_win_is_valid(janela) then
      vim.api.nvim_win_close(janela, true)
    end
  end

  vim.keymap.set("n", "q", fechar, {
    buffer = buffer,
    silent = true,
    desc = "Go: fechar informacoes",
  })

  vim.keymap.set("n", "<Esc>", fechar, {
    buffer = buffer,
    silent = true,
    desc = "Go: fechar informacoes",
  })
end

-- ========================================
-- INFORMACOES CONTEXTUAIS
-- ========================================

function M.mostrar(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if vim.fn.executable("go") ~= 1 then
    avisar("Go: comando go nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local raiz = localizar_modulo(arquivo)

  if not raiz then
    avisar("Go: modulo go.mod nao encontrado.", vim.log.levels.WARN)
    return
  end

  local modulo, versao = ler_modulo(raiz)

  local dados = {
    modulo = modulo,
    versao = versao,
    raiz = raiz,
    pacote = "Consultando...",
    instalado = "Consultando...",
    programas = {},
    erro_programas = nil,
  }

  local pendentes = 3

  local function concluir()
    pendentes = pendentes - 1

    if pendentes == 0 then
      exibir(dados)
    end
  end

  -- ========================================
  -- CONSULTAR VERSAO INSTALADA
  -- ========================================

  consultar(
    {
      "go",
      "version",
    },
    raiz,
    function(resultado)
      if resultado.code == 0 then
        dados.instalado = vim.trim(resultado.stdout or "")
      else
        dados.instalado = mensagem_erro(resultado)
      end

      concluir()
    end
  )

  -- ========================================
  -- IDENTIFICAR PACOTE ATUAL
  -- ========================================

  consultar(
    {
      "go",
      "list",
      "-mod=readonly",
      "-f",
      "{{.Name}}",
      ".",
    },
    vim.fs.dirname(normalizar(arquivo)),
    function(resultado)
      if resultado.code == 0 then
        dados.pacote = vim.trim(resultado.stdout or "")
      else
        dados.pacote = mensagem_erro(resultado)
      end

      concluir()
    end
  )

  -- ========================================
  -- ENCONTRAR EXECUTAVEIS DO MODULO
  -- ========================================

  consultar(
    {
      "go",
      "list",
      "-mod=readonly",
      "-f",
      '{{if eq .Name "main"}}{{.Dir}}{{end}}',
      "./...",
    },
    raiz,
    function(resultado)
      if resultado.code == 0 then
        local vistos = {}

        for linha in ((resultado.stdout or "") .. "\n"):gmatch("(.-)\n") do
          local diretorio = vim.trim(linha)

          if diretorio ~= "" then
            diretorio = vim.fs.normalize(diretorio)

            if not vistos[diretorio] then
              vistos[diretorio] = true

              table.insert(dados.programas, diretorio)
            end
          end
        end

        table.sort(dados.programas)
      else
        dados.erro_programas = mensagem_erro(resultado)
      end

      concluir()
    end
  )
end

return M
