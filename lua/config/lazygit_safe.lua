local M = {}

-- Retorna o diretorio do arquivo atual ou o cwd.
local function diretorio_atual()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if arquivo ~= "" and vim.bo[buffer].buftype == "" then
    return vim.fs.dirname(arquivo)
  end

  return vim.uv.cwd()
end

-- Utiliza o proprio Git para localizar a raiz do repositorio.
-- Tambem reconhece worktrees, onde .git pode ser um arquivo.
local function localizar_raiz_git(diretorio)
  if not diretorio or vim.fn.isdirectory(diretorio) == 0 then
    return nil
  end

  local resultado = vim.system({
    "git",
    "-C",
    diretorio,
    "rev-parse",
    "--show-toplevel",
  }, { text = true }):wait()

  if resultado.code ~= 0 then
    return nil
  end

  local raiz = (resultado.stdout or ""):gsub("%s+$", "")

  if raiz == "" then
    return nil
  end

  return raiz
end

function M.abrir()
  local raiz = localizar_raiz_git(diretorio_atual())

  if not raiz then
    vim.notify(
      "Lazygit: nenhum repositorio Git encontrado para o projeto atual.",
      vim.log.levels.WARN
    )
    return
  end

  Snacks.lazygit({ cwd = raiz })
end

function M.setup()
  vim.keymap.set("n", "<leader>gg", M.abrir, {
    desc = "Lazygit (raiz Git segura)",
    silent = true,
  })
end

return M
