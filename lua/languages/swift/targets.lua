-- ========================================
-- SWIFT - GERENCIAMENTO DE TARGETS SWIFTPM
-- Criacao segura usando comandos oficiais
-- ========================================

local M = {}

local uv = vim.uv or vim.loop

-- Bloqueio compartilhado entre os modulos SwiftPM.
local package_lock = require("languages.swift.package_lock")

local tipos = {
  { nome = "Biblioteca", valor = "library" },
  { nome = "Executavel", valor = "executable" },
  { nome = "Testes (Swift Testing)", valor = "test" },
}

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "SwiftPM",
  })
end

-- ========================================
-- LOCALIZAR O PROJETO
-- ========================================

local function localizar_projeto(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    return nil, "Swift: nenhum arquivo selecionado."
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    return nil, "Swift: arquivo inexistente."
  end

  local manifestos = vim.fs.find("Package.swift", {
    path = vim.fs.dirname(arquivo),
    upward = true,
  })

  if #manifestos == 0 then
    return nil, "Swift: Package.swift nao encontrado."
  end

  local manifesto = uv.fs_realpath(manifestos[1]) or manifestos[1]

  if vim.fn.filereadable(manifesto) ~= 1 then
    return nil, "Swift: manifesto invalido."
  end

  return {
    raiz = vim.fs.dirname(manifesto),
    manifesto = manifesto,
  }
end

-- ========================================
-- PROTEGER O MANIFESTO
-- ========================================

local function manifesto_disponivel(contexto)
  local buffer = vim.fn.bufnr(contexto.manifesto)

  if buffer ~= -1 and vim.bo[buffer].modified then
    return false, "Swift: salve o Package.swift antes de continuar."
  end

  local estado = uv.fs_lstat(contexto.manifesto)

  if not estado or estado.type ~= "file" then
    return false, "Swift: manifesto inexistente ou invalido."
  end

  return true
end

local function ler_manifesto(contexto)
  local sucesso, linhas = pcall(vim.fn.readfile, contexto.manifesto, "b")

  if not sucesso or type(linhas) ~= "table" then
    return nil
  end

  return table.concat(linhas, "\n")
end

-- ========================================
-- BACKUP
-- ========================================

local function criar_backup(contexto)
  local pasta = vim.fn.expand("~/Backups")

  if vim.fn.isdirectory(pasta) ~= 1 then
    return nil, "Swift: pasta de backups inexistente."
  end

  local modelo = vim.fs.joinpath(pasta, "Package.swift.pre-target.XXXXXXXX")

  local backup = vim.trim(vim.fn.system({ "mktemp", modelo }))

  if vim.v.shell_error ~= 0 or backup == "" then
    return nil, "Swift: falha ao reservar arquivo de backup."
  end

  vim.fn.system({
    "cp",
    "-p",
    "--",
    contexto.manifesto,
    backup,
  })

  if vim.v.shell_error ~= 0 then
    vim.fn.delete(backup)
    return nil, "Swift: falha ao copiar o manifesto."
  end

  vim.fn.system({
    "cmp",
    "-s",
    "--",
    contexto.manifesto,
    backup,
  })

  if vim.v.shell_error ~= 0 then
    vim.fn.delete(backup)
    return nil, "Swift: backup diferente do manifesto original."
  end

  return backup
end

-- ========================================
-- SINCRONIZAR BUFFER ABERTO
-- ========================================

local function sincronizar_manifesto(contexto)
  local buffer = vim.fn.bufnr(contexto.manifesto)

  if buffer == -1 or not vim.api.nvim_buf_is_loaded(buffer) then
    return true
  end

  -- Nunca descartar edicoes feitas durante
  -- a execucao assincrona do SwiftPM.
  if vim.bo[buffer].modified then
    return false,
      "Package.swift possui alteracoes nao salvas. " .. "O buffer nao foi recarregado; revise o arquivo no disco."
  end

  local sucesso, erro = pcall(function()
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd("silent edit!")
    end)
  end)

  if not sucesso then
    return false, "Falha ao recarregar Package.swift: " .. tostring(erro)
  end

  return true
