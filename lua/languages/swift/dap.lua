-- ========================================
-- SWIFT - DEBUGGER
-- nvim-dap + LLDB-DAP + SwiftPM
-- ========================================

local M = {}

-- Localizar o projeto SwiftPM do arquivo atual.
local function localizar_projeto()
  local arquivo = vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    error("Swift: nenhum arquivo aberto.")
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    error("Swift: arquivo nao encontrado.")
  end

  if vim.bo.modified then
    error("Swift: salve o arquivo com :w antes de depurar.")
  end

  local manifesto = vim.fs.find("Package.swift", {
    upward = true,
    path = vim.fs.dirname(arquivo),
  })[1]

  if not manifesto then
    error("Swift: Package.swift nao encontrado.")
  end

  return vim.fs.dirname(manifesto), arquivo
end

-- Executar um comando SwiftPM no projeto correto.
local function executar_swift(swift, raiz, argumentos)
  local comando = { swift }

  vim.list_extend(comando, argumentos)

  local resultado = vim
    .system(comando, {
      cwd = raiz,
      text = true,
    })
    :wait()

  if resultado.code ~= 0 then
    error("SwiftPM: comando falhou:\n" .. (resultado.stderr or "") .. "\n" .. (resultado.stdout or ""))
  end

  return vim.trim(resultado.stdout or "")
end

-- Consultar metadados do pacote.
local function obter_metadata(swift, raiz)
  local resposta = executar_swift(swift, raiz, {
    "package",
    "describe",
    "--type",
    "json",
  })

  local ok, metadata = pcall(vim.json.decode, resposta)

  if not ok or type(metadata) ~= "table" then
    error("Swift: metadados do SwiftPM invalidos.")
  end

  return metadata
end

-- Listar somente produtos executaveis.
local function obter_executaveis(metadata)
  local produtos = {}

  for _, produto in ipairs(metadata.products or {}) do
    if type(produto.type) == "table" and produto.type.executable ~= nil then
      table.insert(produtos, produto)
    end
  end

  return produtos
end

-- Identificar o executavel que contem o arquivo aberto.
local function identificar_produto(metadata, produtos, raiz, arquivo)
  local encontrados = {}
  local arquivo_atual = vim.fs.normalize(arquivo)

  for _, target in ipairs(metadata.targets or {}) do
    if target.type == "executable" then
      for _, fonte in ipairs(target.sources or {}) do
        local caminho = vim.fs.normalize(vim.fs.joinpath(raiz, target.path, fonte))

        if caminho == arquivo_atual then
          for _, produto in ipairs(produtos) do
            if vim.tbl_contains(produto.targets or {}, target.name) then
              table.insert(encontrados, produto)
            end
          end

          break
        end
      end
    end
  end

  if #encontrados == 1 then
    return encontrados[1]
  end

  if #produtos == 1 then
    return produtos[1]
  end

  -- Quando ha varios executaveis sem correspondencia
  -- unica, solicitar a escolha ao usuario.
  local opcoes = {
    "Selecione o executavel Swift:",
  }

  for indice, produto in ipairs(produtos) do
    table.insert(opcoes, indice .. ". " .. produto.name)
  end

  local escolha = vim.fn.inputlist(opcoes)

  if escolha < 1 or escolha > #produtos then
    error("Swift: selecao de executavel cancelada.")
  end

  return produtos[escolha]
end

-- Compilar e localizar o binario para o LLDB.
local function localizar_executavel()
  local raiz, arquivo = localizar_projeto()
  local swift = vim.fn.exepath("swift")

  if swift == "" then
    error("Swift: compilador nao encontrado no PATH.")
  end

  local metadata = obter_metadata(swift, raiz)
  local produtos = obter_executaveis(metadata)

  if #produtos == 0 then
    error("Swift: pacote sem produto executavel.")
  end

  local produto = identificar_produto(metadata, produtos, raiz, arquivo)

  vim.notify("Swift: compilando " .. produto.name .. "...", vim.log.levels.INFO)

  -- Falhas de compilacao interrompem a depuracao.
  executar_swift(swift, raiz, {
    "build",
    "--product",
    produto.name,
  })

  local diretorio_binario = executar_swift(swift, raiz, {
    "build",
    "--show-bin-path",
  })

  local executavel = vim.fs.joinpath(diretorio_binario, produto.name)

  if vim.fn.executable(executavel) ~= 1 then
    error("Swift: executavel compilado nao encontrado:\n" .. executavel)
  end

  return executavel
end

function M.setup()
  local dap = require("dap")

  -- Adapter exclusivo do Swift.
  -- Nao modifica o CodeLLDB das outras linguagens.
  -- O executavel sera localizado quando a depuracao for iniciada.
  dap.adapters.swift_lldb = {
    type = "executable",
    command = "lldb-dap",
  }

  dap.configurations.swift = {
    {
      name = "Swift: depurar projeto atual",
      type = "swift_lldb",
      request = "launch",

      program = localizar_executavel,

      cwd = function()
        local raiz = localizar_projeto()
        return raiz
      end,

      stopOnEntry = false,
      args = {},
    },
  }
end

return M
