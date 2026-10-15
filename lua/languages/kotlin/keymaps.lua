local M = {}

-- Identificar arquivos do contexto Kotlin.
function M.eh_contexto_kotlin(buffer)
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    return false
  end

  local tipo = vim.bo[buffer].filetype

  return tipo == "kotlin" or tipo == "kotlin_script"
end

-- Linhas utilizadas pela central :Atalhos.
function M.linhas_ajuda()
  return {
    "[KOTLIN / GRADLE]",
    "  Espaco + k m  Abrir KotlinMenu",
    "  :KotlinMenu    Gerenciar projetos Kotlin",
    "  F5             Adicionar/remover breakpoint",
    "  F6             Executar arquivo Kotlin atual",
    "  F8             Depurar main atual / continuar",
    "",
  }
end

-- Iniciar ou continuar a depuracao Kotlin.
local function depurar_kotlin()
  local ok, dap = pcall(require, "dap")

  if not ok then
    vim.notify("Kotlin: nvim-dap nao esta disponivel.", vim.log.levels.ERROR)
    return
  end

  -- Se ja existe uma sessao de depuracao,
  -- continuar a execucao normalmente.
  if dap.session() then
    dap.continue()
    return
  end

  -- O kotlin.nvim oferece o comando
  -- KotlinDebugMain para depurar a funcao
  -- main do arquivo Kotlin atual.
  if vim.fn.exists(":KotlinDebugMain") ~= 2 then
    vim.notify("Kotlin: comando KotlinDebugMain indisponivel.", vim.log.levels.ERROR)
    return
  end

  -- Iniciar o debugger sem solicitar
  -- manualmente o nome da classe principal.
  local iniciou, erro = pcall(vim.cmd, "KotlinDebugMain")

  if not iniciou then
    vim.notify("Kotlin: falha ao iniciar debugger: " .. tostring(erro), vim.log.levels.ERROR)
  end
end

-- Criar atalhos exclusivos de buffers Kotlin.
local function aplicar(buffer)
  if not M.eh_contexto_kotlin(buffer) then
    return
  end

  -- Abrir o menu Kotlin.
  vim.keymap.set("n", "<leader>km", function()
    require("languages.kotlin.menu").abrir()
  end, {
    buffer = buffer,
    silent = true,
    desc = "Kotlin: abrir menu",
  })

  -- F8 local ao buffer Kotlin.
  -- Os outros tipos de arquivo continuam
  -- utilizando o F8 global do Neovim.
  vim.keymap.set("n", "<F8>", depurar_kotlin, {
    buffer = buffer,
    silent = true,
    desc = "Kotlin: depurar main atual / continuar",
  })
end

function M.setup()
  local grupo = vim.api.nvim_create_augroup("KotlinMenuKeymaps", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = grupo,
    pattern = {
      "kotlin",
      "kotlin_script",
    },

    callback = function(evento)
      aplicar(evento.buf)
    end,
  })

  -- Aplicar atalhos aos buffers Kotlin
  -- que ja estejam carregados.
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buffer) and M.eh_contexto_kotlin(buffer) then
      aplicar(buffer)
    end
  end
end

return M
