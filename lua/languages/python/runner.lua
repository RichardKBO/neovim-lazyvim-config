local M = {}

function M.executar(arquivo)
  if arquivo == nil or arquivo == "" then
    print("Nenhum arquivo Python aberto")
    return
  end

  vim.cmd(
    "split | terminal python3 "
      .. vim.fn.shellescape(arquivo)
  )
end

return M
