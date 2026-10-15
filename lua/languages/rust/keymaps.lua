local M = {}

-- Verifica se o buffer pertence ao contexto Rust.
function M.eh_contexto_rust(buffer)
  buffer = buffer or vim.api.nvim_get_current_buf()

  local tipo = vim.bo[buffer].filetype

  if tipo == "rust" then
    return true
  end

  if tipo == "toml" then
    local arquivo = vim.api.nvim_buf_get_name(buffer)

    return vim.fs.basename(arquivo) == "Cargo.toml"
  end

  return false
end

-- Descricoes utilizadas pela central :Atalhos.
-- A interface global nao precisa conhecer os atalhos
-- internos da linguagem.
function M.linhas_ajuda()
  return {
    "[RUST / CARGO]",
    "  Espaco + r m  Abrir menu Rust",
    "  Espaco + f f  Pesquisar arquivos da crate",
    "  :RustWorkspaceFiles  Pesquisar workspace inteiro",
    "",
  }
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("RustMenuKeymaps", { clear = true })

  -- Atalho local: somente buffers Rust e Cargo.toml.
  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = { "rust", "toml" },

    callback = function(evento)
      local buffer = evento.buf

      if not M.eh_contexto_rust(buffer) then
        return
      end

      vim.keymap.set("n", "<leader>rm", function()
        require("languages.rust.menu").abrir()
      end, {
        buffer = buffer,
        silent = true,
        desc = "Rust: gerenciar projeto e Cargo",
      })
    end,
  })
end

return M
