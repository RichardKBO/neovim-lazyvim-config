local M = {}

local tipos = {
  { nome = "Nova classe", tipo = "class" },
  { nome = "Nova interface", tipo = "interface" },
  { nome = "Novo record", tipo = "record" },
  { nome = "Novo enum", tipo = "enum" },
}

-- Localizar o diretorio de fontes Java do modulo atual.
-- Maven: pom.xml
-- Gradle: build.gradle ou build.gradle.kts
function M.localizar_fontes(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local diretorio = vim.fn.getcwd()

  if arquivo ~= "" then
    diretorio = vim.fs.dirname(arquivo)
  end

  local marcadores = vim.fs.find({
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
  }, {
    path = diretorio,
    upward = true,
  })

  if #marcadores == 0 then
    return nil
  end

  local raiz_modulo = vim.fs.dirname(marcadores[1])

  return vim.fs.joinpath(raiz_modulo, "src", "main", "java")
end

-- Identificar o pacote a partir da pasta do arquivo aberto.
local function pacote_atual(fontes, arquivo)
  if arquivo == "" then
    return ""
  end

  local diretorio = vim.fs.normalize(vim.fs.dirname(arquivo))

  fontes = vim.fs.normalize(fontes)

  if diretorio == fontes then
    return ""
  end

  local prefixo = fontes .. "/"

  if diretorio:sub(1, #prefixo) ~= prefixo then
    return ""
  end

  local relativo = diretorio:sub(#prefixo + 1)
  local pacote = relativo:gsub("/", ".")

  return pacote
end

local function identificador_valido(nome)
  return nome:match("^[%a_][%w_]*$") ~= nil
end

local function pacote_valido(pacote)
  if pacote == "" then
    return false
  end

  local partes = vim.split(pacote, ".", {
    plain = true,
    trimempty = false,
  })

  for _, parte in ipairs(partes) do
    if not identificador_valido(parte) then
      return false
    end
  end

  return true
end

local function gerar_conteudo(tipo, pacote, nome, componentes)
  local linhas = {
    "package " .. pacote .. ";",
    "",
  }

  if tipo == "class" then
    vim.list_extend(linhas, {
      "public class " .. nome .. " {",
      "",
      "}",
    })
  elseif tipo == "interface" then
    vim.list_extend(linhas, {
      "public interface " .. nome .. " {",
      "",
      "}",
    })
  elseif tipo == "record" then
    vim.list_extend(linhas, {
      "public record " .. nome .. "(" .. (componentes or "") .. ") {",
      "",
      "}",
    })
  elseif tipo == "enum" then
    vim.list_extend(linhas, {
      "public enum " .. nome .. " {",
      "    EXEMPLO",
      "}",
    })
  end

  return linhas
end

local function criar_arquivo(fontes, tipo, pacote, nome, componentes)
  if not pacote_valido(pacote) then
    vim.notify("Java: pacote invalido.", vim.log.levels.ERROR)
    return
  end

  if not identificador_valido(nome) then
    vim.notify("Java: nome de tipo invalido.", vim.log.levels.ERROR)
    return
  end

  -- Guardar somente a string retornada por gsub.
  local caminho_pacote = pacote:gsub("%.", "/")

  local pasta = vim.fs.joinpath(fontes, caminho_pacote)

  local arquivo = vim.fs.joinpath(pasta, nome .. ".java")

  if vim.uv.fs_lstat(arquivo) then
    vim.notify("Java: arquivo ja existe: " .. arquivo, vim.log.levels.WARN)
    return
  end

  local ok_diretorio = pcall(vim.fn.mkdir, pasta, "p")

  if not ok_diretorio or vim.fn.isdirectory(pasta) ~= 1 then
    vim.notify("Java: falha ao criar diretorio.", vim.log.levels.ERROR)
    return
  end

  local conteudo = gerar_conteudo(tipo, pacote, nome, componentes)

  local ok, resultado = pcall(vim.fn.writefile, conteudo, arquivo)

  if not ok or resultado ~= 0 then
    vim.notify("Java: falha ao criar arquivo.", vim.log.levels.ERROR)
    return
  end

  vim.notify("Java: criado " .. nome .. ".java", vim.log.levels.INFO)

  local abriu = pcall(vim.cmd.edit, vim.fn.fnameescape(arquivo))

  if not abriu then
    vim.notify("Arquivo criado, mas nao foi possivel abri-lo.", vim.log.levels.WARN)
  end
end

function M.criar(arquivo)
  arquivo = arquivo or vim.api.nvim_buf_get_name(0)

  local fontes = M.localizar_fontes(arquivo)

  if not fontes then
    vim.notify("Java: projeto Maven ou Gradle nao encontrado.", vim.log.levels.WARN)
    return
  end

  local pacote_padrao = pacote_atual(fontes, arquivo)

  vim.ui.select(tipos, {
    prompt = "Java - Novo elemento",

    format_item = function(item)
      return item.nome
    end,
  }, function(escolha)
    if not escolha then
      return
    end

    vim.ui.input({
      prompt = "Pacote Java: ",
      default = pacote_padrao,
    }, function(pacote)
      if pacote == nil then
        return
      end

      pacote = vim.trim(pacote)

      if not pacote_valido(pacote) then
        vim.notify("Java: pacote invalido.", vim.log.levels.ERROR)
        return
      end

      vim.ui.input({
        prompt = "Nome do tipo: ",
      }, function(nome)
        if nome == nil then
          return
        end

        nome = vim.trim(nome)

        if escolha.tipo ~= "record" then
          criar_arquivo(fontes, escolha.tipo, pacote, nome)
          return
        end

        vim.ui.input({
          prompt = "Componentes do record: ",
          default = "",
        }, function(componentes)
          if componentes == nil then
            return
          end

          criar_arquivo(fontes, escolha.tipo, pacote, nome, vim.trim(componentes))
        end)
      end)
    end)
  end)
end

return M
