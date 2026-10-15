-- Configuração modular do Roslyn LSP para C#
-- O plugin seblyng/roslyn.nvim continua gerenciado pelo LazyVim.

local M = {}

function M.setup()
  vim.lsp.config("roslyn", {
    cmd = {
      vim.fn.expand("~/.dotnet/tools/roslyn-language-server"),
      "--stdio",
    },

    filetypes = {
      "cs",
    },

    root_markers = {
      "*.sln",
      "*.slnx",
      "*.csproj",
      "global.json",
    },
  })

  -- Habilitar o servidor Roslyn.
  vim.lsp.enable("roslyn")
end

return M
