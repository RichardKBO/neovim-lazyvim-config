local M = {}

-- Validar nomes utilizados em diretorios,
-- projetos CMake e executaveis.
local function nome_valido(nome)
  return type(nome) == "string" and nome:match("^[%a_][%w_%-]*$") ~= nil
end

-- Escrever os arquivos gerados.
local function escrever(arquivo, linhas)
  local ok, resultado = pcall(vim.fn.writefile, linhas, arquivo)

  return ok and resultado == 0
end

-- Criar o CMakeLists.txt.
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

-- Criar o main.cpp inicial.
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

function M.gerar(dados)
  if not nome_valido(dados.nome) then
    vim.notify("C++: nome de projeto invalido.", vim.log.levels.ERROR)
    return
  end

  local padroes = {
    ["17"] = true,
    ["20"] = true,
    ["23"] = true,
  }

  if not padroes[tostring(dados.padrao)] then
    vim.notify("C++: padrao C++ nao suportado.", vim.log.levels.ERROR)
    return
  end

  -- A pasta de destino e informada pelo usuario.
  local pai = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dados.destino), ":p"))

  if vim.fn.isdirectory(pai) ~= 1 then
    vim.notify("C++: diretorio de destino nao existe.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.joinpath(pai, dados.nome)

  -- Nunca sobrescrever projetos existentes.
  if vim.uv.fs_lstat(raiz) then
    vim.notify("C++: projeto ja existe: " .. raiz, vim.log.levels.ERROR)
    return
  end

  -- Criar exclusivamente a pasta principal.
  local criado, erro = vim.uv.fs_mkdir(raiz, 493)

  if not criado then
    vim.notify("C++: falha ao criar projeto: " .. tostring(erro), vim.log.levels.ERROR)
    return
  end

  local src = vim.fs.joinpath(raiz, "src")

  local include = vim.fs.joinpath(raiz, "include")

  local ok_src = vim.fn.mkdir(src, "p") == 1
  local ok_include = vim.fn.mkdir(include, "p") == 1

  if not ok_src or not ok_include then
    vim.notify("C++: falha ao criar estrutura. Verifique: " .. raiz, vim.log.levels.ERROR)
    return
  end

  local cmake = vim.fs.joinpath(raiz, "CMakeLists.txt")

  local main = vim.fs.joinpath(src, "main.cpp")

  local gitignore = vim.fs.joinpath(raiz, ".gitignore")

  local sucesso = escrever(cmake, gerar_cmake(dados.nome, dados.padrao))
    and escrever(main, gerar_main())
    and escrever(gitignore, {
      "build/",
      "out/",
      ".cache/",
      "compile_commands.json",
    })

  if not sucesso then
    vim.notify("C++: erro na escrita. Projeto parcial em: " .. raiz, vim.log.levels.ERROR)
    return
  end

  vim.notify("C++: projeto criado em " .. raiz, vim.log.levels.INFO)

  local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(main))

  if not abriu then
    vim.notify("Projeto criado, mas main.cpp nao abriu: " .. tostring(erro_abrir), vim.log.levels.WARN)
  end
end

-- Interface de criacao de projetos.
function M.criar()
  local dados = {}

  vim.ui.input({
    prompt = "Nome do projeto C++: ",
  }, function(nome)
    if nome == nil then
      return
    end

    dados.nome = vim.trim(nome)

    if not nome_valido(dados.nome) then
      vim.notify("C++: nome invalido.", vim.log.levels.ERROR)
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
