local M = {}

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

  vim.system(argumentos, {
    cwd = cwd,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      callback(resultado)
    end)
  end)
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

  table.sort(indices, function(a, b)
    local sa = vim.uv.fs_stat(a)
    local sb = vim.uv.fs_stat(b)

    local ta = sa and sa.mtime.sec or 0
    local tb = sb and sb.mtime.sec or 0

    if ta == tb then
      local na = sa and sa.mtime.nsec or 0
      local nb = sb and sb.mtime.nsec or 0

      return na > nb
    end

    return ta > tb
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
      "cmake",
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
local function preparar_cmake(raiz, arquivo, callback)
  local build = vim.fs.joinpath(raiz, "out/Debug")

  local consulta = vim.fs.joinpath(build, ".cmake/api/v1/query")

  vim.fn.mkdir(consulta, "p")

  if vim.fn.isdirectory(consulta) ~= 1 then
    ocupado = false

    avisar("C++: nao foi possivel criar a pasta CMake.", vim.log.levels.ERROR)
    return
  end

  local consulta_arquivo = vim.fs.joinpath(consulta, "codemodel-v2")

  local ok_consulta, resultado_consulta = pcall(vim.fn.writefile, {}, consulta_arquivo)

  if not ok_consulta or resultado_consulta ~= 0 then
    ocupado = false

    avisar("C++: falha ao solicitar codemodel.", vim.log.levels.ERROR)
    return
  end

  avisar("C++: configurando " .. raiz)

  executar_comando(
    {
      "cmake",
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
