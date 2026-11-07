-- ========================================
-- SWIFT - EXECUTOR DE TESTES SWIFTPM
-- Integracao com Swift Testing e SwiftMenu
-- ========================================

local M = {}

local package_lock = require("languages.swift.package_lock")
local uv = vim.uv or vim.loop

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "Swift Testing",
  })
end

-- ========================================
-- LOCALIZAR PROJETO SWIFTPM
-- ========================================

local function localizar_projeto(arquivo)
  if type(arquivo) ~= "string" or arquivo == "" then
    return nil, "Nenhum arquivo Swift selecionado."
  end

  arquivo = vim.fn.fnamemodify(arquivo, ":p")

  if vim.fn.filereadable(arquivo) ~= 1 then
    return nil, "Arquivo Swift inexistente."
  end

  if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "swift" then
    return nil, "Abra um arquivo .swift primeiro."
  end

  local manifestos = vim.fs.find("Package.swift", {
    path = vim.fs.dirname(arquivo),
    upward = true,
  })

  if #manifestos == 0 then
    return nil, "Package.swift nao encontrado."
  end

  local manifesto = uv.fs_realpath(manifestos[1]) or manifestos[1]

  if vim.fn.filereadable(manifesto) ~= 1 then
    return nil, "Manifesto SwiftPM invalido."
  end

  return vim.fs.dirname(manifesto)
end

-- ========================================
-- PROTEGER ARQUIVOS NAO SALVOS
-- ========================================

local function verificar_buffers(raiz)
  local prefixo = raiz .. "/"

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and vim.bo[buffer].modified then
      local caminho = vim.api.nvim_buf_get_name(buffer)

      if caminho ~= "" then
        caminho = vim.fn.fnamemodify(caminho, ":p")

        if caminho:sub(1, #prefixo) == prefixo then
          return false, "Salve os arquivos modificados antes de executar os testes:\n" .. caminho
        end
      end
    end
  end

  return true
end

-- ========================================
-- TERMINAL EXCLUSIVO DO SWIFT TESTING
-- ========================================

local function preparar_terminal()
  local aba = vim.api.nvim_get_current_tabpage()
  local janela_terminal = nil

  for _, janela in ipairs(vim.api.nvim_tabpage_list_wins(aba)) do
    local buffer = vim.api.nvim_win_get_buf(janela)

    if vim.bo[buffer].buftype == "terminal" and vim.b[buffer].swift_tests_terminal == true then
      janela_terminal = janela
      break
    end
  end

  if janela_terminal then
    vim.api.nvim_set_current_win(janela_terminal)
    vim.cmd("wincmd J")
    vim.cmd("resize 12")
  else
    vim.cmd("botright 12split")
  end

  -- Novo buffer para cada execucao, sem reutilizar
  -- ou interromper o terminal exclusivo do F6.
  vim.cmd("enew")

  local buffer = vim.api.nvim_get_current_buf()

  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false

  return buffer
end

-- ========================================
-- EXECUTAR SWIFT TEST
-- ========================================

function M.executar(arquivo)
  local raiz, erro = localizar_projeto(arquivo)

  if not raiz then
    avisar(erro, vim.log.levels.ERROR)
    return false
  end

  local permitido, mensagem = verificar_buffers(raiz)

  if not permitido then
    avisar(mensagem, vim.log.levels.WARN)
    return false
  end

  local swift = vim.fn.exepath("swift")

  if swift == "" then
    avisar("Swift nao encontrado no PATH.", vim.log.levels.ERROR)
    return false
  end

  local token, erro_lock = package_lock.adquirir(raiz)

  if not token then
    avisar(erro_lock, vim.log.levels.WARN)
    return false
  end

  local sucesso, buffer_ou_erro = pcall(preparar_terminal)

  if not sucesso then
    package_lock.liberar(raiz, token)
    avisar("Falha ao preparar terminal: " .. tostring(buffer_ou_erro), vim.log.levels.ERROR)
    return false
  end

  local buffer = buffer_ou_erro

  local iniciado, job_ou_erro = pcall(function()
    return vim.fn.termopen({
      swift,
      "test",
    }, {
      cwd = raiz,

      on_exit = function(_, codigo)
        vim.schedule(function()
          package_lock.liberar(raiz, token)

          if codigo == 0 then
            avisar("Swift Testing: testes finalizados com sucesso!")
          else
            avisar(
              "Swift Testing: falha nos testes (codigo " .. tostring(codigo) .. "). Consulte o terminal.",
              vim.log.levels.ERROR
            )
          end
        end)
      end,
    })
  end)

  if not iniciado or type(job_ou_erro) ~= "number" or job_ou_erro <= 0 then
    package_lock.liberar(raiz, token)

    avisar("Falha ao iniciar swift test: " .. tostring(job_ou_erro), vim.log.levels.ERROR)

    return false
  end

  vim.b[buffer].swift_tests_terminal = true

  avisar("Executando swift test em:\n" .. raiz)

  return true
end

return M
