-- ========================================
-- MINI.ICONS - ICONES DAS LINGUAGENS
-- Personalizacao pessoal - Opcao A
-- ========================================

local icones = {
  cpp = { glyph = "", hl = "MiniIconsBlue" },
  cs = { glyph = "󰌛", hl = "MiniIconsPurple" },
  rust = { glyph = "", hl = "MiniIconsOrange" },
  python = { glyph = "", hl = "MiniIconsYellow" },
  java = { glyph = "", hl = "MiniIconsRed" },
  swift = { glyph = "", hl = "MiniIconsOrange" },
  ruby = { glyph = "", hl = "MiniIconsRed" },
  go = { glyph = "", hl = "MiniIconsCyan" },
  php = { glyph = "", hl = "MiniIconsPurple" },
  lua = { glyph = "", hl = "MiniIconsAzure" },
  typescript = { glyph = "", hl = "MiniIconsBlue" },
  html = { glyph = "", hl = "MiniIconsOrange" },
  css = { glyph = "", hl = "MiniIconsBlue" },
  sql = { glyph = "", hl = "MiniIconsYellow" },
}

return {
  {
    "nvim-mini/mini.icons",

    opts = {
      style = "glyph",

      -- Icones associados aos tipos de arquivo.
      filetype = {
        cpp = icones.cpp,
        cs = icones.cs,
        rust = icones.rust,
        python = icones.python,
        java = icones.java,
        swift = icones.swift,
        ruby = icones.ruby,
        go = icones.go,
        php = icones.php,
        lua = icones.lua,
        typescript = icones.typescript,
        typescriptreact = icones.typescript,
        html = icones.html,
        css = icones.css,
        sql = icones.sql,
      },

      -- Icones associados as extensoes.
      extension = {
        -- C++
        cpp = icones.cpp,
        cc = icones.cpp,
        cxx = icones.cpp,
        hpp = icones.cpp,
        hh = icones.cpp,
        hxx = icones.cpp,

        -- C#
        cs = icones.cs,
        csx = icones.cs,

        -- Rust
        rs = icones.rust,

        -- Python
        py = icones.python,
        pyw = icones.python,

        -- Java
        java = icones.java,

        -- Swift
        swift = icones.swift,

        -- Ruby
        rb = icones.ruby,

        -- Go
        go = icones.go,

        -- PHP
        php = icones.php,

        -- Lua
        lua = icones.lua,

        -- TypeScript
        ts = icones.typescript,
        tsx = icones.typescript,

        -- HTML
        html = icones.html,
        htm = icones.html,

        -- CSS
        css = icones.css,

        -- SQL
        sql = icones.sql,
      },
    },
  },
}
