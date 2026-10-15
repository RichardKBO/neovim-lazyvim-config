local M = {}

local cargo = require("languages.rust.cargo")

-- Abrir o Snacks Picker em um diretorio especifico.
local function abrir_picker(diretorio)
  if not diretorio or vim.fn.isdirectory(diretorio) ~= 1 then
    vim.notify("Rust: diretorio nao encontrado.", vim.log.levels.ERROR)
    return
  end

  Snacks.picker.files({
    cwd = diretorio,
  })
end

-- Pesquisar somente os arquivos da crate atual.
function M.arquivos_crate()
  local contexto, erro = cargo.contexto()

  if not contexto then
    vim.notify("Rust: " .. (erro or "Projeto nao identificado."), vim.log.levels.WARN)

    -- Manter uma busca disponivel para arquivos
    -- Rust ainda nao associados a uma crate.
    Snacks.picker.files()
    return
  end

  -- Em manifests virtuais [workspace], nao existe
  -- uma crate especifica para limitar a pesquisa.
  local diretorio = contexto.pacote and contexto.diretorio or contexto.workspace_root

  abrir_picker(diretorio)
end

-- Pesquisar todos os arquivos do workspace Cargo.
function M.arquivos_workspace()
  local contexto, erro = cargo.contexto()

  if not contexto then
    vim.notify("Rust: " .. (erro or "Workspace nao identificado."), vim.log.levels.WARN)
    return
  end

  abrir_picker(contexto.workspace_root)
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("RustPickerContextual", { clear = true })

  -- Comandos independentes de atalhos.
  vim.api.nvim_create_user_command("RustFiles", M.arquivos_crate, { desc = "Pesquisar arquivos da crate Rust" })

  vim.api.nvim_create_user_command(
    "RustWorkspaceFiles",
    M.arquivos_workspace,
    { desc = "Pesquisar arquivos do workspace Rust" }
  )

  -- Atalhos locais aos buffers Rust.
  -- Os atalhos globais do LazyVim permanecem intactos.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = { "rust", "toml" },

    callback = function(evento)
      local buffer = evento.buf
      local arquivo = vim.api.nvim_buf_get_name(buffer)

      -- Em TOML, ativar apenas para Cargo.toml.
      if vim.bo[buffer].filetype == "toml" and vim.fs.basename(arquivo) ~= "Cargo.toml" then
        return
      end

      vim.keymap.set("n", "<leader>ff", function()
        M.arquivos_crate()
      end, {
        buffer = buffer,
        silent = true,
        desc = "Rust: arquivos da crate",
      })

      vim.keymap.set("n", "<leader><space>", function()
        M.arquivos_crate()
      end, {
        buffer = buffer,
        silent = true,
        desc = "Rust: arquivos da crate",
      })
    end,
  })
end

return M
