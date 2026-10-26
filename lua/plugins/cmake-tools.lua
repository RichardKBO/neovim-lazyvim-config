-- O extra CMake do LazyVim permanece habilitado.
-- Desativar apenas o cmake-tools.nvim redundante.
-- F6, F7 e F8 utilizam nossos modulos C++.

return {
  {
    "Civitasv/cmake-tools.nvim",
    enabled = false,
  },
}
