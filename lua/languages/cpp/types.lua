local M = {}

-- Validar nomes de classes.
local function nome_valido(nome)
  return type(nome) == "string" and nome:match("^[%a_][%w_]*$") ~= nil
end

-- Encontrar o CMakeLists.txt mais proximo.
local function localizar_cmake(arquivo)
  local diretorio = vim.fn.getcwd()

  if arquivo and arquivo ~= "" then
    diretorio = vim.fs.dirname(vim.fn.fnamemodify(arquivo, ":p"))
  end

  local encontrados = vim.fs.find({
    "CMakeLists.txt",
  }, {
    path = diretorio,
    upward = true,
  })

  return encontrados[1]
end

-- Detectar executaveis declarados diretamente.
local function encontrar_alvos(linhas)
  local texto = table.concat(linhas, "\n")

  texto = texto:gsub("#[^\n]*", "")

  local alvos = {}
  local vistos = {}

  for alvo in texto:gmatch("add_executable%s*%(%s*([%w_%.%+%-]+)") do
    if not vistos[alvo] then
      vistos[alvo] = true
      table.insert(alvos, alvo)
    end
  end

  return alvos
end

-- Identificar um buffer ja aberto
-- para o CMakeLists.txt.
local function localizar_buffer(arquivo)
  local esperado = vim.uv.fs_realpath(arquivo) or vim.fs.normalize(arquivo)

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) then
      local nome = vim.api.nvim_buf_get_name(buffer)

      if nome ~= "" then
        local caminho = vim.uv.fs_realpath(nome) or vim.fs.normalize(nome)

        if caminho == esperado then
          return buffer
        end
      end
    end
  end

  return nil
end

-- Verificar se o diretorio include ja foi
-- configurado para determinado executavel.
local function possui_include(linhas, alvo)
  local texto = table.concat(linhas, "\n")

  for bloco in texto:gmatch("target_include_directories%s*(%b())") do
    local nome_alvo = bloco:match("^%(%s*([%w_%.%+%-]+)")

    if nome_alvo == alvo and bloco:find("/include", 1, true) then
      return true
    end
  end

  return false
end

-- Gerar declaracao da classe.
local function gerar_header(nome)
  return {
    "#pragma once",
    "",
    "class " .. nome,
    "{",
    "public:",
    "    " .. nome .. "() = default;",
    "    virtual ~" .. nome .. "() = default;",
    "",
    "    virtual void apresentar() const;",
    "};",
  }
end

-- Gerar implementacao da classe.
local function gerar_source(nome)
  return {
    '#include "' .. nome .. '.hpp"',
    "#include <iostream>",
    "",
    "void " .. nome .. "::apresentar() const",
    "{",
    '    std::cout << "' .. nome .. ' funcionando!\\n";',
    "}",
  }
end

-- Criar somente arquivos que nao existem.
local function escrever_novo(arquivo, linhas)
  local descritor, erro = vim.uv.fs_open(arquivo, "wx", 420)

  if not descritor then
    return false, erro
  end

  local texto = table.concat(linhas, "\n") .. "\n"

  local escritos, erro_escrita = vim.uv.fs_write(descritor, texto, 0)

  local fechado, erro_fechar = vim.uv.fs_close(descritor)

  if escritos ~= #texto or not fechado then
    vim.uv.fs_unlink(arquivo)

    return false, erro_escrita or erro_fechar or "escrita incompleta"
  end

  return true
end

-- Criar backup do CMakeLists.txt.
local function backup_cmake(cmake, raiz)
  local pasta = vim.fn.expand("~/.config/nvim-backup/cpp/cmake")

  vim.fn.mkdir(pasta, "p")

  if vim.fn.isdirectory(pasta) ~= 1 then
    return nil, "Diretorio de backup indisponivel."
  end

  local identificador = vim.fn.sha256(raiz):sub(1, 10)

  local nome = vim.fs.basename(raiz)
    .. "-"
    .. identificador
    .. "-"
    .. os.date("%Y%m%d-%H%M%S")
    .. "-"
    .. tostring(vim.uv.hrtime())
    .. ".cmake"

  local destino = vim.fs.joinpath(pasta, nome)

  local ok, erro = vim.uv.fs_copyfile(cmake, destino)

  if not ok then
    return nil, erro
  end

  return destino
end

-- Registrar a classe no executavel CMake.
local function atualizar_cmake(cmake, alvo, nome)
  local linhas = vim.fn.readfile(cmake)
  local alvos = encontrar_alvos(linhas)

  if not vim.tbl_contains(alvos, alvo) then
    return false, "Alvo CMake nao encontrado."
  end

  local referencia = "src/" .. nome .. ".cpp"
  local texto = table.concat(linhas, "\n")

  if texto:find(referencia, 1, true) then
    return false, "Arquivo ja declarado no CMake."
  end

  local novas = vim.deepcopy(linhas)

  -- Registrar somente o novo arquivo .cpp.
  vim.list_extend(novas, {
    "",
    "# Classe " .. nome .. " adicionada pelo CPPMenu.",
    "target_sources(" .. alvo .. " PRIVATE",
    '    "${CMAKE_CURRENT_SOURCE_DIR}/src/' .. nome .. '.cpp"',
    ")",
  })

  -- Incluir o diretorio de headers apenas
  -- quando ainda nao estiver configurado.
  if not possui_include(linhas, alvo) then
    vim.list_extend(novas, {
      "",
      "target_include_directories(" .. alvo .. " PRIVATE",
      '    "${CMAKE_CURRENT_SOURCE_DIR}/include"',
      ")",
    })
  end

  -- Criar arquivo temporario antes
  -- de substituir o CMakeLists.txt.
  local temporario = cmake .. ".nvim-" .. tostring(vim.uv.hrtime()) .. ".tmp"

  local ok, erro = escrever_novo(temporario, novas)

  if not ok then
    return false, erro
  end

  -- Evitar substituir o CMake se outro processo
  -- o alterou desde a leitura inicial.
  local atual = vim.fn.readfile(cmake)

  if not vim.deep_equal(atual, linhas) then
    vim.uv.fs_unlink(temporario)

    return false, "CMakeLists.txt mudou durante a operacao."
  end

  local renomeou, erro_rename = vim.uv.fs_rename(temporario, cmake)

  if not renomeou then
    vim.uv.fs_unlink(temporario)

    return false, erro_rename
  end

  return true
