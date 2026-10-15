local M = {}

-- ========================================
-- UTILITARIOS
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function nome_valido(nome)
  return type(nome) == "string" and nome:match("^[%a_][%w_%-]*$") ~= nil
end

local function escrever_novo(arquivo, linhas)
  local descritor, erro = vim.uv.fs_open(arquivo, "wx", 420)

  if not descritor then
    return false, erro
  end

  local conteudo = table.concat(linhas, "\n") .. "\n"

  local escritos, erro_escrita = vim.uv.fs_write(descritor, conteudo, 0)

  local fechado, erro_fechamento = vim.uv.fs_close(descritor)

  if escritos ~= #conteudo or not fechado then
    vim.uv.fs_unlink(arquivo)

    return false, erro_escrita or erro_fechamento or "Escrita incompleta"
  end

  return true
end

-- ========================================
-- ARQUIVOS DO PROJETO
-- ========================================

local function gerar_main()
  return {
    "package main",
    "",
    'import "fmt"',
    "",
    "func main() {",
    '    fmt.Println("Projeto Go funcionando!")',
    "}",
  }
end

local function gerar_gitignore()
  return {
    "# Executaveis e artefatos",
    "bin/",
    "dist/",
    "*.exe",
    "*.exe~",
    "*.test",
    "*.out",
  }
end

-- ========================================
-- CRIACAO DO PROJETO
-- ========================================

function M.gerar(dados)
  if not nome_valido(dados.nome) then
    avisar("Go: nome de projeto invalido.", vim.log.levels.ERROR)
    return
  end

  local modulo = vim.trim(dados.modulo or "")

  if modulo == "" or modulo:find("%s") then
    avisar("Go: informe um caminho de modulo valido.", vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable("go") ~= 1 then
    avisar("Go: comando go nao encontrado.", vim.log.levels.ERROR)
    return
  end

  local destino = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dados.destino), ":p"))

  if vim.fn.isdirectory(destino) ~= 1 then
    avisar("Go: diretorio de destino nao existe.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.joinpath(destino, dados.nome)

  -- Nunca sobrescrever projetos existentes.
  if vim.uv.fs_lstat(raiz) then
    avisar("Go: projeto ja existe: " .. raiz, vim.log.levels.ERROR)
    return
  end

  local criado, erro = vim.uv.fs_mkdir(raiz, 493)

  if not criado then
    avisar("Go: erro ao criar diretorio: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  avisar("Go: inicializando modulo " .. modulo)

  -- Criar go.mod utilizando a propria
  -- instalacao do Go.
  vim.system({
    "go",
    "mod",
    "init",
    modulo,
  }, {
    cwd = raiz,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        avisar(
          "Go: falha ao criar go.mod:\n" .. vim.trim(resultado.stderr or "") .. "\nDiretorio criado: " .. raiz,
          vim.log.levels.ERROR
        )
        return
      end

      local main = vim.fs.joinpath(raiz, "main.go")

      local gitignore = vim.fs.joinpath(raiz, ".gitignore")

      local ok_main, erro_main = escrever_novo(main, gerar_main())

      if not ok_main then
        avisar("Go: falha ao criar main.go: " .. tostring(erro_main), vim.log.levels.ERROR)
        return
      end

      local ok_git, erro_git = escrever_novo(gitignore, gerar_gitignore())

      if not ok_git then
        avisar("Go: falha ao criar .gitignore: " .. tostring(erro_git), vim.log.levels.ERROR)
        return
      end

      avisar("Go: projeto criado com sucesso!\n" .. raiz)

      -- Abrir o arquivo principal do
      -- novo projeto automaticamente.
      local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(main))

      if not abriu then
        avisar("Projeto criado, mas main.go nao abriu: " .. tostring(erro_abrir), vim.log.levels.WARN)
      end
    end)
  end)
end

-- ========================================
-- INTERFACE INTERATIVA
-- ========================================

function M.criar()
  local dados = {}

  vim.ui.input({
    prompt = "Nome do projeto Go: ",
  }, function(nome)
    if nome == nil then
      return
    end

    dados.nome = vim.trim(nome)

    if not nome_valido(dados.nome) then
      avisar("Go: nome de projeto invalido.", vim.log.levels.ERROR)
      return
    end

    vim.ui.input({
      prompt = "Criar dentro da pasta: ",
      default = vim.fn.getcwd(),
    }, function(destino)
      if destino == nil then
        return
      end

      dados.destino = vim.trim(destino)

      vim.ui.input({
        prompt = "Caminho do modulo Go: ",
        default = "example.com/" .. dados.nome,
      }, function(modulo)
        if modulo == nil then
          return
        end

        dados.modulo = vim.trim(modulo)

        M.gerar(dados)
      end)
    end)
  end)
end

return M
