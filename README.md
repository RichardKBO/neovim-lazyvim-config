# 🖥️ Neovim / LazyVim — IDE Multilinguagem

![Neovim](https://img.shields.io/badge/Editor-Neovim-57A143)
![LazyVim](https://img.shields.io/badge/Base-LazyVim-7C3AED)
![Lua](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Lua-2C2D72)
![Status](https://img.shields.io/badge/Status-Uso_Pessoal-blue)

Configuração pessoal do **Neovim + LazyVim**, desenvolvida em Lua e organizada por linguagem. Oferece recursos de IDE, como LSP, autocomplete, diagnósticos, execução, depuração e menus contextuais. **Nenhum framework é obrigatório.**

## ✨ Recursos principais

- Arquitetura modular por linguagem e detecção contextual de projetos.
- LSP, autocomplete, navegação, diagnósticos, execução e DAP.
- F5/F6/F8 contextuais; F7 conforme a linguagem (GoMenu ou CMake).
- Menus por linguagem e Central de Atalhos (`:Atalhos`).
- Temas escuros, seletor `:Temas`, `mini.icons` e Lualine CosmicInk com separadores LEGO.
- Dashboard do LazyVim com Snacks e integração com Git/GitHub.

## 🌐 Linguagens configuradas

| Linguagem | Ferramentas e recursos | Situação |
|---|---|---|
| Rust | Cargo, rust-analyzer, CodeLLDB, F6/F8 | Auditoria concluída |
| Java | JDTLS, Maven, Gradle, F6/F8 | Auditoria concluída |
| Kotlin | Gradle, Kotlin LSP, KotlinMenu, F5/F6/F8 | Auditoria concluída |
| C / C++ | Clangd, CMake, CodeLLDB, F6/F7/F8 | Auditoria C++ concluída |
| Go | Gopls, Delve, golangci-lint, GoMenu, F5/F6/F7/F8 | Auditoria em fechamento; integração pendente |
| C# | .NET, Roslyn, NetCoreDbg, executor compartilhado | Auditoria realizada; reforço prático pendente |
| Python | Pyright, Ruff, debugpy, PythonMenu | Auditoria concluída |
| Ruby | Solargraph, RuboCop, Bundler, RubyMenu | Auditoria concluída |
| PHP | Intelephense, Composer, Xdebug, PHPMenu | Configurado; auditoria pendente |
| Swift | Swiftly, SourceKit-LSP, SwiftPM, LLDB-DAP, SwiftMenu | Validação funcional; auditoria pendente |
| TypeScript | VTSLS, TSX, js-debug-adapter, TypeScriptMenu | Validação funcional; auditoria pendente |
| JavaScript | Integrações a verificar | Auditoria pendente |
| JSON | jsonls, SchemaStore, formatação, diagnósticos | Validação funcional; auditoria pendente |
| HTML / CSS / SQL | Configurações a verificar | Auditorias pendentes |

**Validação funcional** significa testes específicos realizados. **Auditoria concluída** indica revisão aprofundada; funcionalidades ainda não integradas à `main` são identificadas separadamente.

Swift foi validado no Linux Mint com SourceKit-LSP, SwiftPM, LLDB-DAP e 11 testes automatizados aprovados. A auditoria de Dart foi cancelada. C mantém seu suporte, mas não integra a sequência de auditorias aprofundadas.

## ✅ Auditorias aprofundadas

**Concluídas e integradas:** Python, Ruby, Rust, Java, Kotlin e C++.

### Kotlin — Outubro de 2026

- Kotlin 2.4.21 (SDKMAN), Kotlin LSP da JetBrains 263.7084.0 e projetos Gradle independentes.
- KotlinMenu: criação de projetos e seis tipos (Class, Interface, Data Class, Object, Enum Class e Sealed Class).
- Hover, autocomplete, diagnósticos, `gd`, `gr` e renomeação nativa entre arquivos testados.
- F6 com múltiplas `main()`, F5/F8 com inspeção, passos e continuação; Gradle Build/Test aprovados.
- Limitações: IncRename teve renomeação parcial; formatação do LSP não alterou o arquivo no teste. Allman não foi forçado.

### Go — Outubro de 2026 (branch `feat/go-audit`)

- F6 com seleção contextual de executáveis em módulos internos e externos; arquivos sem `go.mod` executados isoladamente.
- F5/F8 com Delve: breakpoints, inspeção de variáveis, continuação e encerramento da sessão DAP.
- Gopls e `golangci-lint` contextualizados por projeto/arquivo; diagnóstico ST1023 detectado e removido após correção, inclusive sem módulo.
- GoMenu (`:GoMenu`, `Espaço + g + m` e F7): criar projeto, executar, depurar, compilar, testar, selecionar executável, analisar, organizar dependências e mostrar informações do módulo.
- As opções dependentes de `go.mod` são ocultadas em arquivos isolados; `go mod tidy` requer confirmação e protege alterações não salvas em `go.mod`/`go.sum`.
- F7 do C++/CMake e Central de Atalhos testados após a integração do GoMenu.
- **Estado:** testes funcionais realizados; revisão Git, commit, PR e merge na `main` ainda pendentes.

### Próxima sequência de trabalho

1. Fechar a auditoria Go (revisão, commit e integração).
2. C#: reforço prático da configuração existente, sem refazer a auditoria.
3. TypeScript.
4. Swift.
5. PHP.
6. JavaScript.
7. JSON.
8. HTML.
9. CSS.
10. SQL.

Depois: frameworks opcionais, refinamento global, GrugFar, regressões e infraestrutura automatizada de testes.

## 🚀 Instalação

### Pré-requisitos

Ambiente principal testado: **Linux Mint**. Requer Neovim compatível com o LazyVim utilizado, Git, curl, unzip, ripgrep, fd, terminal com cores e Nerd Font. SDKs, LSPs e depuradores são instalados conforme a linguagem.

```bash
sudo apt update
sudo apt install git curl unzip ripgrep fd-find build-essential
```

### Instalar e verificar

Faça backup de `~/.config/nvim` antes de substituir uma instalação. Coloque a configuração versionada nesse diretório e execute:

```bash
nvim
```

```vim
:Lazy
:Mason
:checkhealth
```

Compiladores, SDKs e ferramentas instalados externamente não fazem parte do repositório. **Frameworks não são impostos pela configuração.**

## 🧩 Executor global C#

O C# utiliza um executor .NET compartilhado, evitando criar um `DesafioRunner.cs` por projeto. O F6 identifica classes com:

```csharp
public static void Executar()
{
    // Codigo do exercicio
}
```

Em `Program.cs`, a execução convencional é preservada. Projetos antigos com `EnableClassRunner=true` continuam usando seu dispatcher.

### Reconstruir o executor compartilhado

O código-fonte está em `tools/csharp-class-runner/`. Com o SDK .NET 10:

```bash
cd ~/.config/nvim
dest="$HOME/.local/share/nvim/csharp-class-runner"
mkdir -p "$dest"
cp tools/csharp-class-runner/Program.cs "$dest/"
cp tools/csharp-class-runner/NeovimCSharpRunner.csproj "$dest/"
dotnet build "$dest/NeovimCSharpRunner.csproj" -c Debug
```

O executável compilado atende F6/F8 em projetos compatíveis. O NetCoreDbg ainda contém um caminho local que precisa ser adaptado em outras instalações.

## ⌨️ Atalhos e comandos

| Atalho / comando | Função |
|---|---|
| `F5` | Adicionar/remover breakpoint |
| `F6` | Executar arquivo, pacote ou projeto contextual |
| `F7` | GoMenu em Go; configuração CMake em C++ |
| `F8` | Iniciar/continuar depuração |
| `:Atalhos` | Central de atalhos contextual |
| `:Temas` / `Espaço + u + t` | Seleção de temas |
| `:GoMenu` / `Espaço + g + m` | Gerenciamento de projetos Go |
| `:KotlinMenu` / `Espaço + k + m` | Projetos, tipos, build e testes Kotlin |
| `:PythonMenu` / `:PHPMenu` | Menus das respectivas linguagens |
| `:SwiftMenu` / `Espaço + s + f` | Projetos SwiftPM |
| `:TypeScriptMenu` / `Espaço + t + m` | Projetos TypeScript ESM |

No TypeScript, o menu cria projetos ESM com TypeScript/TSX locais; F6 executa e F8 depura o arquivo `.ts` aberto. `ts-nvim` abre a pasta dos projetos.

## 🎨 Aparência

- Temas escuros alternáveis com prévia; Enter confirma e Esc cancela.
- Escolha persistida em `tema-atual.json`.
- Ícones via `mini.icons`, Lualine CosmicInk e dashboard LazyVim/Snacks.

## 🗂️ Estrutura do repositório

```text
~/.config/nvim/
├── init.lua
├── after/
├── formatters/
├── lua/
│   ├── config/       # Configuracoes globais
│   ├── languages/    # Modulos por linguagem
│   └── plugins/      # Plugins e interface
├── tools/csharp-class-runner/
├── lazy-lock.json
├── lazyvim.json
├── README.md
└── LICENSE
```

Projetos de estudo, ferramentas compiladas e backups ficam fora do repositório.

## 🔧 Manutenção

- Inspecionar antes de editar, fazer backup e alterar um arquivo por vez.
- Validar sintaxe, funcionamento, regressões e estado do Git.
- Manter este **README com no máximo 200 linhas**, inclusive linhas em branco.
- Fluxo: **branch de trabalho → commit → push → Pull Request → merge na `main`**.
- Auditorias sem alterações versionadas não exigem Pull Requests vazios.

## 👨‍💻 Autor e licença

**Richard Kawan Barbosa Oliveira**

- [GitHub](https://github.com/RichardKBO)
- [LinkedIn](https://www.linkedin.com/in/richard-k-b-oliveira-9a1a3b287/)
- [Repositório](https://github.com/RichardKBO/neovim-lazyvim-config)

Consulte [LICENSE](LICENSE).
