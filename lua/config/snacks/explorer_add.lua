-- ========================================
-- SNACKS - CRIACAO MODULAR DE ARQUIVOS
-- ========================================

local M = {}

function M.adicionar(picker)
  Snacks.input({
    prompt = 'Add a new file or directory (directories end with a "/")',
  }, function(valor)
    if not valor or vim.trim(valor) == "" then
      return
    end

    local caminho = vim.fs.normalize(picker:dir() .. "/" .. valor)
    local is_file = valor:sub(-1) ~= "/"
    local diretorio = is_file and vim.fs.dirname(caminho) or caminho

    if is_file and vim.uv.fs_lstat(caminho) then
      Snacks.notify.warn("File already exists:\n- `" .. caminho .. "`")
      return
    end

    if vim.fn.mkdir(diretorio, "p") == 0
      and vim.fn.isdirectory(diretorio) ~= 1 then
      Snacks.notify.error("Nao foi possivel criar o diretorio.")
      return
    end

    if is_file then
      local fd, erro = vim.uv.fs_open(caminho, "wx", 420)

      if not fd then
        Snacks.notify.error("Erro ao criar arquivo: " .. tostring(erro))
        return
      end

      vim.uv.fs_close(fd)

      local executou, sucesso, mensagem = pcall(
        require("config.file_creation").processar_arquivo_novo,
        caminho
      )

      if not executou then
        Snacks.notify.warn("Automacao falhou: " .. tostring(sucesso))
      elseif sucesso == false then
        Snacks.notify.warn(tostring(mensagem))
      end
    end

    local Tree = require("snacks.explorer.tree")
    Tree:open(diretorio)
    Tree:refresh(diretorio)

    require("snacks.explorer.actions").update(picker, {
      target = caminho,
    })
  end)
end

return M
