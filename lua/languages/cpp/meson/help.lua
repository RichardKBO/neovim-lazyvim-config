local M = {}

-- Conteudo didatico estatico: nao consulta projetos nem carrega o aplicador.
-- Janela segue o padrao da central config.atalhos, sem alterar aquela interface.
local linhas = {
  "AJUDA — DEPENDÊNCIAS MESON",
  "",
  "j/k: navegar | Ctrl+d/u: rolar | gg/G: início/fim | /: buscar",
  "q ou Esc: fechar e voltar ao buffer anterior.",
  "",
  "[COMO USAR OS EXEMPLOS]",
  "Os nomes abaixo são exemplos reais do laboratório p395, não valores obrigatórios.",
  "Em seus projetos, confira os nomes nos meson.build; maiúsculas e minúsculas importam.",
  "Nos exemplos, <laboratório> é a pasta que contém SistemaVendas e BibliotecaProdutos.",
  "Substitua <laboratório> pelo caminho real no seu computador; não digite os sinais < >.",
  "",
  "[1. PROJETO CONSUMIDOR]",
  "É o projeto que usará a biblioteca. Informe o diretório raiz que contém seu meson.build.",
  "Exemplo: <laboratório>/SistemaVendas",
  "",
  "[2. BIBLIOTECA MESON INDEPENDENTE]",
  "É outro projeto Meson, com seu próprio meson.build. Informe a raiz da biblioteca.",
  "Exemplo: <laboratório>/BibliotecaProdutos",
  "Consumidor e biblioteca devem ter raízes distintas, sem uma estar dentro da outra.",
  "",
  "[3. DIRETÓRIO DE BUILD MESON]",
  "É a pasta de build já configurada do consumidor, com os dados de introspecção Meson.",
  "Exemplo: <laboratório>/SistemaVendas/build",
  "A prévia lê esse build; não configura nem compila o projeto automaticamente.",
  "",
  "[4. TARGET CONSUMIDOR]",
  "Selecione na lista o executável principal que receberá a dependência.",
  "O nome vem de executable(); o ID identifica o alvo no build selecionado.",
  "Exemplo: SistemaVendas [SistemaVendas@exe]",
  "O alvo deve estar declarado no meson.build da raiz, fora de um subprojeto.",
  "",
  "[5. TARGET ESTÁTICO DA BIBLIOTECA]",
  "Informe o nome entre aspas passado a static_library(), não o nome de project().",
  "Exemplo: biblioteca_produtos",
  "BibliotecaProdutos é o nome do projeto/diretório e o alias deste exemplo.",
  "biblioteca_produtos é o target estático. Os dois nomes têm funções diferentes.",
  "lib_produtos, abaixo, é apenas a variável que recebe o objeto da biblioteca:",
  "",
  "  inc_produtos = include_directories('include')",
  "  lib_produtos = static_library(",
  "    'biblioteca_produtos',",
  "    'src/Produto.cpp',",
  "    include_directories: inc_produtos",
  "  )",
  "",
  "[6. EXPORTAÇÃO DECLARE_DEPENDENCY]",
  "Informe a variável que recebe declare_dependency() no meson.build da biblioteca.",
  "Esse objeto reúne a biblioteca e seus requisitos de uso, como os includes.",
  "Exemplo: biblioteca_produtos_dep",
  "",
  "  biblioteca_produtos_dep = declare_dependency(",
  "    link_with: lib_produtos,",
  "    include_directories: inc_produtos",
  "  )",
  "",
  "[7. ALIAS DO SUBPROJETO]",
  "É o nome usado em subproject() e no caminho subprojects/<alias> do consumidor.",
  "Exemplo: BibliotecaProdutos",
  "Na integração deste exemplo, o link relativo aponta para a biblioteca independente:",
  "  SistemaVendas/subprojects/BibliotecaProdutos -> ../../BibliotecaProdutos",
  "O alias não precisa ser o nome do target estático.",
  "",
  "[8. VARIÁVEL LOCAL DO SUBPROJETO]",
  "É a variável do consumidor que recebe o resultado de subproject().",
  "Exemplo: biblioteca",
  "",
  "  biblioteca = subproject('BibliotecaProdutos')",
  "",
  "[9. VARIÁVEL LOCAL DA DEPENDÊNCIA]",
  "É a variável do consumidor que recebe a exportação por get_variable().",
  "Ela será usada em dependencies: do executável. Deve diferir da variável do subprojeto.",
  "Exemplo: produtos_dep",
  "",
  "  produtos_dep = biblioteca.get_variable('biblioteca_produtos_dep')",
  "  executable(",
  "    'SistemaVendas',",
  "    'src/main.cpp',",
  "    dependencies: produtos_dep",
  "  )",
  "",
  "O trecho acima é resumido; o consumidor real também declara seus includes.",
  "Se a integração já existe, informe as variáveis que o manifesto realmente usa.",
  "",
  "[10. VISUALIZAR, ADICIONAR E INTEGRAÇÃO EXISTENTE]",
  "Visualizar integração: apresenta caminhos, target, link e diff, sem escrever.",
  "Adicionar biblioteca: apresenta a revisão da operação e, quando há uma proposta,",
  "os objetos afetados, o backup previsto e os riscos. Não é uma confirmação automática.",
  "No estágio atual, a aplicação real do perfil selecionado está bloqueada na UI e na API.",
  "Integração já existente: estado sem_alteracao, link com ação manter e diff vazio.",
  "Nesse caso, nenhuma aplicação é necessária; não há nova dependência a criar.",
  "Uma recusa de formato exige conferir os campos e o formato suportado pelo reconhecedor.",
  "Um projeto compilar não garante que todo formato Meson seja reconhecido pela prévia.",
  "",
  "[LEMBRETE DO EXEMPLO]",
  "Projeto/diretório e alias: BibliotecaProdutos",
  "Target estático: biblioteca_produtos | Exportação: biblioteca_produtos_dep",
  "Variáveis do consumidor: biblioteca e produtos_dep",
  "Esta ajuda apenas exibe texto: não executa Meson nem altera projetos.",
  "",
  "q ou Esc: fechar | :CPPMesonAjuda: abrir novamente, mesmo sem projeto aberto.",
}

function M.abrir()
  local largura = math.max(1, math.min(88, vim.o.columns - 4))
  local altura = math.max(1, math.min(#linhas, vim.o.lines - 6))
  local buffer = vim.api.nvim_create_buf(false, true)

  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, linhas)
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true

  local janela = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = largura,
    height = altura,
    row = math.max(0, math.floor((vim.o.lines - altura - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - largura - 2) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Ajuda — Dependências Meson ",
    title_pos = "center",
  })

  vim.wo[janela].cursorline = true
  vim.wo[janela].wrap = true
  vim.wo[janela].linebreak = true

  for indice, linha in ipairs(linhas) do
    if linha:match("^%[.+%]$") or indice == 1 then
      vim.api.nvim_buf_add_highlight(buffer, -1, "Title", indice - 1, 0, -1)
    end
  end

  local function fechar()
    if vim.api.nvim_win_is_valid(janela) then
      vim.api.nvim_win_close(janela, true)
    end
  end

  for _, tecla in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", tecla, fechar, {
      buffer = buffer,
      silent = true,
      nowait = true,
      desc = "Fechar ajuda de dependências Meson",
    })
  end
end

return M
