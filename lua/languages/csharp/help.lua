-- ========================================
-- C# - GUIA DE PROJETOS E SOLUCOES
-- ========================================
-- Interface de ajuda somente leitura.
-- Nao cria projetos, nao executa dotnet
-- e nao modifica configuracoes existentes.
-- ========================================

local M = {}

local linhas = {
  "AJUDA - C# / .NET NO NEOVIM",
  "",
  "j/k: navegar | Ctrl+d/u: rolar",
  "gg/G: inicio/fim | /: buscar",
  "q ou Esc: fechar a janela.",
  "",
  "[1. PROJETO .CSPROJ]",
  "O .csproj define um projeto .NET.",
  "Contem framework, referencias e propriedades de compilacao.",
  "",
  "Console: aplicativo executavel.",
  "Classlib: biblioteca de classes reutilizaveis.",
  "",
  "[2. CRIAR PROJETO C#]",
  "Abra o menu C# e escolha Criar projeto.",
  "",
  "Templates disponiveis:",
  "- Console com top-level statements.",
  "- Console com Main tradicional.",
  "- Biblioteca de classes (classlib).",
  "",
  "Informe o nome e o diretorio pai.",
  "O menu sugere um diretorio inicial.",
  "A pasta pai deve existir e o destino deve ser novo.",
  "",
  "[3. SOLUCOES .SLN E .SLNX]",
  "Uma solucao organiza um ou mais projetos .NET.",
  "",
  ".sln: formato classico.",
  ".slnx: formato moderno em XML.",
  "",
  "Uma solucao pode conter aplicativos,",
  "bibliotecas e projetos de testes.",
  "",
  "[4. SELECAO AUTOMATICA DE SOLUCOES]",
  "O menu procura solucoes proximas.",
  "",
  "Associada:",
  "A solucao contem o projeto atual.",
  "",
  "Outra:",
  "A solucao foi consultada, mas nao contem",
  "o projeto atual.",
  "",
  "Nao verificada:",
  "A associacao ainda nao foi comprovada.",
  "",
  "Tambem existe a opcao de caminho manual.",
  "",
  "[5. GERENCIAR PROJETOS DA SOLUCAO]",
  "Adicionar: registra um .csproj na solucao.",
  "Listar: mostra os projetos registrados.",
  "Remover: retira o projeto da solucao.",
  "",
  "Remover da solucao nao apaga os arquivos",
  "do projeto no disco.",
  "",
  "[6. CRIAR CLASSES C#]",
  "Escolha Criar classe C# no menu.",
  "",
  "Informe uma pasta existente e o nome.",
  "O namespace sera identificado pelo projeto",
  "e pelo caminho relativo da classe.",
  "",
  "Exemplo:",
  "Models/Produto.cs",
  "Namespace: BibliotecaCore.Models",
  "",
  "Arquivos existentes nao sao sobrescritos.",
  "",
  "[7. BIBLIOTECAS E PROJECTREFERENCE]",
  "Uma biblioteca fornece classes e metodos",
  "que podem ser utilizados por outro projeto.",
  "",
  "Exemplo:",
  "BibliotecaCore -> fornece Produto.",
  "AppConsole -> utiliza Produto.",
  "",
  "O AppConsole precisa referenciar BibliotecaCore.",
  "",
  "Comando .NET:",
  "dotnet add AppConsole/AppConsole.csproj reference",
  "  BibliotecaCore/BibliotecaCore.csproj",
  "",
  "Exemplo de referencia no .csproj consumidor:",
  "",
  '<ProjectReference Include="../BibliotecaCore/BibliotecaCore.csproj" />',
  "",
  "O caminho depende da estrutura real.",
  "",
  "IMPORTANTE:",
  "Adicionar um projeto a uma solucao",
  "NAO cria automaticamente ProjectReference.",
  "",
  "No menu C#, escolha Adicionar ProjectReference.",
  "O projeto consumidor vem do arquivo atual.",
  "A biblioteca e escolhida visualmente.",
  "Autorreferencias e duplicatas sao bloqueadas.",
  "",
  "[8. EXECUTAR COM F6]",
  "Abra e salve um arquivo .cs.",
  "Pressione F6 para executar.",
  "",
  "O runner procura o projeto correspondente.",
  "Quando necessario, permite selecionar",
  "o projeto ou executor.",
  "",
  "Program.cs utiliza a execucao convencional.",
  "Outras classes podem usar o runner global.",
  "",
  "Bibliotecas classlib nao sao executaveis.",
  "",
  "[9. COMPILAR PROJETOS]",
  "No menu C#, escolha Compilar projeto atual.",
  "",
  "O sistema identifica o .csproj ancestral.",
  "Tambem aceita .csproj, .sln e .slnx abertos.",
  "",
  "Compilar valida codigo e referencias.",
  "Executar inicia o aplicativo.",
  "",
  "[10. DEBUG COM F8]",
  "F8 inicia ou continua a depuracao.",
  "",
  "O debugger C# utiliza NetCoreDbg.",
  "O projeto executavel e compilado em Debug.",
  "",
  "Permite breakpoints e inspecao de variaveis.",
  "",
  "Uma biblioteca nao inicia diretamente",
  "uma sessao de execucao independente.",
  "",
  "[11. ROSLYN - LSP]",
  "Roslyn fornece recursos de linguagem:",
  "",
  "- Diagnosticos.",
  "- Navegacao pelo codigo.",
  "- Autocomplete.",
  "- Informacoes sobre simbolos.",
  "",
  "A raiz do projeto influencia o contexto.",
  "",
  "[12. MENU E ATALHOS]",
  "Menu C#: <leader>cm",
  "Executar: F6",
  "Depurar: F8",
  "",
  "Os recursos dependem do tipo de projeto",
  "e das configuracoes existentes.",
  "",
  "[LEMBRETES IMPORTANTES]",
  "Os nomes apresentados sao exemplos.",
  "Confira os projetos reais antes de operar.",
  "",
  "Esta ajuda nao altera nenhum arquivo.",
  "",
  "q ou Esc: fechar.",
}

-- ========================================
-- ABRIR JANELA DE AJUDA
-- ========================================

function M.abrir()
  local largura = math.max(1, math.min(88, vim.o.columns - 4))

  local altura = math.max(1, math.min(#linhas, vim.o.lines - 6))

  local buffer = vim.api.nvim_create_buf(false, true)

  -- Buffer temporario.
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false

  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, linhas)

  -- Proteger o conteudo.
  vim.bo[buffer].modifiable = false
  vim.bo[buffer].readonly = true

  -- Criar janela flutuante centralizada.
  local janela = vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    width = largura,
    height = altura,
    row = math.max(0, math.floor((vim.o.lines - altura - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - largura - 2) / 2)),
    style = "minimal",
    border = "rounded",
    title = " Ajuda - C# / .NET ",
    title_pos = "center",
  })

  vim.wo[janela].cursorline = true
  vim.wo[janela].wrap = true
  vim.wo[janela].linebreak = true

  -- Destacar titulos e secoes.
  for indice, linha in ipairs(linhas) do
    if indice == 1 or linha:match("^%[.+%]$") then
      vim.api.nvim_buf_add_highlight(buffer, -1, "Title", indice - 1, 0, -1)
    end
  end

  -- Fechar somente a janela de ajuda.
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
      desc = "Fechar ajuda C#",
    })
  end
end

return M
