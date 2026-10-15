local M = {}

local cargo = require("languages.rust.cargo")
local crates = require("languages.rust.crates")
local modulos = require("languages.rust.modules")
local picker = require("languages.rust.picker")
local comandos = require("languages.rust.commands")
local dependencias_menu = require("languages.rust.dependencies_menu")

local function notificar(mensagem, nivel)
  vim.notify("Rust: " .. tostring(mensagem), nivel or vim.log.levels.INFO)
end

local function perguntar(mensagem, callback)
  vim.ui.input({
    prompt = mensagem,
  }, function(resposta)
    if not resposta then
      return
    end

    resposta = vim.trim(resposta)

    if resposta == "" then
      notificar("Nenhum nome ou caminho informado.", vim.log.levels.WARN)
      return
    end

    callback(resposta)
  end)
end

local function selecionar_tipo(callback)
  local tipos = {
    {
      nome = "Aplicacao executavel (bin)",
      valor = "bin",
    },
    {
      nome = "Biblioteca Rust (lib)",
      valor = "lib",
    },
  }

  vim.ui.select(tipos, {
    prompt = "Tipo de crate:",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if escolhido then
      callback(escolhido.valor)
    end
  end)
end

local function abrir_arquivo(caminho)
  if not caminho or vim.fn.filereadable(caminho) ~= 1 then
    notificar("Arquivo nao encontrado: " .. tostring(caminho), vim.log.levels.ERROR)
    return
  end

  vim.cmd.edit(vim.fn.fnameescape(caminho))
end

local function abrir_crate_criada(manifesto, tipo)
  local nome_arquivo = tipo == "lib" and "lib.rs" or "main.rs"

  local arquivo = vim.fs.joinpath(vim.fs.dirname(manifesto), "src", nome_arquivo)

  notificar("Crate criada: " .. manifesto)

  abrir_arquivo(arquivo)
end

local function criar_crate_workspace(referencia)
  selecionar_tipo(function(tipo)
    perguntar("Caminho relativo ao workspace: ", function(caminho)
      local manifesto, erro = crates.criar_no_workspace(caminho, tipo, referencia)

      if not manifesto then
        notificar(erro, vim.log.levels.ERROR)
        return
      end

      abrir_crate_criada(manifesto, tipo)
    end)
  end)
end

local function criar_projeto_independente()
  selecionar_tipo(function(tipo)
    perguntar("Destino do projeto (caminho completo ou ~/): ", function(caminho)
      local manifesto, erro = crates.criar_independente(caminho, tipo)

      if not manifesto then
        notificar(erro, vim.log.levels.ERROR)
        return
      end

      abrir_crate_criada(manifesto, tipo)
    end)
  end)
end

local function criar_modulo(referencia)
  if not referencia:match("%.rs$") then
    notificar("Abra o arquivo Rust que sera o pai do modulo.", vim.log.levels.WARN)
    return
  end

  local formatos = {
    {
      nome = "Modulo em arquivo (produto.rs)",
      valor = "arquivo",
    },
    {
      nome = "Modulo em pasta (produto/mod.rs)",
      valor = "pasta",
    },
  }

  vim.ui.select(formatos, {
    prompt = "Estrutura do modulo:",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    perguntar("Nome do modulo: ", function(nome)
      local arquivo, erro = modulos.criar(nome, escolhido.valor, referencia)

      if not arquivo then
        notificar(erro, vim.log.levels.ERROR)
        return
      end

      notificar("Modulo criado: " .. arquivo)

      abrir_arquivo(arquivo)
    end)
  end)
end

local function possui_workspace(contexto)
  if vim.fn.filereadable(contexto.workspace_manifesto) ~= 1 then
    return false
  end

  for _, linha in ipairs(vim.fn.readfile(contexto.workspace_manifesto)) do
    if linha:match("^%s*%[workspace%]") then
      return true
    end
  end

  return false
end

local function executar_cargo(acao, referencia)
  local sucesso, erro = comandos.executar(acao, referencia)

  if not sucesso then
    notificar(erro or "Falha ao executar Cargo.", vim.log.levels.ERROR)
  end
end

function M.abrir()
  -- Capturar a referencia antes de abrir menus flutuantes.
  local referencia = vim.api.nvim_buf_get_name(0)

  local contexto = cargo.contexto(referencia)

  local opcoes = {}

  if contexto then
    if possui_workspace(contexto) then
      table.insert(opcoes, {
        id = "crate_workspace",
        nome = "Criar crate no workspace",
      })
    end

    if contexto.pacote and referencia:match("%.rs$") then
      table.insert(opcoes, {
        id = "modulo",
        nome = "Criar modulo ou submodulo",
      })
    end
  end

  table.insert(opcoes, {
    id = "independente",
    nome = "Criar projeto Cargo independente",
  })

  if contexto then
    if contexto.pacote then
      table.insert(opcoes, {
        id = "manifesto_crate",
        nome = "Abrir Cargo.toml da crate",
      })

      table.insert(opcoes, {
        id = "arquivos_crate",
        nome = "Pesquisar arquivos da crate",
      })

      -- Submenu independente para dependencias.
      table.insert(opcoes, {
        id = "dependencias",
        nome = "Gerenciar dependencias",
      })
    end

    table.insert(opcoes, {
      id = "manifesto_workspace",
      nome = "Abrir Cargo.toml do workspace",
    })

    table.insert(opcoes, {
      id = "arquivos_workspace",
      nome = "Pesquisar arquivos do workspace",
    })

    table.insert(opcoes, {
      id = "cargo_check",
      nome = "Cargo Check - verificar compilacao",
    })

    table.insert(opcoes, {
      id = "cargo_build",
      nome = "Cargo Build - compilar projeto",
    })

    table.insert(opcoes, {
      id = "cargo_test",
      nome = "Cargo Test - executar testes",
    })

    table.insert(opcoes, {
      id = "cargo_clippy",
      nome = "Cargo Clippy - analisar codigo",
    })

    table.insert(opcoes, {
      id = "cargo_fmt_check",
      nome = "Cargo Fmt Check - verificar formatacao",
    })
  end

  vim.ui.select(opcoes, {
    prompt = "Rust Menu - Gerenciamento Cargo",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    local acao = escolhido.id

    if acao == "crate_workspace" then
      criar_crate_workspace(referencia)
    elseif acao == "modulo" then
      criar_modulo(referencia)
    elseif acao == "independente" then
      criar_projeto_independente()
    elseif acao == "manifesto_crate" then
      abrir_arquivo(contexto.manifesto)
    elseif acao == "arquivos_crate" then
      picker.arquivos_crate()
    elseif acao == "dependencias" then
      dependencias_menu.abrir(referencia)
    elseif acao == "manifesto_workspace" then
      abrir_arquivo(contexto.workspace_manifesto)
    elseif acao == "arquivos_workspace" then
      picker.arquivos_workspace()
    elseif acao == "cargo_check" then
      executar_cargo("check", referencia)
    elseif acao == "cargo_build" then
      executar_cargo("build", referencia)
    elseif acao == "cargo_test" then
      executar_cargo("test", referencia)
    elseif acao == "cargo_clippy" then
      executar_cargo("clippy", referencia)
    elseif acao == "cargo_fmt_check" then
      executar_cargo("fmt_check", referencia)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("RustMenu", M.abrir, {
    desc = "Menu de gerenciamento Rust e Cargo",
    force = true,
  })
end

return M
