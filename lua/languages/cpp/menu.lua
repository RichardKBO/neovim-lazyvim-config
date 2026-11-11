local M = {}

-- ========================================
-- C++ - MENU CONTEXTUAL
-- ========================================
-- Interface unica para projetos Meson,
-- CMake e arquivos independentes.
--
-- Reutiliza o detector compartilhado,
-- o runner e o debugger existentes.
-- ========================================

local contexto = require("languages.cpp.context")
local projetos = require("languages.cpp.projects")
local tipos = require("languages.cpp.types")
local runner = require("languages.cpp.runner")
local debugger = require("languages.cpp.debugger")

-- ========================================
-- IDENTIFICAR ARQUIVOS C/C++
-- ========================================

local function eh_codigo_cpp(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    return false
  end

  local extensao = vim.fn.fnamemodify(arquivo, ":e"):lower()

  local extensoes = {
    c = true,
    cc = true,
    cpp = true,
    cxx = true,
  }

  return extensoes[extensao] == true
end

-- ========================================
-- ADICIONAR OPCAO AO MENU
-- ========================================

local function adicionar(opcoes, nome, executar)
  table.insert(opcoes, {
    nome = nome,
    executar = executar,
  })
end

-- Somente interface: deteccao, targets e proposta continuam nos modulos Meson.
local function visualizar_dependencias(raiz_sugerida, adicionar_biblioteca)
  local dados = {
    consumidor = { sistema = "meson" },
    origem = { sistema = "meson", alvo = { type = "static library" } },
  }
  local function avisar(mensagem)
    vim.notify("Dependências Meson: " .. tostring(mensagem), vim.log.levels.ERROR)
  end
  local cancelar_pendente
  local function proteger(callback)
    return function(valor)
      local ok, erro = pcall(callback, valor)
      if not ok then
        if cancelar_pendente then pcall(cancelar_pendente) end
        avisar(erro)
      end
    end
  end
  local function diretorio(valor)
    local absoluto = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(valor), ":p"))
    local canonico = vim.uv.fs_realpath(absoluto)
    local info = canonico and vim.uv.fs_stat(canonico)
    if not info or info.type ~= "directory" then error("Diretório inexistente: " .. valor, 0) end
    return canonico
  end
  local function raiz_meson(valor)
    local raiz = diretorio(valor)
    local projeto, erro = contexto.detectar(raiz)
    if not projeto or projeto.sistema ~= "meson" or projeto.raiz ~= raiz then
      error("Selecione a raiz de um projeto Meson: " .. tostring(erro or valor), 0)
    end
    return raiz
  end
  local function selecionar_target(callback)
    -- Leitura apenas para apresentar candidatos; a previa rele e valida os JSONs.
    local function json(nome)
      local caminho = vim.fs.joinpath(dados.diretorio_build, "meson-info", nome)
      local ok, valor = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(caminho), "\n"))
      end)
      if not ok or type(valor) ~= "table" then
        error("Introspecção indisponível ou inválida: " .. caminho .. ". Configure o build antes desta prévia.", 0)
      end
      return valor
    end
    local inventario = { alvos = json("intro-targets.json"), meson_info = json("meson-info.json") }
    if not vim.islist(inventario.alvos) then error("A introspecção de targets deve ser uma lista.", 0) end
    local candidatos = {}
    for _, alvo in ipairs(inventario.alvos) do
      if type(alvo) ~= "table" then error("Target inválido na introspecção.", 0) end
      if alvo.type == "executable" and alvo.subproject == vim.NIL then
        local destino, erro = require("languages.cpp.meson.dependency_targets").validar({
          consumidor = dados.consumidor, diretorio_build = dados.diretorio_build,
          destino = { id = alvo.id, name = alvo.name },
        }, inventario)
        if not destino then error(erro, 0) end
        candidatos[#candidatos + 1] = destino
      end
    end
    if #candidatos == 0 then error("Nenhum executável principal válido no build selecionado.", 0) end
    vim.ui.select(candidatos, {
      prompt = "Target consumidor Meson — PRÉVIA:",
      format_item = function(item) return item.name .. " [" .. item.id .. "]" end,
    }, proteger(function(escolha)
      if escolha then dados.destino = escolha; callback() end
    end))
  end
  local function exibir()
    local previa, erro = require("languages.cpp.meson.dependency_preview").previsualizar(dados)
    if not previa then avisar("Prévia recusada: " .. tostring(erro)); return end
    if previa.autorizada_para_aplicacao ~= false then error("Prévia fora do contrato read-only.", 0) end
    local aplicador, ensaio, condicoes
    if adicionar_biblioteca then
      aplicador = require("languages.cpp.meson.dependency_apply")
      ensaio, erro = aplicador.preparar_ensaio(dados)
      if not ensaio then avisar(erro.mensagem); return end
      if ensaio.estado == "alterar" then
        condicoes, erro = aplicador.verificar_selecionada(ensaio)
        if not condicoes then avisar(erro.mensagem); return end
      end
    end
    local linhas = {
      "PRÉVIA — nenhuma alteração será aplicada", "",
      "Consumidor: " .. previa.consumidor.raiz,
      "Biblioteca: " .. previa.origem.raiz,
      "Target da biblioteca: " .. previa.origem.alvo.name,
      "Target consumidor: " .. previa.destino.name .. " [" .. previa.destino.id .. "]",
      "Exportação: " .. previa.exportacao,
      "Alias: " .. previa.alias,
      "Variáveis: " .. previa.variavel_subprojeto .. " / " .. previa.variavel_dependencia,
      "Estado: " .. previa.estado,
      previa.estado == "sem_alteracao" and "Dependência já integrada." or "Integração somente proposta.",
      "", "Link do subprojeto (" .. previa.link.acao .. "):",
      previa.link.caminho .. " -> " .. previa.link.destino_literal,
      "", "Diff proposto para " .. previa.precondicoes.consumidor.caminho .. ":",
    }
    if previa.estado == "alterar" then
      local alteracao = previa.alteracoes[1]
      local diff = vim.diff(alteracao.conteudo_anterior, alteracao.conteudo_posterior, {
        result_type = "unified", ctxlen = 3,
      })
      vim.list_extend(linhas, vim.split(diff, "\n", { plain = true }))
    else
      linhas[#linhas + 1] = "(sem alterações)"
    end
    if adicionar_biblioteca then
      linhas[1] = "REVISÃO — aplicação somente após confirmação específica"
      if condicoes then
        vim.list_extend(linhas, { "", "Objetos afetados (diretório criado somente se ausente):" })
        vim.list_extend(linhas, condicoes.arquivos_afetados)
        vim.list_extend(linhas, { "Backup exclusivo: " .. condicoes.backup, "Temporários exclusivos:" })
        vim.list_extend(linhas, condicoes.temporarios)
        vim.list_extend(linhas, { "", "Riscos: " .. condicoes.riscos })
      end
      if not aplicador.aplicacao_selecionada_disponivel() then
        linhas[#linhas + 1] = "APLICAÇÃO REAL BLOQUEADA — Passo 403; nenhum ticket será gerado."
      end
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].swapfile = false
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, linhas)
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    local win = vim.api.nvim_open_win(buf, true, {
      split = "below", height = math.max(1, math.min(22, vim.o.lines - 4)),
    })
    local ativo, pedido = true, nil
    cancelar_pendente = function()
      ativo = false
      if pedido then aplicador.cancelar_autorizacao_selecionada(pedido); pedido = nil end
    end
    vim.keymap.set("n", "q", function()
      cancelar_pendente()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end, { buffer = buf, silent = true, desc = "Fechar prévia Meson" })
    if not adicionar_biblioteca then return end
    vim.api.nvim_create_autocmd("BufWipeout", { buffer = buf, once = true, callback = cancelar_pendente })
    if ensaio.estado == "sem_alteracao" then
      vim.notify("Dependências Meson: já integrada; nenhuma aplicação necessária.", vim.log.levels.INFO)
      return
    end
    if not aplicador.aplicacao_selecionada_disponivel() then
      vim.notify("Dependências Meson: aplicação real bloqueada no Passo 403.", vim.log.levels.WARN)
      return
    end
    -- Relatorio/pedido/ticket permanecem nestes callbacks na mesma instancia.
    vim.ui.select({ "Cancelar", "Confirmar aplicação" }, { prompt = "Revisou o diff, objetos e riscos Meson?" },
      proteger(function(escolha)
        if not ativo or escolha ~= "Confirmar aplicação" then cancelar_pendente(); return end
        pedido, erro = aplicador.solicitar_autorizacao_selecionada(ensaio)
        if not pedido then avisar(erro.mensagem); cancelar_pendente(); return end
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "Confirmação exigida (cinco minutos):", pedido.confirmacao_exigida })
        vim.bo[buf].modifiable = false
        vim.ui.input({ prompt = "Digite a confirmação textual Meson (vazio cancela): " }, proteger(function(frase)
          if not ativo or frase == nil or frase == "" then cancelar_pendente(); return end
          local ticket, falha = aplicador.confirmar_autorizacao_selecionada(pedido, frase)
          if not ticket then avisar(falha.mensagem); cancelar_pendente(); return end
          local resultado, erro_aplicacao = aplicador.aplicar_selecionada(ensaio, ticket)
          local evidencia = resultado or erro_aplicacao
          vim.notify("Dependências Meson: " .. tostring(evidencia.estado) .. ": " .. tostring(evidencia.mensagem)
            .. (evidencia.backup and ("\nBackup: " .. evidencia.backup) or "")
            .. (evidencia.estado == "recuperacao_manual" and "\nPreserve backup, link e temporários; recuperação manual necessária." or ""),
            resultado and vim.log.levels.INFO or vim.log.levels.ERROR)
          cancelar_pendente()
        end))
      end))
  end
  -- Nomes/export/variaveis sao explicitos; nao inferir declaracoes Meson ambiguas.
  local etapas = {
    { prompt = "Projeto consumidor Meson — raiz: ", completion = "dir",
      default = function() return raiz_sugerida or vim.fn.getcwd() end,
      definir = function(v) dados.consumidor.raiz = raiz_meson(v) end },
    { prompt = "Biblioteca Meson independente — raiz: ", completion = "dir",
      default = function() return vim.fs.dirname(dados.consumidor.raiz) .. "/" end,
      definir = function(v) dados.origem.raiz = raiz_meson(v) end },
    { prompt = "Build Meson existente do consumidor: ", completion = "dir",
      default = function() return vim.fs.joinpath(dados.consumidor.raiz, "build") end,
      definir = function(v) dados.diretorio_build = diretorio(v) end },
    { target = true },
    { prompt = "Nome do target estático da biblioteca: ",
      definir = function(v) dados.origem.alvo.name = v end },
    { prompt = "Exportação declare_dependency da biblioteca: ",
      definir = function(v) dados.exportacao = v end },
    { prompt = "Alias do subprojeto: ", default = function() return vim.fs.basename(dados.origem.raiz) end,
      definir = function(v) dados.alias = v end },
    { prompt = "Variável local do subprojeto: ", default = function() return "biblioteca" end,
      definir = function(v) dados.variavel_subprojeto = v end },
    { prompt = "Variável local da dependência: ", default = function() return "produtos_dep" end,
      definir = function(v) dados.variavel_dependencia = v end },
  }
  local function avancar(indice)
    local etapa = etapas[indice]
    if not etapa then exibir(); return end
    if etapa.target then selecionar_target(function() avancar(indice + 1) end); return end
    vim.ui.input({
      prompt = etapa.prompt, completion = etapa.completion,
      default = etapa.default and etapa.default() or nil,
    }, proteger(function(valor)
      if valor == nil then return end
      if type(valor) ~= "string" or vim.trim(valor) == "" or valor:find("%c") then
        avisar("Informe um valor não vazio, sem caracteres de controle."); return
      end
      etapa.definir(vim.trim(valor))
      avancar(indice + 1)
    end))
  end
  avancar(1)