end

-- Recarregar buffer CMake apos
-- uma alteracao feita pelo gerador.
local function atualizar_buffer_cmake(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
    return
  end

  -- Nunca descartar alteracoes do usuario.
  if vim.bo[buffer].modified then
    vim.notify("C++: CMakeLists.txt possui alteracoes " .. "nao salvas. Confira o arquivo.", vim.log.levels.WARN)
    return
  end

  local ok, erro = pcall(vim.api.nvim_buf_call, buffer, function()
    vim.cmd("edit!")
  end)

  if not ok then
    vim.notify(
      "C++: CMake atualizado no disco, mas " .. "nao foi possivel recarregar o buffer: " .. tostring(erro),
      vim.log.levels.WARN
    )
  end
end

-- Criar classe e integrar ao CMake.
local function criar_classe(cmake, alvo, nome)
  if not nome_valido(nome) then
    vim.notify("C++: nome de classe invalido.", vim.log.levels.ERROR)
    return
  end

  local raiz = vim.fs.dirname(cmake)

  local src = vim.fs.joinpath(raiz, "src")
  local include = vim.fs.joinpath(raiz, "include")

  local header = vim.fs.joinpath(include, nome .. ".hpp")

  local source = vim.fs.joinpath(src, nome .. ".cpp")

  -- Nunca sobrescrever classes existentes.
  if vim.uv.fs_lstat(header) or vim.uv.fs_lstat(source) then
    vim.notify("C++: arquivos da classe ja existem.", vim.log.levels.ERROR)
    return
  end

  local buffer_cmake = localizar_buffer(cmake)

  -- Bloquear a geracao se o CMake
  -- tiver edicoes nao salvas.
  if buffer_cmake and vim.bo[buffer_cmake].modified then
    vim.notify("C++: salve o CMakeLists.txt com :w " .. "antes de criar a classe.", vim.log.levels.WARN)
    return
  end

  -- Backup obrigatorio antes de modificar.
  local backup, erro_backup = backup_cmake(cmake, raiz)

  if not backup then
    vim.notify("C++: falha no backup: " .. tostring(erro_backup), vim.log.levels.ERROR)
    return
  end

  -- Preparar diretorios.
  if vim.fn.mkdir(src, "p") == 0 and vim.fn.isdirectory(src) ~= 1 then
    vim.notify("C++: nao foi possivel criar src.", vim.log.levels.ERROR)
    return
  end

  if vim.fn.mkdir(include, "p") == 0 and vim.fn.isdirectory(include) ~= 1 then
    vim.notify("C++: nao foi possivel criar include.", vim.log.levels.ERROR)
    return
  end

  local ok_header, erro_header = escrever_novo(header, gerar_header(nome))

  if not ok_header then
    vim.notify("C++: erro no header: " .. tostring(erro_header), vim.log.levels.ERROR)
    return
  end

  local ok_source, erro_source = escrever_novo(source, gerar_source(nome))

  if not ok_source then
    vim.uv.fs_unlink(header)

    vim.notify("C++: erro no source: " .. tostring(erro_source), vim.log.levels.ERROR)
    return
  end

  local ok_cmake, erro_cmake = atualizar_cmake(cmake, alvo, nome)

  if not ok_cmake then
    vim.uv.fs_unlink(header)
    vim.uv.fs_unlink(source)

    vim.notify("C++: erro ao atualizar CMake: " .. tostring(erro_cmake), vim.log.levels.ERROR)
    return
  end

  -- Sincronizar o buffer aberto com o disco.
  atualizar_buffer_cmake(buffer_cmake)

  vim.notify("C++: classe " .. nome .. " criada no alvo " .. alvo .. ". Backup: " .. backup, vim.log.levels.INFO)

  local abriu, erro_abrir = pcall(vim.cmd.edit, vim.fn.fnameescape(source))

  if not abriu then
    vim.notify(
      "C++: classe criada, mas houve erro " .. "ao abrir o source: " .. tostring(erro_abrir),
      vim.log.levels.WARN
    )
  end
end

-- Interface do gerador.
function M.criar(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local cmake = localizar_cmake(arquivo)

  if not cmake then
    vim.notify("C++: projeto CMake nao encontrado.", vim.log.levels.WARN)
    return
  end

  local linhas = vim.fn.readfile(cmake)
  local alvos = encontrar_alvos(linhas)

  if #alvos == 0 then
    vim.notify("C++: nenhum add_executable simples " .. "encontrado no CMakeLists.txt.", vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = "Nome da classe C++: ",
  }, function(nome)
    if nome == nil then
      return
    end

    nome = vim.trim(nome)

    if not nome_valido(nome) then
      vim.notify("C++: nome de classe invalido.", vim.log.levels.ERROR)
      return
    end

    -- Projeto com um executavel.
    if #alvos == 1 then
      criar_classe(cmake, alvos[1], nome)
      return
    end

    -- Projeto com varios executaveis.
    vim.ui.select(alvos, {
      prompt = "Adicionar " .. nome .. " ao alvo CMake:",
    }, function(alvo)
      if alvo then
        criar_classe(cmake, alvo, nome)
      end
    end)
  end)
end

return M
