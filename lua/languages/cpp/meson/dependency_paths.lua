local M = {}

local contexto = require("languages.cpp.context")
local uv = vim.uv

local function texto_valido(valor)
  return type(valor) == "string" and valor:find("%S") ~= nil and valor:find("%c") == nil
end

local function identidade(info)
  return { type = info.type, dev = info.dev, ino = info.ino }
end

local function mesmo_objeto(a, b)
  return a.dev ~= nil and a.ino ~= nil and a.dev == b.dev and a.ino == b.ino
end

local function raiz_meson(caminho, rotulo)
  if not texto_valido(caminho) or caminho:sub(1, 1) ~= "/" then
    return nil, "Raiz " .. rotulo .. " deve ser um caminho absoluto valido."
  end

  local canonico, erro = uv.fs_realpath(caminho)
  if not canonico then
    return nil, "Nao foi possivel resolver a raiz " .. rotulo .. ": " .. tostring(erro)
  end
  canonico = vim.fs.normalize(canonico)

  local info, erro_stat = uv.fs_stat(canonico)
  if not info or info.type ~= "directory" or info.dev == nil or info.ino == nil then
    return nil, "Raiz " .. rotulo .. " nao e um diretorio com identidade disponivel: " .. tostring(erro_stat)
  end

  local ok, projeto, erro_contexto = pcall(contexto.detectar, canonico)
  if not ok then
    return nil, "Falha ao detectar o projeto " .. rotulo .. ": " .. tostring(projeto)
  end
  if not projeto or projeto.sistema ~= "meson" or projeto.raiz ~= canonico then
    return nil, "Raiz " .. rotulo .. " nao corresponde a um projeto Meson reconhecido: " .. tostring(erro_contexto)
  end

  return { caminho = canonico, identidade = identidade(info) }, nil
end

-- false significa ausencia observada; nil, erro significa falha de inspecao.
local function examinar(caminho)
  local info, erro, codigo = uv.fs_lstat(caminho)
  if info then
    return info, nil
  end
  if codigo == "ENOENT" then
    return false, nil
  end
  return nil, "Nao foi possivel inspecionar " .. caminho .. ": " .. tostring(erro)
end

local function contem(raiz, caminho)
  local prefixo = raiz == "/" and "/" or raiz .. "/"
  return caminho:sub(1, #prefixo) == prefixo
end

-- dados: { consumidor = { raiz = "/..." }, origem = { raiz = "/..." }, alias = "..." }.
-- Sucesso: snapshot, nil; falha/colisao: nil, mensagem.
-- Snapshot: raizes, identidades, subprojects e link; nao inclui conteudos/targets.
-- Usa o contrato do detector existente, sem validar semanticamente o Meson.
-- Somente leitura: nao cria pastas, links ou builds, nem altera dados.
-- Nao e uma observacao atomica: a futura aplicacao deve revalidar os caminhos.
function M.inspecionar(dados)
  if type(dados) ~= "table" or type(dados.consumidor) ~= "table" or type(dados.origem) ~= "table" then
    return nil, "Informe as raizes do consumidor e da origem."
  end
  if type(dados.alias) ~= "string" or not dados.alias:match("^[A-Za-z0-9_][A-Za-z0-9_.%+%-]*$") then
    return nil, "Alias deve ser um unico componente de diretorio seguro."
  end

  local consumidor, erro_consumidor = raiz_meson(dados.consumidor.raiz, "do consumidor")
  if not consumidor then
    return nil, erro_consumidor
  end
  local origem, erro_origem = raiz_meson(dados.origem.raiz, "da origem")
  if not origem then
    return nil, erro_origem
  end

  if consumidor.caminho == origem.caminho or mesmo_objeto(consumidor.identidade, origem.identidade) then
    return nil, "Auto-referencia: consumidor e origem identificam o mesmo diretorio."
  end
  if contem(consumidor.caminho, origem.caminho) or contem(origem.caminho, consumidor.caminho) then
    return nil, "Raizes aninhadas nao sao suportadas para dependencias independentes."
  end

  local pasta = vim.fs.joinpath(consumidor.caminho, "subprojects")
  local info_pasta, erro_pasta = examinar(pasta)
  if info_pasta == nil then
    return nil, erro_pasta
  end
  if info_pasta and info_pasta.type ~= "directory" then
    return nil, "subprojects/ deve ser diretorio real ou ausente; tipo encontrado: " .. tostring(info_pasta.type)
  end
  if info_pasta then
    local canonico, erro_realpath = uv.fs_realpath(pasta)
    if not canonico or canonico ~= pasta then
      return nil, "Identidade de subprojects/ divergiu durante a inspecao: " .. tostring(erro_realpath)
    end
  end

  local caminho_link = vim.fs.joinpath(pasta, dados.alias)
  local referencia = { caminho = caminho_link, estado = "ausente" }
  if info_pasta then
    local info_link, erro_link = examinar(caminho_link)
    if info_link == nil then
      return nil, erro_link
    end
    if info_link then
      if info_link.type ~= "link" then
        return nil, "Colisao na referencia do subprojeto; tipo encontrado: " .. tostring(info_link.type)
      end

      local literal, erro_literal = uv.fs_readlink(caminho_link)
      if not texto_valido(literal) then
        return nil, "Destino literal do link indisponivel ou invalido: " .. tostring(erro_literal)
      end
      -- Resolver apenas depois de comprovar que a referencia final e um link.
      local canonico, erro_canonico = uv.fs_realpath(caminho_link)
      if not canonico then
        return nil, "Link quebrado ou destino inacessivel: " .. tostring(erro_canonico)
      end
      local info_destino, erro_destino = uv.fs_stat(caminho_link)
      if canonico ~= origem.caminho or not info_destino or info_destino.type ~= "directory"
        or not mesmo_objeto(info_destino, origem.identidade)
      then
        return nil, "Referencia nao aponta para a origem selecionada: " .. tostring(erro_destino)
      end

      referencia = {
        caminho = caminho_link,
        estado = "link",
        destino_literal = literal,
        destino_canonico = canonico,
        identidade = identidade(info_link),
      }
    end
  end

  return {
    raizes = { consumidor = consumidor.caminho, origem = origem.caminho },
    identidades = { consumidor = consumidor.identidade, origem = origem.identidade },
    subprojects = {
      caminho = pasta,
      estado = info_pasta and "diretorio" or "ausente",
      identidade = info_pasta and identidade(info_pasta) or nil,
    },
    link = referencia,
  }, nil
end

return M
