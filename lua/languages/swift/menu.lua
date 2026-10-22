-- ========================================
-- SWIFT - MENU DE PROJETOS
-- ========================================

local M = {}

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "SwiftMenu",
  })
end

local function pasta_projetos()
  return vim.fs.joinpath(vim.fn.expand("~"), "Projetos", "Swift")
end

-- Abrir o arquivo principal de um projeto SwiftPM.
local function abrir_arquivo_do_projeto(raiz)
  local manifesto = vim.fs.joinpath(raiz, "Package.swift")

  if vim.fn.filereadable(manifesto) ~= 1 then
    avisar("Package.swift nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local arquivos = vim.fn.globpath(raiz, "Sources/**/*.swift", false, true)

  table.sort(arquivos)

  local arquivo = manifesto

  for _, candidato in ipairs(arquivos) do
    if vim.fs.basename(candidato) == "main.swift" then
      arquivo = candidato
      break
    end
  end

  if arquivo == manifesto and #arquivos > 0 then
    arquivo = arquivos[1]
  end

  vim.cmd("edit " .. vim.fn.fnameescape(arquivo))
end

-- Criar um pacote executavel usando SwiftPM.
local function criar_projeto()
  local swift = vim.fn.exepath("swift")

  if swift == "" then
    avisar("Swift nao encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = "Nome do projeto Swift: ",
  }, function(nome)
    if nome == nil then
      return
    end

    nome = vim.trim(nome)

    -- Identificadores simples e seguros para o SwiftPM.
    if not nome:match("^[A-Za-z_][A-Za-z0-9_]*$") then
      avisar("Use letras, numeros e _. O nome deve comecar por letra ou _.", vim.log.levels.WARN)
      return
    end

    local base = pasta_projetos()
    local raiz = vim.fs.joinpath(base, nome)

    if vim.uv.fs_stat(raiz) then
      avisar("O projeto ja existe: " .. raiz, vim.log.levels.WARN)
      return
    end

    if vim.fn.mkdir(base, "p") == 0 then
      avisar("Nao foi possivel preparar: " .. base, vim.log.levels.ERROR)
      return
    end

    if vim.fn.mkdir(raiz) == 0 then
      avisar("Nao foi possivel criar: " .. raiz, vim.log.levels.ERROR)
      return
    end

    avisar("Criando projeto Swift: " .. nome)

    vim.system({
      swift,
      "package",
      "init",
      "--name",
      nome,
      "--type",
      "executable",
    }, {
      cwd = raiz,
      text = true,
    }, function(resultado)
      vim.schedule(function()
        if resultado.code ~= 0 then
          local detalhes = vim.trim(resultado.stderr or "")

          if detalhes == "" then
            detalhes = vim.trim(resultado.stdout or "")
          end

          avisar("Falha ao criar projeto SwiftPM:\n" .. detalhes, vim.log.levels.ERROR)
          return
        end

        local manifesto = vim.fs.joinpath(raiz, "Package.swift")

        if vim.fn.filereadable(manifesto) ~= 1 then
          avisar("SwiftPM terminou sem gerar Package.swift.", vim.log.levels.ERROR)
          return
        end

        abrir_arquivo_do_projeto(raiz)

        avisar("Projeto criado com sucesso!\n" .. raiz)
      end)
    end)
  end)
end

-- Selecionar um projeto ja existente.
local function abrir_projeto()
  local base = pasta_projetos()

  if vim.fn.isdirectory(base) ~= 1 then
    avisar("Pasta de projetos Swift nao encontrada.", vim.log.levels.WARN)
    return
  end

  local projetos = {}

  for _, nome in ipairs(vim.fn.readdir(base)) do
    local raiz = vim.fs.joinpath(base, nome)
    local manifesto = vim.fs.joinpath(raiz, "Package.swift")

    if vim.fn.filereadable(manifesto) == 1 then
      table.insert(projetos, {
        nome = nome,
        raiz = raiz,
      })
    end
  end

  if #projetos == 0 then
    avisar("Nenhum projeto SwiftPM encontrado.", vim.log.levels.WARN)
    return
  end

  table.sort(projetos, function(a, b)
    return a.nome < b.nome
  end)

  vim.ui.select(projetos, {
    prompt = "Selecione um projeto Swift:",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      abrir_arquivo_do_projeto(escolha.raiz)
    end
  end)
end

function M.abrir()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  local opcoes = {
    {
      nome = "Criar novo projeto Swift",
      executar = criar_projeto,
    },
    {
      nome = "Executar arquivo Swift atual (F6)",
      executar = function()
        if not vim.api.nvim_buf_is_valid(buffer) or vim.api.nvim_get_current_buf() ~= buffer then
          avisar("O buffer original mudou.", vim.log.levels.WARN)
          return
        end

        if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "swift" then
          avisar("Abra um arquivo .swift primeiro.", vim.log.levels.WARN)
          return
        end

        require("languages.swift.runner").executar(arquivo)
      end,
    },
    {
      nome = "Abrir projeto Swift existente",
      executar = abrir_projeto,
    },
  }

  vim.ui.select(opcoes, {
    prompt = "Swift - Gerenciamento de projetos",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      vim.schedule(escolha.executar)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("SwiftMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos Swift",
  })
end

return M
