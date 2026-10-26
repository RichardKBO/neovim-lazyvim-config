local M = {}

-- Ferramentas C++ instaladas no HDD.
local CMAKE = "cmake-4.4.4"
local CMAKE_GENERATOR = "Ninja"
local CMAKE_BUILD_DIR = "out/Debug-Ninja-CMake4"

local ocupado = false

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO)
end

local function normalizar(caminho)
  return vim.fs.normalize(vim.fn.fnamemodify(caminho, ":p"))
end

-- Encontrar o projeto a partir do arquivo,
-- sem depender do cwd do Neovim.
local function localizar_projeto(arquivo)
  local encontrados = vim.fs.find("CMakeLists.txt", {
    path = vim.fs.dirname(arquivo),
    upward = true,
  })

  if #encontrados == 0 then
    return nil
  end

  return vim.fs.dirname(encontrados[1])
end

local function ler_json(caminho)
  local ok, linhas = pcall(vim.fn.readfile, caminho)

  if not ok then
    return nil
  end

  local sucesso, dados = pcall(vim.json.decode, table.concat(linhas, "\n"))

  if not sucesso then
    return nil
  end

  return dados
end

-- Executar processos de forma assincrona,
-- mantendo o diretorio do editor intacto.
local function executar_comando(argumentos, cwd, callback)
  if vim.fn.executable(argumentos[1]) ~= 1 then
    callback({
      code = 1,
      stdout = "",
      stderr = "Comando indisponivel: " .. argumentos[1],
    })
    return
  end

  local ok, erro = pcall(vim.system, argumentos, {
    cwd = cwd,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      callback(resultado)
    end)
  end)

  if not ok then
    callback({
      code = 1,
      stdout = "",
      stderr = "Falha ao iniciar o comando: " .. tostring(erro),
    })
  end
end

local function mostrar_erro(etapa, resultado)
  ocupado = false

  avisar("C++: falha em " .. etapa, vim.log.levels.ERROR)

  local saida = (resultado.stdout or "") .. "\n" .. (resultado.stderr or "")

  if vim.trim(saida) ~= "" then
    vim.fn.setqflist({}, "r", {
      title = "C++ - " .. etapa,
      lines = vim.split(saida, "\n", {
        trimempty = true,
      }),
    })

    vim.cmd("copen")
  end
end

