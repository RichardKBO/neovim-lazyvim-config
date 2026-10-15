local M = {}

local function validar(dados)
  if not dados.nome:match("^[%w][%w._%-]*$") then
    return "Nome do projeto invalido."
  end

  if dados.diretorio == "" then
    return "Informe o diretorio de destino."
  end

  if not dados.artifact_id:match("^[%w][%w._%-]*$") then
    return "ArtifactId invalido."
  end

  if dados.group_id == "" then
    return "GroupId obrigatorio."
  end

  -- O GroupId tambem sera utilizado como pacote Java.
  local partes = vim.split(dados.group_id, ".", { plain = true })

  for _, parte in ipairs(partes) do
    if not parte:match("^[%a_][%w_]*$") then
      return "GroupId invalido para pacote Java."
    end
  end

  local java = tonumber(dados.java)

  if not java or java < 8 or java % 1 ~= 0 then
    return "Informe uma versao Java valida."
  end

  return nil
end

local function criar_diretorio(caminho)
  local ok = pcall(vim.fn.mkdir, caminho, "p")

  return ok and vim.fn.isdirectory(caminho) == 1
end

local function escrever_arquivo(caminho, linhas)
  local ok, resultado = pcall(vim.fn.writefile, linhas, caminho)

  return ok and resultado == 0
end

function M.gerar_maven(dados)
  local erro = validar(dados)

  if erro then
    return false, erro
  end

  local diretorio_pai = vim.fn.fnamemodify(vim.fn.expand(dados.diretorio), ":p")

  local raiz = vim.fs.normalize(vim.fs.joinpath(diretorio_pai, dados.nome))

  -- Nunca modificar ou sobrescrever projeto existente.
  if vim.uv.fs_lstat(raiz) then
    return false, "O projeto ja existe: " .. raiz
  end

  local caminho_pacote = dados.group_id:gsub("%.", "/")

  local java_principal = vim.fs.joinpath(raiz, "src", "main", "java", caminho_pacote)

  local java_testes = vim.fs.joinpath(raiz, "src", "test", "java", caminho_pacote)

  local diretorios = {
    java_principal,
    java_testes,
    vim.fs.joinpath(raiz, "src", "main", "resources"),
    vim.fs.joinpath(raiz, "src", "test", "resources"),
  }

  for _, diretorio in ipairs(diretorios) do
    if not criar_diretorio(diretorio) then
      return false, "Falha ao criar: " .. diretorio
    end
  end

  -- Maven POM
  local pom = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<project xmlns="http://maven.apache.org/POM/4.0.0"',
    '         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"',
    '         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">',
    "",
    "    <modelVersion>4.0.0</modelVersion>",
    "",
    "    <groupId>" .. dados.group_id .. "</groupId>",
    "    <artifactId>" .. dados.artifact_id .. "</artifactId>",
    "    <version>1.0-SNAPSHOT</version>",
    "",
    "    <properties>",
    "        <maven.compiler.source>" .. dados.java .. "</maven.compiler.source>",
    "        <maven.compiler.target>" .. dados.java .. "</maven.compiler.target>",
    "        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>",
    "    </properties>",
    "",
    "</project>",
  }

  local principal = {
    "package " .. dados.group_id .. ";",
    "",
    "public class Main {",
    "",
    "    public static void main(String[] args) {",
    '        System.out.println("Projeto Java funcionando!");',
    "    }",
    "}",
  }

  local gitignore = {
    "target/",
    ".idea/",
    ".settings/",
    ".classpath",
    ".project",
    ".factorypath",
    "*.class",
    "*.log",
  }

  local arquivos = {
    {
      caminho = vim.fs.joinpath(raiz, "pom.xml"),
      conteudo = pom,
    },
    {
      caminho = vim.fs.joinpath(java_principal, "Main.java"),
      conteudo = principal,
    },
    {
      caminho = vim.fs.joinpath(raiz, ".gitignore"),
      conteudo = gitignore,
    },
  }

  for _, arquivo in ipairs(arquivos) do
    if not escrever_arquivo(arquivo.caminho, arquivo.conteudo) then
      return false, "Falha ao escrever: " .. arquivo.caminho .. ". Verifique os arquivos criados."
    end
  end

  return true, raiz, arquivos[2].caminho
end

function M.criar_maven()
  local dados = {}

  local perguntas = {
    {
      chave = "nome",
      texto = "Nome do projeto: ",
      padrao = "",
    },
    {
      chave = "diretorio",
      texto = "Pasta onde criar o projeto: ",
      padrao = vim.fn.getcwd(),
    },
    {
      chave = "group_id",
      texto = "GroupId: ",
      padrao = "com.richard",
    },
    {
      chave = "artifact_id",
      texto = "ArtifactId: ",
      padrao = function()
        return dados.nome or ""
      end,
    },
    {
      chave = "java",
      texto = "Versao do Java: ",
      padrao = "25",
    },
  }

  local function proxima_pergunta(indice)
    local pergunta = perguntas[indice]

    if not pergunta then
      local sucesso, resultado, principal = M.gerar_maven(dados)

      if not sucesso then
        vim.notify("Java Maven: " .. resultado, vim.log.levels.ERROR)
        return
      end

      vim.notify("Projeto Maven criado: " .. resultado, vim.log.levels.INFO)

      -- Abrir automaticamente a classe principal.
      local ok = pcall(vim.cmd.edit, vim.fn.fnameescape(principal))

      if not ok then
        vim.notify("Projeto criado, mas nao foi possivel abrir Main.java.", vim.log.levels.WARN)
      end

      return
    end

    local padrao = pergunta.padrao

    if type(padrao) == "function" then
      padrao = padrao()
    end

    vim.ui.input({
      prompt = pergunta.texto,
      default = padrao,
    }, function(valor)
      if valor == nil then
        vim.notify("Criacao de projeto cancelada.")
        return
      end

      dados[pergunta.chave] = vim.trim(valor)

      proxima_pergunta(indice + 1)
    end)
  end

  proxima_pergunta(1)
end

return M
