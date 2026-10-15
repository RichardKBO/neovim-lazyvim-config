-- Filtros do Snacks para projetos Python
-- Oculta arquivos gerados automaticamente

return {
  -- Cache do interpretador
  "__pycache__",
  "**/__pycache__",
  "**/__pycache__/**",
  "**/*.pyc",
  "**/*.pyo",

  -- Ambientes virtuais
  ".venv",
  "venv",
  "**/.venv",
  "**/venv",
  "**/.venv/**",
  "**/venv/**",

  -- Cache das ferramentas Python
  ".pytest_cache",
  ".mypy_cache",
  ".ruff_cache",
  "**/.pytest_cache/**",
  "**/.mypy_cache/**",
  "**/.ruff_cache/**",
}
