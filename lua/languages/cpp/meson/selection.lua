local M = {}

-- ========================================
-- MESON - ASSOCIACAO DE ARQUIVOS A TARGETS
-- ========================================
-- Identifica targets que compilam uma fonte
-- e executaveis que vinculam suas bibliotecas.
-- Nao modifica arquivos nem compila projetos.
-- ========================================

local function normalizar(caminho)
  if type(caminho) ~= "string" or caminho == "" then
    return nil
  end

  local absoluto = vim.fn.fnamemodify(caminho, ":p")

  return vim.fs.normalize(vim.uv.fs_realpath(absoluto) or absoluto)
end

local function pertence_ao_alvo(alvo, arquivo)
  for _, bloco in ipairs(alvo.target_sources or {}) do
    for _, fonte in ipairs(bloco.sources or {}) do
      if normalizar(fonte) == arquivo then
        return true
      end
    end

    for _, fonte in ipairs(bloco.generated_sources or {}) do
      if normalizar(fonte) == arquivo then
        return true
      end
    end
  end

  return false
end

local function eh_executavel(alvo)
  return alvo.type == "executable"
end

local function eh_biblioteca(alvo)
  return alvo.type == "static library" or alvo.type == "shared library"
end

-- Contar nomes de artefatos para evitar
-- associacoes ambiguas por nome de arquivo.
local function contar_artefatos(alvos)
  local contagens = {}

  for _, alvo in ipairs(alvos) do
    if eh_biblioteca(alvo) then
      for _, caminho in ipairs(alvo.filename or {}) do
        local nome = vim.fs.basename(caminho)

        contagens[nome] = (contagens[nome] or 0) + 1
      end
    end
  end

  return contagens
end

-- Verificar vinculo direto com uma biblioteca
-- a partir dos parametros do linker fornecidos
-- pela introspeccao do Meson.
local function vincula_biblioteca(executavel, biblioteca, contagens)
  for _, bloco in ipairs(executavel.target_sources or {}) do
    if type(bloco.linker) == "table" and type(bloco.parameters) == "table" then
      for _, parametro in ipairs(bloco.parameters) do
        for _, artefato in ipairs(biblioteca.filename or {}) do
          local nome = vim.fs.basename(artefato)

          if parametro == artefato then
            return true
          end

          if contagens[nome] == 1 and (parametro == nome or parametro == "./" .. nome) then
            return true
          end
        end
      end
    end
  end

  return false
end

-- ========================================
-- API PUBLICA
-- ========================================

-- Retornar todos os targets que compilam
-- diretamente o arquivo informado.
function M.por_fonte(alvos, caminho)
  if type(alvos) ~= "table" then
    return nil, "Lista de targets invalida."
  end

  local arquivo = normalizar(caminho)

  if not arquivo then
    return nil, "Caminho do arquivo invalido."
  end

  local encontrados = {}

  for _, alvo in ipairs(alvos) do
    if pertence_ao_alvo(alvo, arquivo) then
      table.insert(encontrados, alvo)
    end
  end

  return encontrados, nil
end

-- Retornar executaveis relacionados a fonte,
-- diretamente ou por bibliotecas vinculadas.
function M.executaveis_por_fonte(alvos, caminho)
  local diretos, erro = M.por_fonte(alvos, caminho)

  if not diretos then
    return nil, erro
  end

  local executaveis = {}
  local bibliotecas = {}
  local vistos = {}

  local function adicionar(alvo)
    local chave = alvo.id or alvo.name

    if chave and not vistos[chave] then
      vistos[chave] = true
      table.insert(executaveis, alvo)
    end
  end

  for _, alvo in ipairs(diretos) do
    if eh_executavel(alvo) then
      adicionar(alvo)
    elseif eh_biblioteca(alvo) then
      table.insert(bibliotecas, alvo)
    end
  end

  if #bibliotecas == 0 then
    return executaveis, nil
  end

  local contagens = contar_artefatos(alvos)

  for _, alvo in ipairs(alvos) do
    if eh_executavel(alvo) then
      for _, biblioteca in ipairs(bibliotecas) do
        if vincula_biblioteca(alvo, biblioteca, contagens) then
          adicionar(alvo)
          break
        end
      end
    end
  end

  return executaveis, nil
end

return M
