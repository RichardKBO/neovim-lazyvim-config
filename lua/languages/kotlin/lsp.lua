local M = {}

-- Localizar automaticamente o servidor Kotlin LSP
-- instalado fora do Mason.
local function localizar_servidor()
  local pasta_base = vim.fn.expand("~/.local/share/kotlin-lsp")

  local instalacoes = vim.fn.glob(pasta_base .. "/kotlin-server-*", false, true)

  local candidatos = {}

  for _, pasta in ipairs(instalacoes) do
    local nome = vim.fs.basename(pasta)

    local versao = nome:match("^kotlin%-server%-(%d+%.%d+%.%d+)$")

    local executavel = vim.fs.joinpath(pasta, "bin", "intellij-server")

    if versao and vim.fn.isdirectory(pasta) == 1 and vim.fn.executable(executavel) == 1 then
      local numeros = {}

      for numero in versao:gmatch("%d+") do
        table.insert(numeros, tonumber(numero))
      end

      table.insert(candidatos, {
        pasta = pasta,
        versao = numeros,
      })
    end
  end

  -- Comparar os componentes numericamente.
  table.sort(candidatos, function(a, b)
    for i = 1, 3 do
      if a.versao[i] ~= b.versao[i] then
        return a.versao[i] > b.versao[i]
      end
    end

    return false
  end)

  if #candidatos == 0 then
    return nil
  end

  return candidatos[1].pasta
end

function M.setup()
  local servidor = localizar_servidor()

  if not servidor then
    vim.notify(
      "Kotlin LSP: nenhuma instalacao valida encontrada " .. "em ~/.local/share/kotlin-lsp.",
      vim.log.levels.ERROR
    )
    return
  end

  -- Configurar a instalacao externa encontrada.
  vim.env.KOTLIN_LSP_DIR = servidor

  -- Inicializar o plugin existente.
  require("kotlin").setup()
end

return M
