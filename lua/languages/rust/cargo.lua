local M = {}

-- Localizar o Cargo.toml mais proximo do arquivo atual.
-- Funciona em crates independentes e workspaces.
function M.localizar_manifesto(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local diretorio

  if arquivo == "" then
    diretorio = vim.fn.getcwd()
  elseif vim.fn.isdirectory(arquivo) == 1 then
    diretorio = arquivo
  else
    diretorio = vim.fs.dirname(vim.fn.fnamemodify(arquivo, ":p"))
  end

  local manifestos = vim.fs.find("Cargo.toml", {
    upward = true,
    path = diretorio,
  })

  return manifestos[1]
end

-- Consultar os metadados oficiais do Cargo.
function M.metadata(manifesto)
  local cargo = vim.fn.exepath("cargo")

  if cargo == "" then
    return nil, "Cargo nao encontrado no PATH."
  end

  if not manifesto or vim.fn.filereadable(manifesto) ~= 1 then
    return nil, "Cargo.toml nao encontrado."
  end

  local resultado = vim
    .system({
      cargo,
      "metadata",
      "--no-deps",
      "--format-version",
      "1",
      "--manifest-path",
      manifesto,
    }, {
      text = true,
    })
    :wait()

  if resultado.code ~= 0 then
    return nil, "Erro do Cargo:\n" .. (resultado.stderr or resultado.stdout or "")
  end

  local ok, dados = pcall(vim.json.decode, resultado.stdout or "")

  if not ok or type(dados) ~= "table" then
    return nil, "Nao foi possivel interpretar os metadados."
  end

  return dados
end

-- Identificar a crate e o workspace associados ao arquivo.
function M.contexto(arquivo)
  local manifesto = M.localizar_manifesto(arquivo)

  if not manifesto then
    return nil, "Nenhum Cargo.toml encontrado."
  end

  manifesto = vim.fs.normalize(manifesto)

  local dados, erro = M.metadata(manifesto)

  if not dados then
    return nil, erro
  end

  local pacote_atual = nil

  for _, pacote in ipairs(dados.packages or {}) do
    if vim.fs.normalize(pacote.manifest_path) == manifesto then
      pacote_atual = pacote
      break
    end
  end

  local membro_workspace = false

  if pacote_atual then
    for _, identificador in ipairs(dados.workspace_members or {}) do
      if identificador == pacote_atual.id then
        membro_workspace = true
        break
      end
    end
  end

  local raiz_workspace = vim.fs.normalize(dados.workspace_root)

  return {
    manifesto = manifesto,

    diretorio = vim.fs.dirname(manifesto),

    pacote = pacote_atual,

    membro_workspace = membro_workspace,

    workspace_root = raiz_workspace,

    workspace_manifesto = vim.fs.joinpath(raiz_workspace, "Cargo.toml"),

    dados = dados,
  }
end

return M
