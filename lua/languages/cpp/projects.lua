local M = {}

-- ========================================
-- C++ - GERADOR DE PROJETOS
-- ========================================
-- Suporta Meson e CMake.
--
-- Mantem compatibilidade com chamadas
-- antigas de projetos.criar() e
-- projetos.gerar(dados).
--
-- Meson:
--   projetos.criar("meson")
--
-- CMake:
--   projetos.criar("cmake")
--   projetos.criar()
-- ========================================

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function nome_valido(nome)
  return type(nome) == "string" and nome:match("^[%a_][%w_%-]*$") ~= nil
end

local function padrao_valido(padrao)
  return padrao == "17" or padrao == "20" or padrao == "23"
end

local function sistema_valido(sistema)
  return sistema == "meson" or sistema == "cmake"
end

-- ========================================
-- GERAR CMAKE
-- ========================================

local function gerar_cmake(nome, padrao)
  return {
    "cmake_minimum_required(VERSION 3.28)",
    "",
    "project(" .. nome,
    "    VERSION 1.0",
    "    LANGUAGES CXX",
    ")",
    "",
    "set(CMAKE_CXX_STANDARD " .. padrao .. ")",
    "set(CMAKE_CXX_STANDARD_REQUIRED ON)",
    "set(CMAKE_CXX_EXTENSIONS OFF)",
    "",
    "set(CMAKE_EXPORT_COMPILE_COMMANDS ON)",
    "",
    "if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)",
    '    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type")',
    "endif()",
    "",
    "add_executable(" .. nome,
    "    src/main.cpp",
    ")",
    "",
    "target_include_directories(" .. nome .. " PRIVATE",
    "    ${CMAKE_CURRENT_SOURCE_DIR}/include",
    ")",
  }
end

-- ========================================
-- GERAR MESON
-- ========================================

local function gerar_meson(nome, padrao)
  return {
    "project(",
    "  '" .. nome .. "',",
    "  'cpp',",
    "  version: '1.0.0',",
    "  default_options: [",
    "    'cpp_std=c++" .. padrao .. "',",
    "    'buildtype=debug',",
    "  ]",
    ")",
    "",
    "inc = include_directories('include')",
    "",
    "executable(",
    "  '" .. nome .. "',",
    "  'src/main.cpp',",
    "  include_directories: inc",
    ")",
  }
end

-- ========================================
-- GERAR MAIN.CPP
-- ========================================

local function gerar_main()
  return {
    "#include <iostream>",
    "",
    "int main()",
    "{",
    '    std::cout << "Projeto C++ funcionando!\\n";',
    "",
    "    return 0;",
    "}",
  }
end

-- ========================================
-- GERAR GITIGNORE
-- ========================================

local function gerar_gitignore()
  return {
    "build/",
    "out/",
    ".cache/",
    "compile_commands.json",
  }
end

-- ========================================
-- CRIACAO EXCLUSIVA DE ARQUIVOS
-- ========================================

local function escrever_novo(caminho, linhas)
  local descritor, erro = vim.uv.fs_open(caminho, "wx", 420)

  if not descritor then
    return false, erro
  end

  local conteudo = table.concat(linhas, "\n") .. "\n"

  local escritos, erro_escrita = vim.uv.fs_write(descritor, conteudo, 0)

  local fechado, erro_fechar = vim.uv.fs_close(descritor)

  if escritos ~= #conteudo or not fechado then
    local removido, erro_remocao = vim.uv.fs_unlink(caminho)

    local mensagem = erro_escrita or erro_fechar or "Escrita incompleta."

    if not removido then
      mensagem = tostring(mensagem)
        .. " Arquivo parcial preservado: "
        .. caminho
        .. " ("
        .. tostring(erro_remocao)
        .. ")"
    end

    return false, mensagem
  end

  return true
end

-- ========================================
-- LIMPEZA CONTROLADA DE FALHAS
-- ========================================
-- Desfazer apenas caminhos criados
-- nesta operacao.
--
-- fs_rmdir somente remove diretorios
-- vazios, preservando conteudos que
-- possam ter aparecido posteriormente.

local function desfazer(criados)
  local falhas = {}

  for indice = #criados, 1, -1 do
    local item = criados[indice]

    local sucesso, erro

    if item.tipo == "arquivo" then
      sucesso, erro = vim.uv.fs_unlink(item.caminho)
    else
      sucesso, erro = vim.uv.fs_rmdir(item.caminho)
    end

    if not sucesso then
      table.insert(falhas, item.caminho .. ": " .. tostring(erro))
    end
  end

  return falhas
end

-- ========================================
-- GERACAO DO PROJETO
-- ========================================