end

-- ========================================
-- CONSULTAR METADADOS REAIS
-- ========================================

local function consultar_targets(contexto, callback)
  local swift = vim.fn.exepath("swift")

  if swift == "" then
    callback(nil, "Swift: executavel swift nao encontrado.")
    return
  end

  vim.system({
    swift,
    "package",
    "describe",
    "--type",
    "json",
  }, {
    cwd = contexto.raiz,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        callback(nil, "SwiftPM: falha ao consultar os targets.")
        return
      end

      local sucesso, dados = pcall(vim.json.decode, resultado.stdout or "")

      if not sucesso or type(dados) ~= "table" or type(dados.targets) ~= "table" then
        callback(nil, "SwiftPM: metadados invalidos.")
        return
      end

      callback(dados.targets, nil)
    end)
  end)
end

local function target_existe(targets, nome)
  for _, target in ipairs(targets) do
    if target.name == nome then
      return true
    end
  end

  return false
end

-- ========================================
-- CRIAR TARGET
-- ========================================

function M.criar_target(arquivo)
  -- Preservar a janela e o buffer de origem.
  local janela_origem = vim.api.nvim_get_current_win()
  local buffer_origem = vim.api.nvim_get_current_buf()
  local contexto, erro = localizar_projeto(arquivo)

  if not contexto then
    avisar(erro, vim.log.levels.ERROR)
    return false
  end

  local permitido, mensagem = manifesto_disponivel(contexto)

  if not permitido then
    avisar(mensagem, vim.log.levels.ERROR)
    return false
  end

  local conteudo_inicial = ler_manifesto(contexto)

  if conteudo_inicial == nil then
    avisar("Swift: nao foi possivel ler Package.swift.", vim.log.levels.ERROR)
    return false
  end

  local token, erro_lock = package_lock.adquirir(contexto.raiz)

  if not token then
    avisar(erro_lock or "SwiftPM: operacao em andamento.", vim.log.levels.WARN)
    return false
  end

  local function liberar()
    package_lock.liberar(contexto.raiz, token)
  end

  local function interromper(motivo, nivel)
    liberar()
    avisar(motivo, nivel or vim.log.levels.ERROR)
  end

  consultar_targets(contexto, function(targets, erro_consulta)
    if not targets then
      interromper(erro_consulta)
      return
    end

    vim.ui.select(tipos, {
      prompt = "SwiftPM - Tipo do novo target:",
      format_item = function(item)
        return item.nome
      end,
    }, function(escolha)
      if not escolha then
        liberar()
        return
      end

      vim.ui.input({
        prompt = "Nome do novo target Swift: ",
      }, function(nome)
        if nome == nil then
          liberar()
          return
        end

        nome = vim.trim(nome)

        local tipos_swift = require("languages.swift.types")

        if not tipos_swift.identificador_valido(nome) then
          interromper("Swift: identificador invalido.")
          return
        end

        if target_existe(targets, nome) then
          interromper("Swift: target ja existe: " .. nome, vim.log.levels.WARN)
          return
        end

        local pasta_base = escolha.valor == "test" and "Tests" or "Sources"

        local destino = vim.fs.joinpath(contexto.raiz, pasta_base, nome)

        if uv.fs_lstat(destino) then
          interromper("Swift: diretorio ja existe: " .. destino, vim.log.levels.WARN)
          return
        end

        local liberado, erro_manifesto = manifesto_disponivel(contexto)

        if not liberado then
          interromper(erro_manifesto)
          return
        end

        -- Evita utilizar metadados antigos caso
        -- o manifesto tenha mudado durante o menu.
        local conteudo_atual = ler_manifesto(contexto)

        if conteudo_atual == nil or conteudo_atual ~= conteudo_inicial then
          interromper("Swift: Package.swift mudou durante a operacao. " .. "Nenhuma alteracao foi iniciada.")
          return
        end

        local backup, erro_backup = criar_backup(contexto)

        if not backup then
          interromper(erro_backup)
          return
        end

        local swift = vim.fn.exepath("swift")

        if swift == "" then
          interromper("Swift: executavel swift nao encontrado.")
          return
        end

        local comando = {
          swift,
          "package",
          "add-target",
          nome,
          "--type",
          escolha.valor,
        }

        if escolha.valor == "test" then
          vim.list_extend(comando, {
            "--testing-library",
            "swift-testing",
          })
        end

        avisar("SwiftPM: criando target " .. nome .. "...")

        vim.system(comando, {
          cwd = contexto.raiz,
          text = true,
        }, function(resultado)
          vim.schedule(function()
            local sincronizado, aviso_buffer = sincronizar_manifesto(contexto)

            local aviso_extra = ""

            if not sincronizado then
              aviso_extra = "\n" .. aviso_buffer
            end

            if resultado.code ~= 0 then
              interromper(
                "Falha ao criar target: "
                  .. nome
                  .. "\nBackup: "
                  .. backup
                  .. "\n"
                  .. (resultado.stderr or "")
                  .. "\nVerifique possiveis alteracoes parciais."
                  .. aviso_extra
              )
              return
            end

            -- Confirmacao posterior pelos metadados
            -- oficiais do SwiftPM.
            consultar_targets(contexto, function(novos_targets, erro_final)
              if not novos_targets then
                interromper(
                  "SwiftPM executou, mas nao foi possivel confirmar o target."
                    .. "\n"
                    .. erro_final
                    .. "\nBackup: "
                    .. backup
                    .. aviso_extra
                )
                return
              end

              local estado_destino = uv.fs_lstat(destino)

              if not target_existe(novos_targets, nome) or not estado_destino or estado_destino.type ~= "directory" then
                interromper(
                  "SwiftPM terminou, mas a criacao nao foi "
                    .. "confirmada integralmente."
                    .. "\nBackup: "
                    .. backup
                    .. aviso_extra
                )
                return
              end

              liberar()

              -- Localizar o arquivo inicial gerado pelo SwiftPM.
              local arquivo_gerado = vim.fs.joinpath(destino, nome .. ".swift")

              if vim.fn.filereadable(arquivo_gerado) ~= 1 then
                local arquivos = vim.fn.globpath(destino, "*.swift", false, true)
                table.sort(arquivos)
                arquivo_gerado = arquivos[1]
              end

              local mensagem_abertura = ""
              local nivel = sincronizado and vim.log.levels.INFO or vim.log.levels.WARN

              if not arquivo_gerado or vim.fn.filereadable(arquivo_gerado) ~= 1 then
                mensagem_abertura = "\nArquivo Swift inicial nao encontrado."
                nivel = vim.log.levels.WARN

              elseif not vim.api.nvim_win_is_valid(janela_origem)
                or vim.api.nvim_win_get_buf(janela_origem) ~= buffer_origem
                or vim.bo[buffer_origem].modified
              then
                mensagem_abertura = "\nAbertura automatica ignorada: janela ou buffer alterado."
                nivel = vim.log.levels.WARN

              else
                local abriu, erro_abertura = pcall(function()
                  vim.api.nvim_win_call(janela_origem, function()
                    vim.cmd("edit " .. vim.fn.fnameescape(arquivo_gerado))
                  end)
                end)

                if abriu then
                  mensagem_abertura = "\nArquivo aberto: " .. arquivo_gerado
                else
                  mensagem_abertura = "\nFalha ao abrir arquivo: " .. tostring(erro_abertura)
                  nivel = vim.log.levels.WARN
                end
              end

              avisar(
                "Target criado e confirmado: " .. nome
                  .. "\nBackup: " .. backup
                  .. aviso_extra
                  .. mensagem_abertura,
                nivel
              )
            end)
          end)
        end)
      end)
    end)
  end)

  return true
end

return M
