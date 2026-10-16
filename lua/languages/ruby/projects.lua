-- ========================================
-- RUBY - GERENCIAMENTO DE PROJETOS
-- Projeto simples e projeto com Bundler
-- ========================================

local M = {}

local modelos = {
  {
    nome = "Novo projeto Ruby simples",
    tipo = "simples",
  },
  {
    nome = "Novo projeto Ruby com Bundler",
    tipo = "bundler",
  },
}

-- ========================================
-- IDENTIFICAR VERSAO DO RUBY
-- ========================================

local function versao_ruby_atual()
  local ruby = vim.fn.exepath("ruby")

  if ruby == "" then
    return ""
  end

  local resultado = vim.fn.system({
    ruby,
    "-e",
    "print RUBY_VERSION",
  })

  if vim.v.shell_error ~= 0 then
    return ""
  end

  return vim.trim(resultado)
end

-- ========================================
-- VALIDAR INFORMACOES
-- ========================================

local function validar(dados)
  if dados.tipo ~= "simples" and dados.tipo ~= "bundler" then
    return "Modelo de projeto invalido."
  end

  if not dados.nome or not dados.nome:match("^[A-Za-z][A-Za-z0-9_-]*$") then
    return "Nome invalido. Use letras, numeros, _ ou -."
  end

  if not dados.diretorio or vim.trim(dados.diretorio) == "" then
    return "Informe o diretorio de destino."
  end

  if not dados.versao or (not dados.versao:match("^%d+%.%d+$") and not dados.versao:match("^%d+%.%d+%.%d+$")) then
    return "Versao Ruby invalida. Exemplo: 4.0.7."
  end

  return nil
end

-- ========================================
-- ARQUIVOS INICIAIS
-- ========================================

local function arquivos_do_projeto(raiz, dados)
  local arquivos = {
    {
      caminho = vim.fs.joinpath(raiz, "main.rb"),
      linhas = {
        "# frozen_string_literal: true",
        "",
        'puts "Projeto Ruby funcionando!"',
      },
    },
    {
      caminho = vim.fs.joinpath(raiz, ".ruby-version"),
      linhas = {
        dados.versao,
      },
    },
    {
      caminho = vim.fs.joinpath(raiz, ".gitignore"),
      linhas = {
        ".bundle/",
        "vendor/bundle/",
        "coverage/",
        "log/",
        "tmp/",
        ".idea/",
        ".ruby-lsp/",
        ".env",
        "*.gem",
      },
    },
  }

  if dados.tipo == "bundler" then
    table.insert(arquivos, {
      caminho = vim.fs.joinpath(raiz, "Gemfile"),
      linhas = {
        'source "https://rubygems.org"',
        "",
        "# Adicione as gems do projeto aqui.",
      },
    })
  end

  return arquivos
end

-- ========================================
-- GERAR PROJETO
-- ========================================

function M.gerar(dados)
  local erro = validar(dados)

  if erro then
    return false, erro
  end

  local pai = vim.fn.fnamemodify(vim.fn.expand(dados.diretorio), ":p")

  pai = vim.fs.normalize(pai)

  -- Exigir um diretorio pai existente.
  if vim.fn.isdirectory(pai) ~= 1 then
    return false, "Diretorio de destino inexistente: " .. pai
  end

  local raiz = vim.fs.joinpath(pai, dados.nome)

  -- Nunca reutilizar ou sobrescrever um projeto existente.
  if vim.uv.fs_lstat(raiz) then
    return false, "O projeto ja existe: " .. raiz
  end

  -- Criacao exclusiva da pasta do projeto.
  local criou, erro_pasta = vim.uv.fs_mkdir(raiz, 493)

  if not criou then
    return false, "Falha ao criar projeto: " .. tostring(erro_pasta)
  end

  local arquivos = arquivos_do_projeto(raiz, dados)
  local criados = {}
  local falha = nil

  for _, arquivo in ipairs(arquivos) do
    -- "wx": criar somente se o arquivo nao existir.
    local descritor, erro_abertura = vim.uv.fs_open(arquivo.caminho, "wx", 420)

    if not descritor then
      falha = "Falha ao criar " .. arquivo.caminho .. ": " .. tostring(erro_abertura)
      break
    end

    -- Registrar imediatamente para permitir limpeza
    -- mesmo se a gravacao falhar.
    table.insert(criados, arquivo.caminho)

    local texto = table.concat(arquivo.linhas, "\n") .. "\n"

    local gravados, erro_gravacao = vim.uv.fs_write(descritor, texto, 0)

    local fechou, erro_fechamento = vim.uv.fs_close(descritor)

    if gravados ~= #texto or not fechou then
      falha = "Falha ao gravar "
        .. arquivo.caminho
        .. ": "
        .. tostring(erro_gravacao or erro_fechamento or "gravacao incompleta")
      break
    end
  end

  -- ====================================
  -- LIMPEZA EM CASO DE FALHA
  -- ====================================

  if falha then
    local limpeza_ok = true

    for indice = #criados, 1, -1 do
      if not vim.uv.fs_unlink(criados[indice]) then
        limpeza_ok = false
      end
    end

    if not vim.uv.fs_rmdir(raiz) then
      limpeza_ok = false
    end

    if not limpeza_ok then
      falha = falha .. ". A limpeza foi incompleta; verifique: " .. raiz
    end

    return false, falha
  end

  local principal = vim.fs.joinpath(raiz, "main.rb")

  return true, raiz, principal
end

-- ========================================
-- INTERFACE DE CRIACAO
-- ========================================

function M.criar()
  vim.ui.select(modelos, {
    prompt = "Ruby - Criar novo projeto",

    format_item = function(item)
      return item.nome
    end,
  }, function(modelo)
    if not modelo then
      return
    end

    local dados = {
      tipo = modelo.tipo,
    }

    local perguntas = {
      {
        chave = "nome",
        texto = "Nome do projeto: ",
        padrao = "",
      },
      {
        chave = "diretorio",
        texto = "Pasta onde criar o projeto: ",
        padrao = vim.fn.getcwd(),
      },
      {
        chave = "versao",
        texto = "Versao Ruby (.ruby-version): ",
        padrao = versao_ruby_atual(),
      },
    }

    local function proxima_pergunta(indice)
      local pergunta = perguntas[indice]

      if not pergunta then
        local sucesso, resultado, principal = M.gerar(dados)

        if not sucesso then
          vim.notify("Ruby: " .. resultado, vim.log.levels.ERROR)
          return
        end

        vim.notify("Projeto Ruby criado: " .. resultado, vim.log.levels.INFO)

        local abriu = pcall(vim.cmd.edit, vim.fn.fnameescape(principal))

        if not abriu then
          vim.notify("Projeto criado, mas nao foi possivel abrir main.rb.", vim.log.levels.WARN)
        end

        return
      end

      vim.ui.input({
        prompt = pergunta.texto,
        default = pergunta.padrao,
      }, function(valor)
        if valor == nil then
          vim.notify("Criacao de projeto cancelada.")
          return
        end

        dados[pergunta.chave] = vim.trim(valor)

        proxima_pergunta(indice + 1)
      end)
    end

    proxima_pergunta(1)
  end)
end

return M
