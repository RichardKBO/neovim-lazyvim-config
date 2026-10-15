local M = {}

local cargo = require("languages.rust.cargo")
local dependencias = require("languages.rust.dependencies")

local function notificar(mensagem, nivel)
  vim.notify("Rust: " .. tostring(mensagem), nivel or vim.log.levels.INFO)
end

local function perguntar(mensagem, callback, permite_vazio)
  vim.ui.input({
    prompt = mensagem,
  }, function(resposta)
    if resposta == nil then
      return
    end

    resposta = vim.trim(resposta)

    if resposta == "" and not permite_vazio then
      notificar("Informe um valor valido.", vim.log.levels.WARN)
      return
    end

    callback(resposta)
  end)
end

local function selecionar_tipo(callback)
  local tipos = {
    { nome = "Normal", valor = "normal" },
    { nome = "Desenvolvimento (dev)", valor = "dev" },
    { nome = "Compilacao (build)", valor = "build" },
  }

  vim.ui.select(tipos, {
    prompt = "Tipo de dependencia:",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if escolhido then
      callback(escolhido.valor)
    end
  end)
end

local function verificar_resultado(sucesso, erro)
  if not sucesso then
    notificar(erro or "Operacao nao iniciada.", vim.log.levels.ERROR)
  end
end

-- Adicionar ou simular uma dependencia do crates.io.
local function adicionar_crates_io(referencia, simular)
  perguntar("Nome da dependencia: ", function(nome)
    perguntar("Versao (Enter para automatica): ", function(versao)
      selecionar_tipo(function(tipo)
        local sucesso, erro = dependencias.adicionar(nome, versao, tipo, referencia, simular)

        verificar_resultado(sucesso, erro)
      end)
    end, true)
  end)
end

-- Adicionar ou simular uma biblioteca local.
local function adicionar_local(referencia, simular)
  perguntar("Caminho da crate local: ", function(caminho)
    selecionar_tipo(function(tipo)
      local sucesso, erro = dependencias.adicionar_local(caminho, tipo, referencia, simular)

      verificar_resultado(sucesso, erro)
    end)
  end)
end

-- Listar as dependencias realmente declaradas pela crate.
local function remover_dependencia(referencia)
  local contexto, erro = cargo.contexto(referencia)

  if not contexto then
    notificar(erro, vim.log.levels.ERROR)
    return
  end

  if not contexto.pacote then
    notificar("Selecione uma crate, nao um workspace virtual.", vim.log.levels.WARN)
    return
  end

  local itens = {}

  for _, dependencia in ipairs(contexto.pacote.dependencies or {}) do
    table.insert(itens, {
      nome = dependencia.rename or dependencia.name,
      tipo = dependencia.kind or "normal",
    })
  end

  if #itens == 0 then
    notificar("Esta crate nao possui dependencias.")
    return
  end

  vim.ui.select(itens, {
    prompt = "Selecione a dependencia para remover:",
    format_item = function(item)
      return item.nome .. " [" .. item.tipo .. "]"
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    -- Nunca remover uma dependencia sem confirmacao.
    vim.ui.select({
      "Cancelar",
      "Confirmar remocao",
    }, {
      prompt = "Remover " .. escolhido.nome .. "?",
    }, function(confirmacao)
      if confirmacao ~= "Confirmar remocao" then
        return
      end

      local sucesso, erro_remocao = dependencias.remover(escolhido.nome, escolhido.tipo, referencia)

      verificar_resultado(sucesso, erro_remocao)
    end)
  end)
end

function M.abrir(referencia)
  referencia = referencia or vim.api.nvim_buf_get_name(0)

  local contexto, erro = cargo.contexto(referencia)

  if not contexto then
    notificar(erro, vim.log.levels.ERROR)
    return
  end

  if not contexto.pacote then
    notificar("Abra um arquivo pertencente a uma crate.", vim.log.levels.WARN)
    return
  end

  local opcoes = {
    {
      id = "adicionar",
      nome = "Adicionar dependencia do crates.io",
    },
    {
      id = "simular",
      nome = "Simular adicao do crates.io",
    },
    {
      id = "local",
      nome = "Adicionar biblioteca local",
    },
    {
      id = "simular_local",
      nome = "Simular biblioteca local",
    },
    {
      id = "remover",
      nome = "Remover dependencia existente",
    },
  }

  vim.ui.select(opcoes, {
    prompt = "Rust - Gerenciar dependencias",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    if escolhido.id == "adicionar" then
      adicionar_crates_io(referencia, false)
    elseif escolhido.id == "simular" then
      adicionar_crates_io(referencia, true)
    elseif escolhido.id == "local" then
      adicionar_local(referencia, false)
    elseif escolhido.id == "simular_local" then
      adicionar_local(referencia, true)
    elseif escolhido.id == "remover" then
      remover_dependencia(referencia)
    end
  end)
end

return M
