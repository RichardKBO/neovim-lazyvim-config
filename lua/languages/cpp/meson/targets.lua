local M = {}

-- ========================================
-- MESON - INTROSPECCAO DE TARGETS
-- ========================================
-- Consulta os targets de um build Meson.
-- Nao modifica arquivos ou compila projetos.
-- A execucao e assincrona para nao bloquear
-- a interface do Neovim.
-- ========================================

function M.listar(diretorio_build, callback)
  if type(callback) ~= "function" then
    return false, "Callback invalido."
  end

  if type(diretorio_build) ~= "string" or diretorio_build == "" then
    return false, "Diretorio de build invalido."
  end

  local caminho = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(diretorio_build), ":p"))

  local info = vim.uv.fs_stat(caminho)

  if not info or info.type ~= "directory" then
    return false, "Diretorio de build inexistente."
  end

  if vim.fn.executable("meson") ~= 1 then
    return false, "Meson nao encontrado no PATH."
  end

  local ok, erro = pcall(vim.system, {
    "meson",
    "introspect",
    "--targets",
    caminho,
  }, { text = true }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        local mensagem = vim.trim(resultado.stderr or "")

        if mensagem == "" then
          mensagem = "Meson introspect falhou: " .. tostring(resultado.code)
        end

        callback(nil, mensagem)
        return
      end

      local decodificou, alvos = pcall(vim.json.decode, resultado.stdout or "")

      if not decodificou or type(alvos) ~= "table" then
        callback(nil, "Resposta JSON invalida do Meson.")
        return
      end

      callback(alvos, nil)
    end)
  end)

  if not ok then
    return false, tostring(erro)
  end

  return true
end

return M
