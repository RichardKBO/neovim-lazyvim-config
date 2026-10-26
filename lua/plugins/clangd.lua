-- Integracao do clangd com o LazyVim.
-- A ativacao do LSP continua em languages/cpp/lsp.lua.
-- Configurar marcadores no nvim-lspconfig para evitar
-- que o LazyVim substitua nossa deteccao de projetos CMake.

return {
  {
    "neovim/nvim-lspconfig",

    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local clangd = opts.servers.clangd

      if clangd == false then
        return
      end

      if type(clangd) ~= "table" then
        clangd = {}
      end

      local configuracao = vim.lsp.config.clangd or {}

      local marcadores = vim.deepcopy(
        clangd.root_markers
          or configuracao.root_markers
          or {
            "compile_commands.json",
            "compile_flags.txt",
            "Makefile",
            "meson.build",
            "build.ninja",
            ".git",
          }
      )

      -- Reconhecer projetos CMake pelo arquivo atual.
      if not vim.tbl_contains(marcadores, "CMakeLists.txt") then
        table.insert(marcadores, 1, "CMakeLists.txt")
      end

      clangd.root_markers = marcadores
      opts.servers.clangd = clangd
    end,
  },
}
