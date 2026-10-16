-- ========================================
-- F6 - EXECUTAR ARQUIVO ATUAL
-- ========================================

vim.keymap.set("n", "<F6>", function()
  local arquivo = vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    vim.notify("Nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  local extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()

  -- C#
  if extensao == "cs" then
    require("languages.csharp.runner").executar(arquivo)

  -- Python
  elseif extensao == "py" then
    require("languages.python.runner").executar(arquivo)

  -- Java
  elseif extensao == "java" then
    require("languages.java.runner").executar(arquivo)

  -- Go
  elseif extensao == "go" then
    require("languages.go.runner").executar(arquivo)

  -- Rust
  elseif extensao == "rs" then
    require("languages.rust.runner").executar(arquivo)

  -- Kotlin
  elseif extensao == "kt" then
    require("languages.kotlin.runner").executar(arquivo)

  -- Ruby
  elseif extensao == "rb" then
    require("languages.ruby.runner").executar(arquivo)

  -- C / C++
  -- Detectar automaticamente a raiz CMake
  -- ou compilar um arquivo independente.
  elseif extensao == "c" or extensao == "cc" or extensao == "cpp" or extensao == "cxx" then
    require("languages.cpp.runner").executar(arquivo)

  -- PHP
  elseif extensao == "php" then
    require("languages.php.runner").executar(arquivo)

  -- SQL
  elseif extensao == "sql" then
    require("languages.sql.runner").executar(arquivo)
  else
    vim.notify("Extensao nao configurada: ." .. extensao, vim.log.levels.WARN)
  end
end, {
  desc = "Executar arquivo atual",
})

-- ========================================
-- F8 - DEBUGGER UNIVERSAL
-- ========================================

vim.keymap.set("n", "<F8>", function()
  local dap = require("dap")
  local filetype = vim.bo.filetype

  if dap.session() then
    dap.continue()
    return
  end

  -- C/C++ possui F8 especifico no buffer,
  -- configurado por languages.cpp.keymaps.
  -- Preservamos o comportamento global antigo
  -- como fallback.
  if filetype == "cpp" or filetype == "c" then
    require("cmake-tools").debug({})
    return
  end

  dap.continue()
end, {
  desc = "Iniciar ou continuar debugger",
})

-- ========================================
-- MENU INTERATIVO C#
-- ========================================

vim.keymap.set("n", "<leader>cm", function()
  require("languages.csharp.menu").abrir()
end, {
  desc = "Abrir menu C#",
})
