-- Debugger Rust modularizado
-- Utiliza nvim-dap + CodeLLDB + Cargo

local M = {}

-- Encontrar o Cargo.toml correspondente ao arquivo atual.
local function localizar_cargo()
  local arquivo = vim.fn.expand("%:p")

  if arquivo == "" then
    error("Nenhum arquivo Rust aberto.")
  end

  if vim.bo.modified then
    error("Salve o arquivo Rust com :w antes de depurar.")
  end

  local cargo_toml = vim.fs.find("Cargo.toml", {
    upward = true,
    path = vim.fs.dirname(arquivo),
  })[1]

  if not cargo_toml then
    error("Cargo.toml nao encontrado.")
  end

  return cargo_toml
end

-- Obter informacoes reais do projeto Cargo.
local function obter_metadata(cargo_toml)
  local resultado = vim.fn.system({
    "cargo",
    "metadata",
    "--no-deps",
    "--format-version",
    "1",
    "--manifest-path",
    cargo_toml,
  })

  if vim.v.shell_error ~= 0 then
    error("Nao foi possivel obter os dados do Cargo:\n" .. resultado)
  end

  return vim.json.decode(resultado)
end

-- Encontrar o package correspondente ao manifesto.
local function localizar_package(metadata, cargo_toml)
  for _, package in ipairs(metadata.packages or {}) do
    if vim.fs.normalize(package.manifest_path) == vim.fs.normalize(cargo_toml) then
      return package
    end
  end

  error("Package correspondente ao Cargo.toml nao encontrado.")
end

-- Encontrar um executavel binario do package.
local function localizar_binario(package)
  for _, target in ipairs(package.targets or {}) do
    for _, kind in ipairs(target.kind or {}) do
      if kind == "bin" then
        return target.name
      end
    end
  end

  error("Nenhum executavel binario encontrado no projeto.")
end

function M.setup()
  local dap = require("dap")

  -- O adaptador codelldb permanece compartilhado
  -- em plugins/dap.lua ate modularizarmos o C++.

  dap.configurations.rust = {
    {
      name = "Rust: depurar projeto atual",

      type = "codelldb",
      request = "launch",

      -- Compilar e localizar o executavel correto.
      program = function()
        local cargo_toml = localizar_cargo()
        local metadata = obter_metadata(cargo_toml)

        local package = localizar_package(metadata, cargo_toml)
        local binario = localizar_binario(package)

        local resultado = vim.fn.system({
          "cargo",
          "build",
          "--manifest-path",
          cargo_toml,
          "--bin",
          binario,
        })

        if vim.v.shell_error ~= 0 then
          error("cargo build falhou:\n" .. resultado)
        end

        return metadata.target_directory .. "/debug/" .. binario
      end,

      -- Executar no diretorio do projeto correto.
      cwd = function()
        local cargo_toml = localizar_cargo()
        return vim.fs.dirname(cargo_toml)
      end,

      stopOnEntry = false,

      sourceLanguages = {
        "rust",
      },
    },
  }
end

return M
