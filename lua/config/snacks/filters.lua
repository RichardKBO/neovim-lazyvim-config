local M = {}

-- Filtros compartilhados pelo Picker e Explorer.
M.exclude = {}

-- C++: arquivos e pastas de compilacao.
vim.list_extend(M.exclude, require("languages.cpp.snacks"))

-- C#: binarios e arquivos temporarios do .NET.
vim.list_extend(M.exclude, require("languages.csharp.snacks"))

-- Python: ambientes virtuais e caches.
vim.list_extend(M.exclude, require("languages.python.snacks"))

-- Rust: arquivos gerados pelo Cargo.
vim.list_extend(M.exclude, require("languages.rust.snacks"))

return M
