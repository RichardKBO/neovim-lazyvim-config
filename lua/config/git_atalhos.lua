local M = {}

-- Central independente de ajuda para Git e Lazygit.
-- Nao executa operacoes Git nem altera o repositorio.

local linhas = {
  "  CENTRAL DE ATALHOS - GIT / LAZYGIT",
  "",
  "[ABRIR NO NEOVIM]",
  "  Espaco + g g   Lazygit na raiz do repositorio",
  "  Espaco + g G   Lazygit no diretorio atual",
  "  :GitAtalhos    Abrir esta central",
  "",
  "[NAVEGACAO DO LAZYGIT]",
  "  1 a 5          Selecionar painel",
  "  Tab            Proximo painel",
  "  Shift + Tab    Painel anterior",
  "  j / k          Navegar para baixo / cima",
  "  Enter          Abrir detalhes",
  "  Esc            Voltar ou cancelar",
  "  ?              Ajuda contextual",
  "  q              Sair do Lazygit",
  "",
  "[ARQUIVOS - PAINEL 2]",
  "  Espaco         Adicionar/remover arquivo do staging",
  "  Enter          Examinar diff e selecionar trechos",
  "  a              Adicionar/remover todos os arquivos",
  "  e              Editar arquivo",
  "  c              Criar commit com alteracoes preparadas",
  "  s              Guardar alteracoes em stash",
  "  S              Opcoes de stash",
  "  d              Descartar alteracoes [CUIDADO]",
  "",
  "[DIFF - SELECAO DE TRECHOS]",
  "  Espaco         Preparar/remover linha selecionada",
  "  v              Selecionar intervalo de linhas",
  "  a              Preparar/remover trecho inteiro",
  "",
  "[BRANCHES - PAINEL 3]",
  "  n              Criar branch",
  "  Espaco         Trocar para branch selecionada",
  "  d              Excluir branch [CUIDADO]",
  "  M              Merge [CUIDADO]",
  "  r              Rebase [CUIDADO]",
  "",
  "[COMMITS - PAINEL 4]",
  "  Enter          Examinar arquivos do commit",
  "  r              Alterar mensagem [CUIDADO]",
  "  s              Squash [CUIDADO]",
  "  i              Rebase interativo [CUIDADO]",
  "",
  "[STASH - PAINEL 5]",
  "  Espaco         Aplicar stash sem remove-lo",
  "  g              Aplicar e remover stash [CUIDADO]",
  "  d              Excluir stash [CUIDADO]",
  "  n              Criar branch a partir do stash",
  "",
  "[GIT REMOTO E UTILIDADES]",
  "  p              Pull",
  "  P              Push",
  "  /              Filtrar itens do painel",
  "  @              Historico de comandos Git",
  "",
  "[SEGURANCA]",
  "  Confira o staging antes de criar commits.",
  "  Nao inclua personalizacoes locais sem querer.",
  "  Reset, descarte, rebase e stash drop exigem cuidado.",
  "  Pratique operacoes de risco em repositorios de teste.",
  "",
  "[AJUDA DESTA CENTRAL]",
  "  j / k          Navegar pelas linhas",
  "  Ctrl + d/u     Rolar meia pagina",
  "  q ou Esc       Fechar a janela",
}

function M.abrir()
  local largura = math.max(1, math.min(82, vim.o.columns - 4))
  local altura = math.max(1, math.min(#linhas, vim.o.lines - 6))

  local buffer = vim.api.nvim_create_buf(false, true)

  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, linhas)
  vim.bo[buffer].modifiable = false

  local janela = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = largura,
    height = altura,
    row = math.max(0, math.floor((vim.o.lines - altura - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - largura) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Git - Atalhos ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = janela })
  vim.api.nvim_set_option_value("wrap", false, { win = janela })

  local namespace = vim.api.nvim_create_namespace("GitAtalhos")

  for indice, linha in ipairs(linhas) do
    if linha:match("^%[.+%]$") then
      vim.api.nvim_buf_add_highlight(
        buffer,
        namespace,
        "Title",
        indice - 1,
        0,
        -1
      )
    elseif linha:find("%[CUIDADO%]") then
      local inicio = linha:find("%[CUIDADO%]")

      vim.api.nvim_buf_add_highlight(
        buffer,
        namespace,
        "WarningMsg",
        indice - 1,
        inicio - 1,
        -1
      )
    end
  end

  local function fechar()
    if vim.api.nvim_win_is_valid(janela) then
      vim.api.nvim_win_close(janela, true)
    end
  end

  vim.keymap.set("n", "q", fechar, {
    buffer = buffer,
    silent = true,
  })

  vim.keymap.set("n", "<Esc>", fechar, {
    buffer = buffer,
    silent = true,
  })
end

function M.setup()
  if vim.fn.exists(":GitAtalhos") == 2 then
    return
  end

  vim.api.nvim_create_user_command("GitAtalhos", function()
    M.abrir()
  end, {
    desc = "Abrir central de atalhos do Git e Lazygit",
  })
end

return M
