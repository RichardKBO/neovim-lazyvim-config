-- ========================================
-- RUBY
-- ========================================

-- Autocomplete Ruby ao digitar ponto.
vim.api.nvim_create_autocmd("InsertCharPre", {
  pattern = "*.rb",

  callback = function()
    if vim.v.char == "." then
      vim.schedule(function()
        require("blink.cmp").show()
      end)
    end
  end,
})

-- Registrar o comando :RubyMenu.
require("languages.ruby.menu").setup()

-- Atalhos contextuais dos buffers Ruby.
require("languages.ruby.keymaps").setup()

-- ========================================
-- C / C++
-- ========================================

require("languages.cpp.lsp").setup()
require("languages.cpp.diagnostics").setup()
require("languages.cpp.keymaps").setup()
require("languages.cpp.menu").setup()

-- ========================================
-- RUST
-- ========================================

require("languages.rust.lsp").setup()
require("languages.rust.picker").setup()
require("languages.rust.menu").setup()
require("languages.rust.keymaps").setup()

-- ========================================
-- JAVA
-- ========================================

require("languages.java.diagnostics").setup()
require("languages.java.menu").setup()
require("languages.java.keymaps").setup()

-- ========================================
-- GO
-- ========================================

-- LSP Gopls.
require("languages.go.lsp").setup()

-- Diagnosticos inline automaticos.
require("languages.go.diagnostics").setup()

-- F8 dinamico com Delve.
require("languages.go.keymaps").setup()

-- Registrar o comando :GoMenu.
require("languages.go.menu").setup()

-- ========================================
-- PYTHON
-- ========================================

-- Registrar o comando :PythonMenu.
require("languages.python.menu").setup()

-- Atalhos contextuais dos buffers Python.
require("languages.python.keymaps").setup()

-- ========================================
-- PHP
-- ========================================

-- Inicializacao global do Intelephense.
require("languages.php.lsp").setup()

-- ========================================
-- CMAKE
-- ========================================

require("languages.cmake.lsp").setup()

-- ========================================
-- APARENCIA E CENTRAL DE ATALHOS
-- ========================================

require("config.theme_selector").setup()
require("config.atalhos").setup()
