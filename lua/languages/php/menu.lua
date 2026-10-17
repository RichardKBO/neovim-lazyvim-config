-- ========================================
-- PHP - MENU GLOBAL
-- ========================================
-- Execucao, depuracao e gerenciamento Composer.

local M = {}

-- ========================================
-- IDENTIFICAR O PROJETO
-- ========================================

local function encontrar_raiz(arquivo)
  return vim.fs.root(arquivo, {
    "composer.json",
    ".git",
  }) or vim.fs.dirname(arquivo)
end

-- ========================================
-- INFORMACOES DO AMBIENTE
-- ========================================

local function mostrar_informacoes(arquivo)
  local raiz = encontrar_raiz(arquivo)
  local php = vim.fn.exepath("php")
  local composer = vim.fn.exepath("composer")
  local projeto_composer = vim.fs.root(arquivo, {
    "composer.json",
  })

  vim.notify(
    table.concat({
      "Arquivo: " .. arquivo,
      "Projeto: " .. raiz,
      "PHP: " .. (php ~= "" and php or "Nao encontrado"),
      "Composer: " .. (composer ~= "" and composer or "Nao encontrado"),
      "composer.json: " .. (
        projeto_composer
        and vim.fs.joinpath(projeto_composer, "composer.json")
        or "Nao encontrado"
      ),
    }, "\n"),
    vim.log.levels.INFO,
    { title = "PHP - Ambiente atual" }
  )
end

-- ========================================
-- VALIDAR COMPOSER.JSON
-- ========================================

local function validar_composer(arquivo)
  local raiz = vim.fs.root(arquivo, {
    "composer.json",
  })

  if not raiz then
    vim.notify(
      "PHP: nenhum composer.json encontrado neste projeto.",
      vim.log.levels.WARN
    )
    return
  end

  local composer = vim.fn.exepath("composer")

  if composer == "" then
    vim.notify(
      "PHP: Composer nao encontrado no PATH.",
      vim.log.levels.ERROR
    )
    return
  end

  local sucesso, erro = pcall(vim.system, {
    composer,
    "validate",
    "--no-check-publish",
  }, {
    cwd = raiz,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      local saida = vim.trim(
        (resultado.stdout or "") .. "\n" ..
        (resultado.stderr or "")
      )

      local aprovado = resultado.code == 0

      if saida == "" then
        saida = aprovado
          and "composer.json validado com sucesso."
          or "Falha na validacao do composer.json."
      end

      vim.notify(
        saida,
        aprovado and vim.log.levels.INFO or vim.log.levels.ERROR,
        { title = "PHP - Composer validate" }
      )
    end)
  end)

  if not sucesso then
    vim.notify(
      "PHP: falha ao iniciar Composer: " .. tostring(erro),
      vim.log.levels.ERROR
    )
  end
end

-- ========================================
-- MENU INTERATIVO
-- ========================================

function M.abrir()
  local janela = vim.api.nvim_get_current_win()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if vim.bo[buffer].filetype ~= "php" or arquivo == "" then
    vim.notify(
      "PHPMenu: abra um arquivo PHP primeiro.",
      vim.log.levels.WARN
    )
    return
  end

  local opcoes = {
    {
      nome = "Executar arquivo atual (F6)",
      executar = function()
        require("languages.php.runner").executar(arquivo)
      end,
    },
    {
      nome = "Depurar arquivo atual (F8)",
      executar = function()
        if vim.bo[buffer].modified then
          vim.notify(
            "PHP: salve o arquivo antes de depurar.",
            vim.log.levels.WARN
          )
          return
        end

        require("dap").continue()
      end,
    },
    {
      nome = "Informacoes do PHP e projeto",
      executar = function()
        mostrar_informacoes(arquivo)
      end,
    },
    {
      nome = "Validar composer.json",
      executar = function()
        validar_composer(arquivo)
      end,
    },
    {
      nome = "Iniciar servidor HTTP",
      executar = function()
        require("languages.php.server").iniciar(arquivo)
      end,
    },
    {
      nome = "Verificar servidor HTTP",
      executar = function()
        require("languages.php.server").status()
      end,
    },
    {
      nome = "Parar servidor HTTP",
      executar = function()
        require("languages.php.server").parar()
      end,
    },
  }

  vim.ui.select(opcoes, {
    prompt = "PHP - Gerenciamento de projetos",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    vim.schedule(function()
      if not vim.api.nvim_win_is_valid(janela) then
        vim.notify(
          "PHPMenu: janela original indisponivel.",
          vim.log.levels.WARN
        )
        return
      end

      if vim.api.nvim_win_get_buf(janela) ~= buffer then
        vim.notify(
          "PHPMenu: o arquivo original mudou.",
          vim.log.levels.WARN
        )
        return
      end

      vim.api.nvim_set_current_win(janela)
      escolha.executar()
    end)
  end)
end

-- ========================================
-- REGISTRAR :PHPMenu
-- ========================================

function M.setup()
  vim.api.nvim_create_user_command("PHPMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos PHP",
  })
end

return M
