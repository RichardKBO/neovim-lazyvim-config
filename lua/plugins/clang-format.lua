-- ========================================
-- CLANG-FORMAT GLOBAL - C / C++
-- ========================================
-- Respeita configuracoes proprias dos projetos.
-- Quando nao existem, utiliza o Allman global.
-- Funciona no SSD, HDD e arquivos independentes.

local function argumentos_estilo(_, ctx)
  local arquivo = ctx.filename
  local estilo_global = vim.fn.expand("~/.clang-format")

  if arquivo and arquivo ~= "" then
    local diretorio = vim.fs.dirname(vim.fs.normalize(arquivo))

    local configuracoes = vim.fs.find({
      ".clang-format",
      "_clang-format",
    }, {
      path = diretorio,
      upward = true,
    })

    -- Existe configuracao local ou ancestral.
    -- Deixar o clang-format selecionar essa configuracao.
    if #configuracoes > 0 then
      return {}
    end
  end

  -- Sem configuracao encontrada: utilizar o Allman global.
  return {
    "--style=file:" .. estilo_global,
  }
end

return {
  {
    "stevearc/conform.nvim",

    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}

      -- C e C++.
      opts.formatters_by_ft.c = { "clang-format" }
      opts.formatters_by_ft.cpp = { "clang-format" }

      -- Preservar os argumentos originais do Conform.
      -- Acrescentar somente a escolha do estilo.
      opts.formatters["clang-format"] = {
        prepend_args = argumentos_estilo,
      }
    end,
  },
}