function M.gerar(dados)
  if type(dados) ~= "table" then
    avisar("C++: dados de projeto invalidos.", vim.log.levels.ERROR)
    return false
  end

  local nome = dados.nome
  local padrao = tostring(dados.padrao)
  local sistema = dados.sistema or "cmake"

  if not nome_valido(nome) then
    avisar("C++: nome de projeto invalido.", vim.log.levels.ERROR)
    return false
  end

  if not padrao_valido(padrao) then
    avisar("C++: padrao C++ nao suportado.", vim.log.levels.ERROR)
    return false
  end

  if not sistema_valido(sistema) then
    avisar("C++: sistema de build invalido.", vim.log.levels.ERROR)
    return false
  end

  if type(dados.destino) ~= "string" or vim.trim(dados.destino) == "" then
    avisar("C++: diretorio de destino invalido.", vim.log.levels.ERROR)
    return false
  end

  local pai = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dados.destino), ":p"))

  local info_pai = vim.uv.fs_stat(pai)

  if not info_pai or info_pai.type ~= "directory" then
    avisar("C++: diretorio de destino nao existe.", vim.log.levels.ERROR)
    return false
  end

  local raiz = vim.fs.joinpath(pai, nome)

  -- Nunca utilizar um caminho preexistente,
  -- inclusive links simbolicos quebrados.
  if vim.uv.fs_lstat(raiz) then
    avisar("C++: projeto ja existe: " .. raiz, vim.log.levels.ERROR)
    return false
  end

  local criados = {}

  local function registrar(caminho, tipo)
    table.insert(criados, {
      caminho = caminho,
      tipo = tipo,
    })
  end

  local function falhar(mensagem)
    local falhas = desfazer(criados)

    if #falhas > 0 then
      mensagem = mensagem .. " Limpeza incompleta: " .. table.concat(falhas, "; ")
    end

    avisar("C++: " .. mensagem, vim.log.levels.ERROR)

    return false
  end

  -- ========================================
  -- CRIAR DIRETORIO PRINCIPAL
  -- ========================================

  local criou_raiz, erro_raiz = vim.uv.fs_mkdir(raiz, 493)

  if not criou_raiz then
    avisar("C++: falha ao criar projeto: " .. tostring(erro_raiz), vim.log.levels.ERROR)
    return false
  end

  registrar(raiz, "diretorio")

  local src = vim.fs.joinpath(raiz, "src")
  local include = vim.fs.joinpath(raiz, "include")

  local criou_src, erro_src = vim.uv.fs_mkdir(src, 493)

  if not criou_src then
    return falhar("falha ao criar src: " .. tostring(erro_src))
  end

  registrar(src, "diretorio")

  local criou_include, erro_include = vim.uv.fs_mkdir(include, 493)

  if not criou_include then
    return falhar("falha ao criar include: " .. tostring(erro_include))
  end

  registrar(include, "diretorio")

  -- ========================================
  -- PREPARAR ARQUIVOS
  -- ========================================

  local configuracao
  local linhas_configuracao

  if sistema == "meson" then
    configuracao = vim.fs.joinpath(raiz, "meson.build")

    linhas_configuracao = gerar_meson(nome, padrao)
  else
    configuracao = vim.fs.joinpath(raiz, "CMakeLists.txt")

    linhas_configuracao = gerar_cmake(nome, padrao)
  end

  local arquivos = {
    {
      caminho = configuracao,
      linhas = linhas_configuracao,
    },
    {
      caminho = vim.fs.joinpath(src, "main.cpp"),
      linhas = gerar_main(),
    },
    {
      caminho = vim.fs.joinpath(raiz, ".gitignore"),
      linhas = gerar_gitignore(),
    },
  }

  for _, item in ipairs(arquivos) do
    local sucesso, erro = escrever_novo(item.caminho, item.linhas)

    if not sucesso then
      return falhar("falha ao criar " .. item.caminho .. ": " .. tostring(erro))
    end

    registrar(item.caminho, "arquivo")
  end

  -- ========================================
  -- CONCLUSAO
  -- ========================================

  avisar("C++: projeto " .. sistema .. " criado em " .. raiz)

  local main = vim.fs.joinpath(src, "main.cpp")

  local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(main))

  if not abriu then
    avisar("C++: projeto criado, mas main.cpp nao abriu: " .. tostring(erro_abrir), vim.log.levels.WARN)
  end

  return true
end

-- ========================================
-- INTERFACE DE CRIACAO
-- ========================================
-- Sem argumento: preserva o CMake antigo.
-- Com "meson": cria projeto Meson.

function M.criar(sistema)
  sistema = sistema or "cmake"

  if not sistema_valido(sistema) then
    avisar("C++: sistema de build invalido.", vim.log.levels.ERROR)
    return
  end

  local dados = {
    sistema = sistema,
  }

  vim.ui.input({
    prompt = "Nome do projeto C++: ",
  }, function(nome)
    if nome == nil then
      return
    end

    dados.nome = vim.trim(nome)

    if not nome_valido(dados.nome) then
      avisar("C++: nome invalido.", vim.log.levels.ERROR)
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

      vim.ui.select({
        "17",
        "20",
        "23",
      }, {
        prompt = "Selecione o padrao C++:",
        format_item = function(valor)
          return "C++" .. valor
        end,
      }, function(padrao)
        if padrao == nil then
          return
        end

        dados.padrao = padrao

        M.gerar(dados)
      end)
    end)
  end)
end

return M
