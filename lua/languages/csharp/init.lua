-- ========================================
-- C# - INICIALIZACAO MODULAR
-- ========================================
-- Roslyn LSP gerenciado pelo LazyVim.
-- Diagnosticos inline configurados
-- exclusivamente para C#.

local M = {}

function M.setup()
  -- ========================================
  -- DIAGNOSTICOS INLINE
  -- ========================================

  -- Registrar os eventos antes de habilitar
  -- o LSP, para acompanhar novas conexoes.
  require("languages.csharp.diagnostics").setup()

  -- ========================================
  -- CONFIGURACAO DO ROSLYN
  -- ========================================

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

  -- ========================================
  -- HABILITAR ROSLYN
  -- ========================================

  vim.lsp.enable("roslyn")
end

return M