-- Entregar um executavel pronto ao F6 ou F8.
local function concluir(executavel, callback)
  ocupado = false

  if vim.fn.executable(executavel) ~= 1 then
    avisar("C++: executavel nao encontrado: " .. executavel, vim.log.levels.ERROR)
    return
  end

  local cwd = vim.fs.dirname(executavel)

  local ok, erro = pcall(callback, executavel, cwd)

  if not ok then
    avisar("C++: falha ao iniciar programa: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- Consultar os executaveis do CMake File API.
-- Identificar os que utilizam o arquivo atual.
local function localizar_alvos(raiz, build, arquivo)
  local respostas = vim.fs.joinpath(build, ".cmake/api/v1/reply")

  local indices = vim.fn.glob(respostas .. "/index-*.json", false, true)

  -- CMake File API: o indice atual possui o maior
  -- nome em ordem lexicografica.
  table.sort(indices, function(a, b)
    return vim.fs.basename(a) > vim.fs.basename(b)
  end)

  if #indices == 0 then
    return nil, "CMake File API sem respostas."
  end

  local indice = ler_json(indices[1])

  if not indice then
    return nil, "Indice CMake invalido."
  end

  local modelo_arquivo = nil

  for _, objeto in ipairs(indice.objects or {}) do
    if objeto.kind == "codemodel" and objeto.version and objeto.version.major == 2 then
      modelo_arquivo = objeto.jsonFile
      break
    end
  end

  if not modelo_arquivo then
    return nil, "Codemodel CMake nao encontrado."
  end

  local modelo = ler_json(vim.fs.joinpath(respostas, modelo_arquivo))

  if not modelo then
    return nil, "Erro ao ler codemodel CMake."
  end

  local alvos = {}
  local vistos = {}

  for _, configuracao in ipairs(modelo.configurations or {}) do
    for _, referencia in ipairs(configuracao.targets or {}) do
      local alvo = ler_json(vim.fs.joinpath(respostas, referencia.jsonFile))

      if alvo and alvo.type == "EXECUTABLE" then
        local pertence = false

        for _, fonte in ipairs(alvo.sources or {}) do
          local caminho = fonte.path

          if caminho and not caminho:match("^/") then
            caminho = vim.fs.joinpath(raiz, caminho)
          end

          if caminho and vim.fs.normalize(caminho) == arquivo then
            pertence = true
            break
          end
        end

        local artefato = alvo.artifacts and alvo.artifacts[1]

        if pertence and artefato and artefato.path then
          local identificador = referencia.id or referencia.name

          if not vistos[identificador] then
            vistos[identificador] = true

            local executavel = artefato.path

            if not executavel:match("^/") then
              executavel = vim.fs.joinpath(build, executavel)
            end

            table.insert(alvos, {
              nome = referencia.name,
              executavel = vim.fs.normalize(executavel),
            })
          end
        end
      end
    end
  end

  return alvos
end

local function compilar_alvo(raiz, build, alvo, callback)
  avisar("C++: compilando " .. alvo.nome)

  executar_comando(
    {
      CMAKE,
      "--build",
      build,
      "--target",
      alvo.nome,
    },
    raiz,
    function(resultado)
      if resultado.code ~= 0 then
        mostrar_erro("compilacao", resultado)
        return
      end

      concluir(alvo.executavel, callback)
    end
  )
end

-- Configurar e preparar um executavel CMake.
-- ========================================
-- BANCO DE COMPILACAO POR PROJETO
-- ========================================

local function sincronizar_compile_commands(raiz, build)
  local origem = vim.fs.joinpath(build, "compile_commands.json")
  local link = vim.fs.joinpath(raiz, "compile_commands.json")

  -- Utilizar o banco de compilacao do build selecionado.
  -- Para builds externos ao projeto, utilizar caminho absoluto.
  local destino_relativo = vim.fs.relpath(raiz, origem) or origem

  -- Registrar somente links gerenciados pelo Neovim.
  -- Cada projeto possui um registro independente.
  local raiz_canonica = vim.uv.fs_realpath(raiz) or raiz

  local arquivo_registro = vim.fs.joinpath(
    vim.fn.stdpath("state"),
    "cpp-compile-db",
    vim.fn.sha256(raiz_canonica) .. ".json"
  )

  local function ler_destino_gerenciado()
    if vim.fn.filereadable(arquivo_registro) ~= 1 then
      return nil
    end

    local ok, linhas = pcall(vim.fn.readfile, arquivo_registro)

    if not ok then
      return nil
    end

    local valido, dados = pcall(
      vim.json.decode,
      table.concat(linhas, "\n")
    )

    if not valido or type(dados) ~= "table" then
      return nil
    end

    if dados.raiz ~= raiz_canonica then
      return nil
    end

    if type(dados.destino) ~= "string" then
      return nil
    end

    return dados.destino
  end

  local function registrar_link(destino)
    local pasta = vim.fs.dirname(arquivo_registro)

    vim.fn.mkdir(pasta, "p")

    if vim.fn.isdirectory(pasta) ~= 1 then
      avisar(
        "C++: falha ao criar pasta do registro do banco.",
        vim.log.levels.ERROR
      )
      return false
    end

    local dados = vim.json.encode({
      raiz = raiz_canonica,
      destino = destino,
    })

    local temporario =
      arquivo_registro .. ".tmp-" .. tostring(vim.uv.hrtime())

    local ok, resultado = pcall(
      vim.fn.writefile,
      { dados },
      temporario
    )

    if not ok or resultado ~= 0 then
      vim.fn.delete(temporario)
      avisar(
        "C++: falha ao registrar banco de compilacao.",
        vim.log.levels.ERROR
      )
      return false
    end

    local sucesso, erro = vim.uv.fs_rename(
      temporario,
      arquivo_registro
    )

    if not sucesso then
      vim.fn.delete(temporario)
      avisar(
        "C++: falha ao salvar registro do banco: " .. tostring(erro),
        vim.log.levels.ERROR
      )
      return false
    end

    return true
  end

  if vim.fn.filereadable(origem) ~= 1 then
    avisar("C++: banco de compilacao nao encontrado.", vim.log.levels.WARN)
    return
  end

  -- fs_lstat detecta inclusive links simbolicos quebrados.
  local informacoes, erro_stat, codigo_stat = vim.uv.fs_lstat(link)

  if informacoes then
    if informacoes.type == "link" then
      local destino_atual = vim.uv.fs_readlink(link)

      if destino_atual == destino_relativo then
        return
      end

      -- Aceitar links legados conhecidos ou links registrados
      -- anteriormente pelo proprio Neovim.
      local legado_absoluto =
        vim.fs.joinpath(raiz, "out", "Debug", "compile_commands.json")
      local legado_relativo = "out/Debug/compile_commands.json"

      local tradicional_relativo =
        vim.fs.joinpath(CMAKE_BUILD_DIR, "compile_commands.json")
      local tradicional_absoluto =
        vim.fs.joinpath(raiz, tradicional_relativo)

      local registrado = ler_destino_gerenciado()

      if destino_atual == legado_absoluto
        or destino_atual == legado_relativo
        or destino_atual == tradicional_relativo
        or destino_atual == tradicional_absoluto
        or (registrado and destino_atual == registrado)
      then
        -- Preparar o novo link sem remover o antigo.
        local temporario = link .. ".nvim-cpp-" .. tostring(vim.uv.hrtime())

        local criado, erro_criacao =
          vim.uv.fs_symlink(destino_relativo, temporario)

        if not criado then
          avisar(
            "C++: falha ao preparar migracao: " .. tostring(erro_criacao),
            vim.log.levels.ERROR
          )
          return
        end

        -- Verificar novamente se o link antigo nao mudou.
        if vim.uv.fs_readlink(link) ~= destino_atual then
          vim.uv.fs_unlink(temporario)
          avisar("C++: link alterado durante a migracao.", vim.log.levels.WARN)
          return
        end

        -- Substituicao atomica no sistema de arquivos Linux.
        local migrado, erro_migracao = vim.uv.fs_rename(temporario, link)

        if not migrado then
          vim.uv.fs_unlink(temporario)
          avisar(
            "C++: falha ao migrar banco: " .. tostring(erro_migracao),
            vim.log.levels.ERROR
          )
          return
        end

        registrar_link(destino_relativo)
        avisar("C++: banco de compilacao atualizado: " .. raiz)
        return
      end
    end

    -- Preservar arquivos reais e links desconhecidos.
    avisar(
      "C++: compile_commands.json ja existe na raiz e sera preservado: " .. link,
      vim.log.levels.WARN
    )
    return
  end

  if codigo_stat ~= "ENOENT" then
    avisar(
      "C++: nao foi possivel verificar o banco existente: " .. tostring(erro_stat),
      vim.log.levels.ERROR
    )
    return
  end

  local sucesso, erro_link = vim.uv.fs_symlink(destino_relativo, link)

  if not sucesso then
    avisar(
      "C++: falha ao criar link do banco: " .. tostring(erro_link),
      vim.log.levels.ERROR
    )
    return
  end

  registrar_link(destino_relativo)
  avisar("C++: banco de compilacao vinculado ao projeto: " .. raiz)
end

local function selecionar_e_compilar(raiz, build, arquivo, callback)
  local alvos, erro = localizar_alvos(raiz, build, arquivo)

  if not alvos then
    ocupado = false

    avisar("C++: " .. erro, vim.log.levels.ERROR)
    return
  end

  if #alvos == 0 then
    ocupado = false

    avisar(
      "C++: arquivo nao pertence a um executavel " .. "CMake. Verifique add_executable() " .. "ou target_sources().",
      vim.log.levels.WARN
    )
    return
  end

  if #alvos == 1 then
    compilar_alvo(raiz, build, alvos[1], callback)
    return
  end

  -- Perguntar apenas quando o mesmo arquivo
  -- participa de mais de um executavel.
  vim.ui.select(alvos, {
    prompt = "Selecione o executavel C++:",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      ocupado = false
      return
    end

    compilar_alvo(raiz, build, escolha, callback)
  end)
end

local function solicitar_codemodel(build)
  local consulta = vim.fs.joinpath(build, ".cmake/api/v1/query")

  vim.fn.mkdir(consulta, "p")

  if vim.fn.isdirectory(consulta) ~= 1 then
    ocupado = false
    avisar("C++: nao foi possivel criar a pasta CMake.", vim.log.levels.ERROR)
    return false
  end

  local consulta_arquivo = vim.fs.joinpath(consulta, "codemodel-v2")

  local ok, resultado = pcall(vim.fn.writefile, {}, consulta_arquivo)

  if not ok or resultado ~= 0 then
    ocupado = false
    avisar("C++: falha ao solicitar codemodel.", vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Validar o indice e o codemodel da CMake File API.
local function resposta_codemodel_valida(build)
  local pasta = vim.fs.joinpath(build, ".cmake/api/v1/reply")
  local indices = vim.fn.glob(
    vim.fs.joinpath(pasta, "index-*.json"), false, true
  )

  table.sort(indices, function(a, b)
    return vim.fs.basename(a) > vim.fs.basename(b)
  end)

  if #indices == 0 then
    return false
  end

  local indice = ler_json(indices[1])

  if type(indice) ~= "table" or type(indice.objects) ~= "table" then
    return false
  end

  for _, objeto in ipairs(indice.objects) do
    if type(objeto) == "table"
      and objeto.kind == "codemodel"
      and type(objeto.version) == "table"
      and objeto.version.major == 2
      and type(objeto.jsonFile) == "string"
    then
      local modelo = ler_json(vim.fs.joinpath(pasta, objeto.jsonFile))

      if type(modelo) == "table"
        and modelo.kind == "codemodel"
        and type(modelo.version) == "table"
        and modelo.version.major == 2
        and type(modelo.configurations) == "table"
      then
        return true
      end
    end
  end

  return false
end

local function preparar_cmake(raiz, arquivo, callback)
  -- CMake Presets: respeitar a configuracao salva por projeto.
  if vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakePresets.json")) == 1
    or vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakeUserPresets.json")) == 1
  then
    local ok_modulo, presets = pcall(require, "languages.cpp.presets")

    if not ok_modulo or type(presets.configurar) ~= "function" then
      ocupado = false
      avisar("C++: modulo de presets indisponivel.", vim.log.levels.ERROR)
      return
    end

    presets.configurar(raiz, function(nome, saida)
      if not nome then
        ocupado = false
        return
      end

      local build = nil

      for linha in (saida or ""):gmatch("[^\r\n]+") do
        local candidato = linha:match(
          "^%-%- Build files have been written to:%s*(.-)%s*$"
        )

        if candidato and candidato ~= "" then
          if not candidato:match("^/") then
            candidato = vim.fs.joinpath(raiz, candidato)
          end

          build = vim.fs.normalize(candidato)
        end
      end

      if not build
        or vim.fn.filereadable(
          vim.fs.joinpath(build, "CMakeCache.txt")
        ) ~= 1
      then
        ocupado = false
        avisar(
          "C++: diretorio de build do preset nao confirmado.",
          vim.log.levels.ERROR
        )
        return
      end

      local consulta_arquivo = vim.fs.joinpath(
        build, ".cmake/api/v1/query/codemodel-v2"
      )

      local consulta_existia = vim.fn.filereadable(consulta_arquivo) == 1

      if not solicitar_codemodel(build) then
        return
      end

      local function continuar()
        sincronizar_compile_commands(raiz, build)
        selecionar_e_compilar(raiz, build, arquivo, callback)
      end

      -- Reutilizar apenas um codemodel v2 verificavel.
      if consulta_existia and resposta_codemodel_valida(build) then
        continuar()
        return
      end

      -- Primeira utilizacao: gerar a resposta da CMake File API.
      avisar("C++: gerando codemodel do preset " .. nome)

      executar_comando(
        { CMAKE, "--preset", nome },
        raiz,
        function(resultado)
          if resultado.code ~= 0 then
            mostrar_erro("codemodel do preset", resultado)
            return
          end

          continuar()
        end
      )
    end)

    return
  end

  local build = vim.fs.joinpath(raiz, CMAKE_BUILD_DIR)

  if not solicitar_codemodel(build) then
    return
  end

  avisar("C++: configurando " .. raiz)

  executar_comando(
    {
      CMAKE,
      "-G",
      CMAKE_GENERATOR,
      "-S",
      raiz,
      "-B",
      build,
      "-DCMAKE_BUILD_TYPE=Debug",
      "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
    },
    raiz,
    function(resultado)
      if resultado.code ~= 0 then
        mostrar_erro("configuracao CMake", resultado)
        return
      end

      sincronizar_compile_commands(raiz, build)

      selecionar_e_compilar(raiz, build, arquivo, callback)
    end
  )
end

-- Preparar arquivo independente, sem CMake.
local function preparar_isolado(arquivo, extensao, callback)
  local pasta = vim.fs.joinpath(vim.fn.stdpath("cache"), "cpp-f6")

  vim.fn.mkdir(pasta, "p")

  if vim.fn.isdirectory(pasta) ~= 1 then
    ocupado = false

    avisar("C++: falha ao criar pasta temporaria.", vim.log.levels.ERROR)
    return
  end

  local executavel = vim.fs.joinpath(pasta, vim.fn.sha256(arquivo):sub(1, 16))

  local compilador = "g++"
  local padrao = "-std=c++23"

  if extensao == "c" then
    compilador = "gcc"
    padrao = "-std=c17"
  end

  executar_comando(
    {
      compilador,
      padrao,
      "-g",
      "-Wall",
      "-Wextra",
      arquivo,
      "-o",
      executavel,
    },
    vim.fs.dirname(arquivo),
    function(resultado)
      if resultado.code ~= 0 then
        mostrar_erro("arquivo independente", resultado)
        return
      end

      concluir(executavel, callback)
    end
  )
end

-- ========================================
-- F7: CONFIGURAR PROJETO CMAKE ATUAL
-- ========================================

function M.configurar(arquivo)
  if ocupado then
    avisar("C++: aguarde a operacao anterior.", vim.log.levels.WARN)
    return
  end

  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("C++: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = normalizar(arquivo)

  local raiz = localizar_projeto(arquivo)

  if not raiz then
    avisar("C++: projeto CMake nao encontrado para o arquivo atual.", vim.log.levels.WARN)
    return
  end

  -- Salvar o arquivo atual antes de configurar.
  local buffer_atual = vim.api.nvim_buf_get_name(0)

  if buffer_atual ~= "" and normalizar(buffer_atual) == arquivo then
    local ok, erro = pcall(vim.cmd, "update")

    if not ok then
      avisar("C++: falha ao salvar: " .. tostring(erro), vim.log.levels.ERROR)
      return
    end
  end

  -- Projetos com presets usam a configuracao declarada pelo projeto.
  -- Projetos tradicionais continuam no fluxo original.
  if vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakePresets.json")) == 1
    or vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakeUserPresets.json")) == 1
  then
    local ok_modulo, presets = pcall(
      require,
      "languages.cpp.presets"
    )

    if not ok_modulo or type(presets.configurar) ~= "function" then
      avisar(
        "C++: modulo de CMake Presets indisponivel.",
        vim.log.levels.ERROR
      )
      return
    end

    ocupado = true

    presets.configurar(raiz, function(nome, saida)
      if not nome then
        ocupado = false
        return
      end

      -- O CMake informa o diretorio efetivo apos configurar.
      -- Nao presumir que o preset usa o build padrao.
      local build = nil

      for linha in (saida or ""):gmatch("[^\r\n]+") do
        local candidato = linha:match(
          "^%-%- Build files have been written to:%s*(.-)%s*$"
        )

        if candidato and candidato ~= "" then
          build = vim.fs.normalize(candidato)
        end
      end

      if not build
        or vim.fn.filereadable(
          vim.fs.joinpath(build, "CMakeCache.txt")
        ) ~= 1
      then
        ocupado = false
        avisar(
          "C++: nao foi possivel confirmar o diretorio de build do preset.",
          vim.log.levels.ERROR
        )
        return
      end

      sincronizar_compile_commands(raiz, build)

      ocupado = false

      avisar(
        "C++: F7 configurou o preset "
          .. nome
          .. " em "
          .. build
      )
    end)

    return
  end

  local build = vim.fs.joinpath(raiz, CMAKE_BUILD_DIR)

  ocupado = true

  avisar("C++: configurando projeto " .. raiz)

  executar_comando(
    {
      CMAKE,
      "-G",
      CMAKE_GENERATOR,
      "-S",
      raiz,
      "-B",
      build,
      "-DCMAKE_BUILD_TYPE=Debug",
      "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
    },
    raiz,
    function(resultado)
      if resultado.code ~= 0 then
        mostrar_erro("configuracao CMake", resultado)
        return
      end

      sincronizar_compile_commands(raiz, build)

      ocupado = false
      avisar("C++: configuracao CMake concluida: " .. raiz)
    end
  )
end

-- Preparador compartilhado por F6 e F8.
-- O callback recebe (executavel, cwd).
function M.preparar(arquivo, callback)
  if type(callback) ~= "function" then
    avisar("C++: callback de preparacao invalido.", vim.log.levels.ERROR)
    return
  end

  if ocupado then
    avisar("C++: aguarde a preparacao anterior.", vim.log.levels.WARN)
    return
  end

  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  if arquivo == "" then
    avisar("C++: nenhum arquivo aberto.", vim.log.levels.WARN)
    return
  end

  arquivo = normalizar(arquivo)

  local extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()

  if not vim.tbl_contains({
    "c",
    "cc",
    "cpp",
    "cxx",
  }, extensao) then
    avisar("C++: extensao nao suportada.", vim.log.levels.WARN)
    return
  end

  -- Salvar o buffer atual antes da compilacao.
  local buffer_atual = vim.api.nvim_buf_get_name(0)

  if buffer_atual ~= "" and normalizar(buffer_atual) == arquivo then
    local ok, erro = pcall(vim.cmd, "update")

    if not ok then
      avisar("C++: falha ao salvar: " .. tostring(erro), vim.log.levels.ERROR)
      return
    end
  end

  if vim.fn.filereadable(arquivo) ~= 1 then
    avisar("C++: arquivo nao encontrado no disco.", vim.log.levels.ERROR)
    return
  end

  ocupado = true

  local raiz = localizar_projeto(arquivo)

  if raiz then
    preparar_cmake(raiz, arquivo, callback)
  else
    preparar_isolado(arquivo, extensao, callback)
  end
end

-- F6: preparar e executar no terminal.
function M.executar(arquivo)
  M.preparar(arquivo, function(executavel, cwd)
    vim.cmd("botright 12new")

    local processo = vim.fn.termopen({ executavel }, { cwd = cwd })

    if processo <= 0 then
      avisar("C++: falha ao iniciar o terminal.", vim.log.levels.ERROR)
      return
    end

    vim.cmd("startinsert")
  end)
end

return M
