local M = {}

-- Menu modular para integracao com GitHub CLI e Snacks.
-- Detecta o repositorio do arquivo atual ou do diretorio corrente.

local opcoes = {
  {
    id = "issues",
    nome = "Consultar Issues",
  },
  {
    id = "prs",
    nome = "Consultar Pull Requests",
  },
  {
    id = "issue_create",
    nome = "Criar Issue no navegador",
  },
}

-- Identifica o diretorio do arquivo aberto.
-- Quando nao existe arquivo, utiliza o cwd.
local function diretorio_atual()
  local buffer = vim.api.nvim_get_current_buf()
  local arquivo = vim.api.nvim_buf_get_name(buffer)

  if arquivo ~= "" and vim.bo[buffer].buftype == "" then
    return vim.fs.dirname(arquivo)
  end

  return vim.uv.cwd()
end

-- Localiza a raiz do repositorio utilizando o proprio Git.
-- Funciona tambem com subpastas e worktrees.
local function localizar_raiz_git(diretorio)
  if not diretorio or vim.fn.isdirectory(diretorio) == 0 then
    return nil
  end

  local resultado = vim.system({
    "git",
    "-C",
    diretorio,
    "rev-parse",
    "--show-toplevel",
  }, { text = true }):wait()

  if resultado.code ~= 0 then
    return nil
  end

  local raiz = (resultado.stdout or ""):gsub("%s+$", "")

  if raiz == "" then
    return nil
  end

  return raiz
end

-- Identifica o repositorio GitHub associado ao projeto.
-- Retorna o formato proprietario/repositorio.
local function localizar_repositorio_github(raiz)
  local resultado = vim.system({
    "gh",
    "repo",
    "view",
    "--json",
    "nameWithOwner",
    "--jq",
    ".nameWithOwner",
  }, {
    cwd = raiz,
    text = true,
  }):wait()

  if resultado.code ~= 0 then
    return nil
  end

  local repositorio = (resultado.stdout or ""):gsub("%s+$", "")

  if repositorio == "" then
    return nil
  end

  return repositorio
end

function M.abrir()
  if vim.fn.executable("gh") ~= 1 then
    vim.notify(
      "GitHub CLI (gh) nao encontrado.",
      vim.log.levels.ERROR
    )
    return
  end

  local ok, snacks = pcall(require, "snacks")

  if not ok or not snacks.picker then
    vim.notify(
      "Snacks Picker nao esta disponivel.",
      vim.log.levels.ERROR
    )
    return
  end

  local raiz = localizar_raiz_git(diretorio_atual())

  if not raiz then
    vim.notify(
      "GitHubMenu: nenhum repositorio Git encontrado.",
      vim.log.levels.WARN
    )
    return
  end

  local repositorio = localizar_repositorio_github(raiz)

  if not repositorio then
    vim.notify(
      "GitHubMenu: nenhum repositorio GitHub identificado para este projeto.",
      vim.log.levels.WARN
    )
    return
  end

  vim.ui.select(opcoes, {
    prompt = "GitHub - " .. repositorio,

    format_item = function(item)
      return item.nome
    end,
  }, function(escolhido)
    if not escolhido then
      return
    end

    local configuracao = {
      repo = repositorio,
      cwd = raiz,
    }

    if escolhido.id == "issues" then
      snacks.picker.gh_issue(configuracao)
    elseif escolhido.id == "prs" then
      snacks.picker.gh_pr(vim.tbl_extend("force", configuracao, {
        state = "all",
      }))
    elseif escolhido.id == "issue_create" then
      local endereco = "https://github.com/" .. repositorio .. "/issues/new"
      local _, erro = vim.ui.open(endereco)

      if erro then
        vim.notify(
          "GitHubMenu: falha ao abrir formulario de Issue: " .. tostring(erro),
          vim.log.levels.ERROR
        )
      end
    end
  end)
end

function M.setup()
  if vim.fn.exists(":GitHubMenu") ~= 2 then
    vim.api.nvim_create_user_command("GitHubMenu", function()
      M.abrir()
    end, {
      desc = "Abrir menu do GitHub",
    })
  end

  vim.keymap.set("n", "<leader>gh", function()
    M.abrir()
  end, {
    desc = "GitHub Menu",
    silent = true,
  })
end

return M
