-- ========================================
-- SWIFT - DEPENDENCIAS ENTRE TARGETS
-- Gerenciamento pelo SwiftPM
-- ========================================

local M = {}

local uv = vim.uv or vim.loop

-- Bloqueio compartilhado entre os modulos SwiftPM.
local package_lock = require("languages.swift.package_lock")

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "SwiftPM - Dependencias",
  })
end

-- ========================================
-- LOCALIZAR PACOTE
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
-- PROTEGER MANIFESTO
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
-- BACKUP DO MANIFESTO
-- ========================================

local function criar_backup(contexto)
  local pasta = vim.fn.expand("~/Backups")

  if vim.fn.isdirectory(pasta) ~= 1 then
    return nil, "Swift: pasta de backups inexistente."
  end

  local modelo = vim.fs.joinpath(pasta, "Package.swift.pre-dependency.XXXXXXXX")

  local backup = vim.trim(vim.fn.system({ "mktemp", modelo }))

  if vim.v.shell_error ~= 0 or backup == "" then
    return nil, "Swift: falha ao criar arquivo de backup."
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
    return nil, "Swift: backup diferente do original."
  end

  return backup
end

-- ========================================
-- SINCRONIZAR BUFFER
-- ========================================

local function sincronizar_manifesto(contexto)
  local buffer = vim.fn.bufnr(contexto.manifesto)

  if buffer == -1 or not vim.api.nvim_buf_is_loaded(buffer) then
    return true
  end

  if vim.bo[buffer].modified then
    return false,
      "Package.swift possui edicoes nao salvas. " .. "O buffer nao foi recarregado; revise o arquivo no disco."
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
-- CONSULTAR TARGETS SWIFTPM
-- ========================================

local function consultar_targets(contexto, callback)
  local swift = vim.fn.exepath("swift")

  if swift == "" then
    callback(nil, "Swift: executavel nao encontrado.")
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
        callback(nil, "SwiftPM: falha ao consultar targets.")
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

-- ========================================
-- VALIDAR REFERENCIAS
-- ========================================

local function possui_dependencia(target, nome)
  for _, dependencia in ipairs(target.target_dependencies or {}) do
    if dependencia == nome then
      return true
    end
  end

  return false
end

local function mapa_targets(targets)
  local mapa = {}

  for _, target in ipairs(targets) do
    mapa[target.name] = target
  end

  return mapa
end

-- Detecta um caminho transitivo no grafo.
-- Uma nova aresta A -> B causaria ciclo
-- quando B ja alcanca A.
local function alcanca(mapa, atual, destino, visitados)
  if atual == destino then
    return true
  end

  if visitados[atual] then
    return false
  end

  visitados[atual] = true

  local target = mapa[atual]

  if not target then
    return false
  end

  for _, dependencia in ipairs(target.target_dependencies or {}) do
    if type(dependencia) == "string" and alcanca(mapa, dependencia, destino, visitados) then
      return true
    end
  end

  return false
end

local function validar_referencia(targets, destino, dependencia)
  local mapa = mapa_targets(targets)
  local consumidor = mapa[destino]
  local modulo = mapa[dependencia]

  if not consumidor or not modulo then
    return false, "Swift: um dos targets nao existe mais."
  end

  if destino == dependencia then
    return false, "Swift: um target nao pode depender de si mesmo."
  end

  if modulo.type == "test" then
    return false, "Swift: target de testes nao pode ser usado como biblioteca."
  end

  if possui_dependencia(consumidor, dependencia) then
    return false, "Swift: essa dependencia ja esta registrada."
  end

  if alcanca(mapa, dependencia, destino, {}) then
    return false, "Swift: referencia criaria uma dependencia circular."
  end

  return true
end

-- ========================================
-- ADICIONAR REFERENCIA
-- ========================================

function M.adicionar_referencia(arquivo)
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
    avisar("Swift: falha ao ler Package.swift.", vim.log.levels.ERROR)
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

    if #targets < 2 then
      interromper("Swift: sao necessarios pelo menos dois targets.", vim.log.levels.WARN)
      return
    end

    vim.ui.select(targets, {
      prompt = "Target que RECEBERA a dependencia:",
      format_item = function(item)
        return item.name .. " (" .. tostring(item.type) .. ")"
      end,
    }, function(consumidor)
      if not consumidor then
        liberar()
        return
      end

      local candidatos = {}

      for _, target in ipairs(targets) do
        if target.name ~= consumidor.name and target.type ~= "test" then
          table.insert(candidatos, target)
        end
      end

      if #candidatos == 0 then
        interromper("Swift: nenhuma dependencia local disponivel.", vim.log.levels.WARN)
        return
      end

      vim.ui.select(candidatos, {
        prompt = "Target que sera REFERENCIADO:",
        format_item = function(item)
          return item.name .. " (" .. tostring(item.type) .. ")"
        end,
      }, function(modulo)
        if not modulo then
          liberar()
          return
        end

        local valido, motivo = validar_referencia(targets, consumidor.name, modulo.name)

        if not valido then
          interromper(motivo, vim.log.levels.WARN)
          return
        end

        local liberado, erro_manifesto = manifesto_disponivel(contexto)

        if not liberado then
          interromper(erro_manifesto)
          return
        end

        local conteudo_atual = ler_manifesto(contexto)

        if conteudo_atual == nil or conteudo_atual ~= conteudo_inicial then
          interromper("Swift: Package.swift mudou durante a operacao. " .. "Nenhuma referencia foi adicionada.")
          return
        end

        local backup, erro_backup = criar_backup(contexto)

        if not backup then
          interromper(erro_backup)
          return
        end

        local swift = vim.fn.exepath("swift")

        if swift == "" then
          interromper("Swift: executavel nao encontrado.")
          return
        end

        avisar("SwiftPM: adicionando " .. modulo.name .. " -> " .. consumidor.name)

        vim.system({
          swift,
          "package",
          "add-target-dependency",
          modulo.name,
          consumidor.name,
        }, {
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
                "SwiftPM: falha ao adicionar referencia."
                  .. "\nBackup: "
                  .. backup
                  .. "\n"
                  .. (resultado.stderr or "")
                  .. "\nVerifique possiveis alteracoes parciais."
                  .. aviso_extra
              )
              return
            end

            consultar_targets(contexto, function(novos_targets, erro_final)
              if not novos_targets then
                interromper(
                  "SwiftPM executou, mas a referencia nao foi confirmada."
                    .. "\n"
                    .. erro_final
                    .. "\nBackup: "
                    .. backup
                    .. aviso_extra
                )
                return
              end

              local atual = mapa_targets(novos_targets)[consumidor.name]

              if not atual or not possui_dependencia(atual, modulo.name) then
                interromper(
                  "SwiftPM terminou, mas a referencia nao aparece "
                    .. "nos metadados."
                    .. "\nBackup: "
                    .. backup
                    .. aviso_extra
                )
                return
              end

              liberar()

              avisar(
                "Referencia confirmada: "
                  .. consumidor.name
                  .. " -> "
                  .. modulo.name
                  .. "\nBackup: "
                  .. backup
                  .. aviso_extra,
                sincronizado and vim.log.levels.INFO or vim.log.levels.WARN
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
