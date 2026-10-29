local M = {}

-- Atalhos globais do Neovim.
local linhas_base = {
  "  CENTRAL DE ATALHOS - NEOVIM",
  "",
  "[EXECUCAO E DEBUG]",
  "  F5            Adicionar/remover breakpoint",
  "  F6            Executar arquivo atual",
  "  F7            Gerenciar projeto (conforme linguagem)",
  "  F8            Iniciar/continuar depuracao",
  "",
  "[NAVEGACAO]",
  "  Espaco + e    Abrir Snacks Explorer",
  "  Espaco + f f  Pesquisar arquivos",
  "  :e arquivo    Abrir arquivo",
  "  :bnext        Proximo buffer",
  "  :bprevious    Buffer anterior",
  "",
  "[CODIGO E LSP]",
  "  Espaco + r n  Renomear simbolo (inc-rename)",
  "  Espaco + c r  Renomear simbolo (LSP)",
  "  Espaco + c m  Abrir menu C#",
  "  :LspInfo      Verificar servidores LSP",
  "  :checkhealth  Diagnostico do Neovim",
  "",
  "[APARENCIA]",
  "  Espaco + u t  Seletor de temas",
  "  :Temas        Abrir seletor de temas",
  "  :colorscheme  Escolher tema pelo nome",
  "",
  "[GERENCIAMENTO]",
  "  :Lazy         Gerenciar plugins",
  "  :Lazy install Instalar plugins ausentes",
  "  :Lazy update  Atualizar plugins",
  "  :Mason        Gerenciar ferramentas",
  "",
  "[EDICAO E ARQUIVOS]",
  "  :w            Salvar arquivo",
  "  :wa           Salvar todos os arquivos",
  "  :q            Fechar janela",
  "  :wq           Salvar e sair",
  "  :q!           Sair sem salvar alteracoes",
  "  u             Desfazer",
  "  Ctrl + r      Refazer",
  "",
  "[AJUDA]",
  "  :Atalhos      Abrir esta central",
  "  j / k        Navegar pela lista",
  "  Ctrl + d/u    Rolar meia pagina",
  "  q ou Esc      Fechar esta janela",
}

-- Inserir secoes especificas de cada linguagem
-- antes da secao APARENCIA.
local function inserir_secao(linhas, adicionais)
  for indice, linha in ipairs(linhas) do
    if linha == "[APARENCIA]" then
      for i = #adicionais, 1, -1 do
        table.insert(linhas, indice, adicionais[i])
      end

      return
    end
  end
end

-- Montar a ajuda de acordo com o buffer aberto.
local function montar_linhas(buffer_origem)
  local linhas = vim.deepcopy(linhas_base)

  -- Rust.
  local rust = require("languages.rust.keymaps")

  if rust.eh_contexto_rust(buffer_origem) then
    inserir_secao(linhas, rust.linhas_ajuda())
  end

  -- Java.
  local java = require("languages.java.keymaps")

  if java.eh_contexto_java(buffer_origem) then
    inserir_secao(linhas, java.linhas_ajuda())
  end

  -- Kotlin.
  local kotlin = require("languages.kotlin.keymaps")

  if kotlin.eh_contexto_kotlin(buffer_origem) then
    inserir_secao(linhas, kotlin.linhas_ajuda())
  end

  -- C / C++.
  local cpp = require("languages.cpp.keymaps")

  if cpp.eh_contexto_cpp(buffer_origem) then
    inserir_secao(linhas, cpp.linhas_ajuda())
  end

  -- Go.
  local go = require("languages.go.keymaps")

  if go.eh_contexto_go(buffer_origem) then
    inserir_secao(linhas, go.linhas_ajuda())
  end

  -- Python.
  local python = require("languages.python.keymaps")

  if python.eh_contexto_python(buffer_origem) then
    inserir_secao(linhas, python.linhas_ajuda())
  end

  -- Ruby.
  local ruby = require("languages.ruby.keymaps")

  if ruby.eh_contexto_ruby(buffer_origem) then
    inserir_secao(linhas, ruby.linhas_ajuda())
  end

  -- PHP.
  local php = require("languages.php.keymaps")

  if php.eh_contexto_php(buffer_origem) then
    inserir_secao(linhas, php.linhas_ajuda())
  end

  -- Swift: exibir somente quando o buffer for Swift.
  local tipo_arquivo = vim.bo[buffer_origem].filetype

  if tipo_arquivo == "swift" then
    inserir_secao(linhas, {
      "[SWIFT]",
      "  Espaco + s f  Abrir SwiftMenu",
      "  :SwiftMenu    Criar, abrir e gerenciar projetos Swift",
      "  F5            Adicionar/remover breakpoint",
      "  F6            Compilar e executar projeto SwiftPM",
      "  F8            Iniciar/continuar depuracao Swift",
      "",
    })
  end

  -- TypeScript: exibir somente quando o buffer for TypeScript.
  if tipo_arquivo == "typescript" then
    inserir_secao(linhas, {
      "[TYPESCRIPT]",
      "  Espaco + t m  Abrir TypeScriptMenu",
      "  :TypeScriptMenu Criar e gerenciar projetos TypeScript",
      "  F5            Adicionar/remover breakpoint",
      "  F6            Executar arquivo .ts atual",
      "  F8            Depurar arquivo .ts atual",
      "",
    })
  end

  return linhas
end

function M.abrir()
  -- Guardar o buffer antes de abrir a janela.
  local buffer_origem = vim.api.nvim_get_current_buf()

  local linhas = montar_linhas(buffer_origem)

  local largura = math.max(1, math.min(76, vim.o.columns - 4))

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
    title = " Meus Atalhos ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = janela })

  vim.api.nvim_set_option_value("wrap", false, { win = janela })

  -- Destacar os titulos das secoes.
  for indice, linha in ipairs(linhas) do
    if linha:match("^%[.+%]$") then
      vim.api.nvim_buf_add_highlight(buffer, -1, "Title", indice - 1, 0, -1)
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
  vim.api.nvim_create_user_command("Atalhos", function()
    M.abrir()
  end, {
    desc = "Abrir central de atalhos do Neovim",
  })

  if vim.fn.maparg("<leader>uA", "n") == "" then
    vim.keymap.set("n", "<leader>uA", function()
      M.abrir()
    end, {
      desc = "Central de atalhos",
    })
  end
end

return M
