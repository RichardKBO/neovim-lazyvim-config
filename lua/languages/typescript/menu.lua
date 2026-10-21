-- ========================================
-- TYPESCRIPT - MENU DE PROJETOS
-- ========================================

local M = {}

local function avisar(mensagem, nivel)
  vim.notify(mensagem, nivel or vim.log.levels.INFO, {
    title = "TypeScriptMenu",
  })
end

local function executar_comando(comando, raiz, ao_concluir)
  vim.system(comando, {
    cwd = raiz,
    text = true,
  }, function(resultado)
    vim.schedule(function()
      if resultado.code ~= 0 then
        local detalhes = vim.trim(resultado.stderr or "")

        if detalhes == "" then
          detalhes = vim.trim(resultado.stdout or "")
        end

        avisar("Falha no comando: " .. table.concat(comando, " ") .. "\n" .. detalhes, vim.log.levels.ERROR)
        return
      end

      ao_concluir()
    end)
  end)
end

local function criar_projeto()
  local npm = vim.fn.exepath("npm")

  if npm == "" then
    avisar("npm não encontrado no PATH.", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = "Nome do projeto TypeScript: ",
  }, function(nome)
    if not nome then
      return
    end

    nome = vim.trim(nome)

    if not nome:match("^[%w_-]+$") then
      avisar("Use apenas letras, números, _ e - no nome.", vim.log.levels.WARN)
      return
    end

    local base = vim.fs.joinpath(vim.fn.expand("~"), "Projetos", "TypeScript")

    local raiz = vim.fs.joinpath(base, nome)

    if vim.uv.fs_stat(raiz) then
      avisar("O projeto já existe: " .. raiz, vim.log.levels.WARN)
      return
    end

    vim.fn.mkdir(base, "p")

    if vim.fn.mkdir(raiz) == 0 then
      avisar("Não foi possível criar: " .. raiz, vim.log.levels.ERROR)
      return
    end

    avisar("Criando projeto: " .. nome)

    executar_comando({ npm, "init", "-y" }, raiz, function()
      avisar("Configurando ES Modules...")

      executar_comando(
        {
          npm,
          "pkg",
          "set",
          "type=module",
        },
        raiz,
        function()
          avisar("Instalando TypeScript e TSX...")

          executar_comando(
            {
              npm,
              "install",
              "--save-dev",
              "typescript",
              "tsx",
            },
            raiz,
            function()
              local tsc = vim.fs.joinpath(raiz, "node_modules", ".bin", "tsc")

              avisar("Gerando tsconfig.json...")

              executar_comando({ tsc, "--init" }, raiz, function()
                local sucesso, erro = pcall(function()
                  local src = vim.fs.joinpath(raiz, "src")
                  local main = vim.fs.joinpath(src, "main.ts")

                  vim.fn.mkdir(src, "p")

                  vim.fn.writefile({
                    'const projeto: string = "' .. nome .. '";',
                    "",
                    "console.log(`Projeto: ${projeto}`);",
                  }, main)

                  vim.cmd("edit " .. vim.fn.fnameescape(main))
                end)

                if not sucesso then
                  avisar("Projeto parcialmente criado: " .. tostring(erro), vim.log.levels.ERROR)
                  return
                end

                avisar("Projeto criado com sucesso!\n" .. raiz)
              end)
            end
          )
        end
      )
    end)
  end)
end

function M.abrir()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  local opcoes = {
    {
      nome = "Criar novo projeto TypeScript",
      executar = criar_projeto,
    },
    {
      nome = "Executar arquivo .ts atual (F6)",
      executar = function()
        if not vim.api.nvim_buf_is_valid(buffer) or vim.api.nvim_get_current_buf() ~= buffer then
          avisar("O buffer original mudou.", vim.log.levels.WARN)
          return
        end

        if vim.fn.fnamemodify(arquivo, ":e"):lower() ~= "ts" then
          avisar("Abra um arquivo .ts primeiro.", vim.log.levels.WARN)
          return
        end

        require("languages.typescript.runner").executar(arquivo)
      end,
    },
  }

  vim.ui.select(opcoes, {
    prompt = "TypeScript - Gerenciamento de projetos",
    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if escolha then
      vim.schedule(escolha.executar)
    end
  end)
end

function M.setup()
  vim.api.nvim_create_user_command("TypeScriptMenu", function()
    M.abrir()
  end, {
    desc = "Abrir gerenciamento de projetos TypeScript",
  })
end

return M
