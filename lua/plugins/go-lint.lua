-- ========================================
-- GOLANGCI-LINT - CONTEXTO POR MODULO
-- ========================================
--
-- Mantem o linter original do nvim-lint.
-- Corrige apenas o diretorio de execucao
-- e o alvo conforme o arquivo Go aberto.
--
-- Nao altera o cwd global do Neovim.
-- Nao cria autocmds adicionais.
-- Nao modifica os linters de outras linguagens.

return {
  {
    "mfussenegger/nvim-lint",
    optional = true,

    opts = function(_, opts)
      opts.linters = opts.linters or {}

      opts.linters.golangcilint = function()
        local original = require("lint.linters.golangcilint")
        local linter = vim.deepcopy(original)

        local arquivo = vim.api.nvim_buf_get_name(0)

        if arquivo == "" then
          return linter
        end

        arquivo = vim.fs.normalize(arquivo)

        local diretorio = vim.fs.dirname(arquivo)

        local encontrados = vim.fs.find("go.mod", {
          path = diretorio,
          upward = true,
        })

        if #encontrados > 0 then
          -- Projeto com go.mod.
          -- Executar dentro do modulo atual.
          linter.cwd = vim.fs.dirname(encontrados[1])

          -- Analisar o pacote do arquivo aberto.
          linter.args[#linter.args] = diretorio
        else
          -- Arquivo Go independente.
          linter.cwd = diretorio
          linter.args[#linter.args] = arquivo
        end

        return linter
      end
    end,
  },
}
