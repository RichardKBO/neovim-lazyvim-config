-- ========================================
-- RUBY - CRIACAO DE ELEMENTOS
-- Classes, modulos e arquivos Ruby
-- ========================================

local M = {}

local tipos = {
  { nome = "Nova classe Ruby", tipo = "class" },
  { nome = "Novo modulo Ruby", tipo = "module" },
  { nome = "Novo arquivo Ruby", tipo = "file" },
}

-- ========================================
-- VALIDACAO DOS NOMES
-- ========================================

local function identificador_valido(nome)
  return nome:match("^[A-Z][A-Za-z0-9_]*$") ~= nil
end

local function arquivo_valido(nome)
  return nome:match("^[a-z_][a-z0-9_]*$") ~= nil
end

-- Converter MinhaClasse para minha_classe.
-- Exemplos:
-- MinhaClasse -> minha_classe
-- HTTPServer  -> http_server
-- Produto2D   -> produto2_d
local function snake_case(nome)
  return nome:gsub("(%u+)(%u%l)", "%1_%2"):gsub("([%l%d])(%u)", "%1_%2"):lower()
end

local function normalizar_nome(tipo, nome)
  nome = vim.trim(nome)

  if tipo == "file" then
    if nome:sub(-3) == ".rb" then
      nome = nome:sub(1, -4)
    end

    if not arquivo_valido(nome) then
      return nil, "Nome de arquivo invalido. Use snake_case."
    end

    return nome
  end

  if not identificador_valido(nome) then
    return nil, "Nome invalido. Use uma constante Ruby como MinhaClasse."
  end

  return nome
end

-- ========================================
-- GERAR CONTEUDO
-- ========================================

local function gerar_conteudo(tipo, nome)
  local linhas = {
    "# frozen_string_literal: true",
    "",
  }

  if tipo == "class" then
    vim.list_extend(linhas, {
      "class " .. nome,
      "end",
    })
  elseif tipo == "module" then
    vim.list_extend(linhas, {
      "module " .. nome,
      "end",
    })
  end

  return linhas
end

-- ========================================
-- CRIAR ARQUIVO COM SEGURANCA
-- ========================================

local function criar_arquivo(diretorio, tipo, nome)
  local nome_valido, erro = normalizar_nome(tipo, nome)

  if not nome_valido then
    vim.notify("Ruby: " .. erro, vim.log.levels.ERROR)
    return
  end

  local nome_arquivo = nome_valido

  if tipo ~= "file" then
    nome_arquivo = snake_case(nome_valido)
  end

  local destino = vim.fs.joinpath(diretorio, nome_arquivo .. ".rb")

  -- Verificacao antecipada para uma mensagem amigavel.
  if vim.uv.fs_lstat(destino) then
    vim.notify("Ruby: arquivo ja existe: " .. destino, vim.log.levels.WARN)
    return
  end

  local conteudo = gerar_conteudo(tipo, nome_valido)
  local texto = table.concat(conteudo, "\n") .. "\n"

  -- "wx" cria o arquivo exclusivamente.
  -- Se ele ja existir, a abertura falha sem sobrescrever.
  local descritor, erro_abertura = vim.uv.fs_open(destino, "wx", 420)

  if not descritor then
    if vim.uv.fs_lstat(destino) then
      vim.notify("Ruby: arquivo ja existe: " .. destino, vim.log.levels.WARN)
    else
      vim.notify("Ruby: falha ao criar arquivo: " .. tostring(erro_abertura), vim.log.levels.ERROR)
    end

    return
  end

  local gravados, erro_gravacao = vim.uv.fs_write(descritor, texto, 0)

  local fechou, erro_fechamento = vim.uv.fs_close(descritor)

  if gravados ~= #texto or not fechou then
    -- Remover somente o arquivo incompleto que acabamos
    -- de criar, preservando arquivos preexistentes.
    vim.uv.fs_unlink(destino)

    vim.notify(
      "Ruby: falha ao gravar arquivo: " .. tostring(erro_gravacao or erro_fechamento or "gravacao incompleta"),
      vim.log.levels.ERROR
    )

    return
  end

  vim.notify("Ruby: criado " .. nome_arquivo .. ".rb", vim.log.levels.INFO)

  local abriu = pcall(vim.cmd.edit, vim.fn.fnameescape(destino))

  if not abriu then
    vim.notify("Arquivo criado, mas nao foi possivel abri-lo.", vim.log.levels.WARN)
  end
end

-- ========================================
-- INTERFACE DE CRIACAO
-- ========================================

function M.criar(arquivo)
  local buffer = vim.api.nvim_get_current_buf()
  local janela = vim.api.nvim_get_current_win()

  arquivo = arquivo or vim.api.nvim_buf_get_name(buffer)

  if arquivo == "" then
    vim.notify("Ruby: abra um arquivo antes de criar elementos.", vim.log.levels.WARN)
    return
  end

  local diretorio = vim.fs.dirname(arquivo)

  if vim.fn.isdirectory(diretorio) ~= 1 then
    vim.notify("Ruby: diretorio de destino inexistente.", vim.log.levels.ERROR)
    return
  end

  vim.ui.select(tipos, {
    prompt = "Ruby - Novo elemento",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    local pergunta = "Nome da classe: "

    if escolha.tipo == "module" then
      pergunta = "Nome do modulo: "
    elseif escolha.tipo == "file" then
      pergunta = "Nome do arquivo (snake_case): "
    end

    vim.ui.input({
      prompt = pergunta,
    }, function(nome)
      if nome == nil then
        return
      end

      if not vim.api.nvim_win_is_valid(janela) then
        vim.notify("Ruby: janela original indisponivel.", vim.log.levels.WARN)
        return
      end

      if vim.api.nvim_win_get_buf(janela) ~= buffer then
        vim.notify("Ruby: o arquivo original mudou.", vim.log.levels.WARN)
        return
      end

      vim.api.nvim_set_current_win(janela)

      criar_arquivo(diretorio, escolha.tipo, nome)
    end)
  end)
end

return M
