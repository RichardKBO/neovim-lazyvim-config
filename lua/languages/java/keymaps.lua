local M = {}

-- Identifica arquivos Java e o manifesto Maven.
function M.eh_contexto_java(buffer)
  buffer = buffer or vim.api.nvim_get_current_buf()

  local tipo = vim.bo[buffer].filetype

  if tipo == "java" then
    return true
  end

  local arquivo = vim.api.nvim_buf_get_name(buffer)

  return arquivo ~= "" and vim.fs.basename(arquivo) == "pom.xml"
end

-- Informacoes exibidas na central :Atalhos.
function M.linhas_ajuda()
  return {
    "[JAVA / MAVEN]",
    "  Espaco + j m  Abrir menu Java",
    "",
  }
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("JavaMenuKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = { "java", "xml" },

    callback = function(evento)
      local buffer = evento.buf

      if not M.eh_contexto_java(buffer) then
        return
      end

      vim.keymap.set("n", "<leader>jm", function()
        require("languages.java.menu").abrir()
      end, {
        buffer = buffer,
        silent = true,
        desc = "Java: gerenciar projeto",
      })
    end,
  })
end

return M