end

-- ========================================
-- ABRIR CPPMENU
-- ========================================

function M.abrir()
  -- Capturar o arquivo antes de abrir
  -- qualquer interface de selecao.
  local arquivo = vim.api.nvim_buf_get_name(0)

  local projeto, erro_contexto = contexto.detectar(arquivo)

  if not projeto then
    vim.notify("C++: falha ao detectar contexto: " .. tostring(erro_contexto), vim.log.levels.ERROR)
    return
  end

  local sistema = projeto.sistema
  local raiz = projeto.raiz

  local eh_projeto = sistema == "meson" or sistema == "cmake"
  local eh_codigo = eh_codigo_cpp(arquivo)

  local opcoes = {}

  -- ========================================
  -- CRIACAO DE PROJETOS
  -- ========================================

  -- Meson e o sistema preferencial
  -- para projetos novos.
  adicionar(opcoes, "Criar novo projeto C++ (Meson)", function()
    projetos.criar("meson")
  end)

  -- Preservar o gerador CMake
  -- durante a migracao.
  adicionar(opcoes, "Criar novo projeto C++ (CMake)", function()
    projetos.criar("cmake")
  end)

  adicionar(opcoes, "Ajuda — Dependências Meson", function()
    require("languages.cpp.meson.help").abrir()
  end)

  adicionar(opcoes, "Dependências Meson — Visualizar integração", function()
    visualizar_dependencias(sistema == "meson" and raiz or nil)
  end)

  adicionar(opcoes, "Dependências Meson — Adicionar biblioteca", function()
    visualizar_dependencias(sistema == "meson" and raiz or nil, true)
  end)

  -- ========================================
  -- PROJETOS MESON E CMAKE
  -- ========================================

  if eh_projeto then
    local nome_sistema = sistema == "meson" and "Meson" or "CMake"

    -- O gerador de classes existente
    -- ainda oferece suporte ao CMake.
    if sistema == "cmake" then
      adicionar(opcoes, "Criar classe C++ (.hpp + .cpp)", function()
        tipos.criar(arquivo)
      end)
    end

    -- Reutilizar o mecanismo do F7.
    adicionar(opcoes, nome_sistema .. " - Configurar projeto (F7)", function()
      runner.configurar(arquivo)
    end)

    -- Presets exclusivos do CMake.
    if
      sistema == "cmake"
      and raiz
      and (
        vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakePresets.json")) == 1
        or vim.fn.filereadable(vim.fs.joinpath(raiz, "CMakeUserPresets.json")) == 1
      )
    then
      adicionar(opcoes, "CMake - Alterar preset", function()
        local presets = require("languages.cpp.presets")

        presets.selecionar(raiz, function(nome)
          if nome then
            runner.configurar(arquivo)
          end
        end)
      end)
    end

    -- ========================================
    -- COMPILACAO E EXECUCAO
    -- ========================================

    if eh_codigo then
      adicionar(opcoes, nome_sistema .. " - Compilar alvo do arquivo atual", function()
        runner.preparar(arquivo, function(executavel)
          vim.notify("C++: alvo compilado: " .. vim.fn.fnamemodify(executavel, ":t"), vim.log.levels.INFO)
        end)
      end)

      adicionar(opcoes, "Executar arquivo atual (F6)", function()
        runner.executar(arquivo)
      end)

      adicionar(opcoes, "Depurar arquivo atual (F8)", function()
        debugger.depurar(arquivo)
      end)
    end
  end

  -- ========================================
  -- ARQUIVO INDEPENDENTE
  -- ========================================

  if sistema == "standalone" and eh_codigo then
    adicionar(opcoes, "Executar arquivo independente (F6)", function()
      runner.executar(arquivo)
    end)
  end

  -- ========================================
  -- EXIBIR MENU
  -- ========================================

  vim.ui.select(opcoes, {
    prompt = "C++ - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    local ok, erro = pcall(escolha.executar)

    if not ok then
      vim.notify("C++: falha na operacao do CPPMenu: " .. tostring(erro), vim.log.levels.ERROR)
    end
  end)
end

-- ========================================
-- REGISTRAR COMANDO
-- ========================================

function M.setup()
  vim.api.nvim_create_user_command("CPPMenu", function()
    M.abrir()
  end, {
    desc = "Abrir menu de gerenciamento C++",
  })

  vim.api.nvim_create_user_command("CPPMesonAjuda", function()
    require("languages.cpp.meson.help").abrir()
  end, {
    desc = "Abrir ajuda dos campos de dependências Meson",
  })
end

return M
