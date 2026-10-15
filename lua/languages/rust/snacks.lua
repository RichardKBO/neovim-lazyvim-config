-- Filtros do Snacks para projetos Rust.
-- Oculta arquivos gerados pelo Cargo.
-- Preserva arquivos de codigo e configuracao.

return {
  -- Diretorios de compilacao
  "target",
  "**/target",
  "**/target/**",
}
