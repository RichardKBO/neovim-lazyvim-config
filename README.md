# 🖥️ Neovim / LazyVim — IDE Multilinguagem

![Neovim](https://img.shields.io/badge/Editor-Neovim-57A143)
![LazyVim](https://img.shields.io/badge/Base-LazyVim-7C3AED)
![Lua](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Lua-2C2D72)
![Status](https://img.shields.io/badge/Status-Uso_Pessoal-blue)

Configuração pessoal do **Neovim + LazyVim**, desenvolvida em Lua e organizada por linguagem de programação.

O objetivo é oferecer recursos de IDE, incluindo LSP, autocomplete, diagnósticos, execução, depuração e menus contextuais.

**O projeto não exige frameworks específicos.** Cada desenvolvedor escolhe e instala os frameworks de que necessita.

## ✨ Recursos principais

- Configuração modular por linguagem.
- LSP, autocomplete, diagnósticos e navegação de código.
- F5, F6 e F8 contextuais nas linguagens integradas.
- Menus específicos e central de atalhos `:Atalhos`.
- Detecção automática de arquivos e projetos.
- Temas escuros com seletor `:Temas`.
- Ícones personalizados utilizando `mini.icons`.
- Lualine CosmicInk com separadores LEGO.
- Dashboard original do LazyVim com Snacks.
- Integração com Git local e GitHub.

## 🌐 Linguagens configuradas

| Linguagem | Ferramentas e recursos | Situação |
|---|---|---|
| Rust | Cargo, rust-analyzer, CodeLLDB, F6/F8 | Auditoria concluída |
| Java | JDTLS, Maven, Gradle, F6/F8 | Auditoria concluída |
| Kotlin | Gradle, Kotlin LSP, KotlinMenu, F5/F6/F8 | Auditoria concluída |
| C / C++ | Clangd, CMake, CodeLLDB, F6/F7/F8 | Funcional; auditoria C++ pendente |
| Go | Gopls, Delve, GoMenu, F6/F8 | Funcional; auditoria pendente |
| C# | .NET, Roslyn, NetCoreDbg, F6/F8 | Funcional; auditoria pendente |
| Python | Pyright, Ruff, debugpy, PythonMenu | Auditoria concluída |
| Ruby | Solargraph, RuboCop, Bundler, RubyMenu | Auditoria concluída |
| PHP | Intelephense, Composer, Xdebug, PHPMenu | Configurado; auditoria pendente |
| Swift | Swiftly, SourceKit-LSP, SwiftPM, LLDB-DAP, SwiftMenu, F6/F8 | Validação funcional realizada; auditoria pendente |
| TypeScript | VTSLS, TSX, js-debug-adapter, F5/F6/F8, TypeScriptMenu | Validação funcional realizada; auditoria pendente |
| JavaScript | Integrações a verificar na auditoria | Auditoria pendente |
| JSON | jsonls, SchemaStore, formatação e diagnósticos | Validação funcional realizada; auditoria pendente |
| HTML / CSS / SQL | Configurações a verificar | Auditoria pendente |

**Validação funcional** indica que determinados recursos já foram testados. **Auditoria concluída** indica a revisão aprofundada realizada na jornada atual.

Swift foi validado anteriormente no Linux Mint com SourceKit-LSP, SwiftPM, LLDB-DAP e 11 testes automatizados aprovados.

A auditoria de Dart foi cancelada. A linguagem C não faz parte da sequência de auditorias aprofundadas, embora o suporte existente no repositório seja preservado.

## ✅ Auditorias aprofundadas

Auditorias concluídas:

- Python
- Ruby
- Rust
- Java
- Kotlin

### Auditoria Kotlin — Outubro de 2026

A configuração Kotlin foi validada utilizando:

- Compilador Kotlin 2.4.21, gerenciado pelo SDKMAN.
- Kotlin LSP oficial da JetBrains, versão 263.7084.0.
- Projetos Gradle independentes.
- KotlinMenu para criação de projetos e tipos Kotlin.
- F6 inteligente para selecionar a função `main()` do arquivo aberto.
- Depuração com DAP, F5 e F8.
- Gradle Build e execução de testes.

**Resultados principais:**

- Hover, autocomplete, diagnósticos, `gd` e `gr` validados.
- Renomeação nativa do Kotlin LSP funcionando entre arquivos, incluindo imports.
- Seis geradores Kotlin validados: Class, Interface, Data Class, Object, Enum Class e Sealed Class.
- F6 validado com múltiplas funções `main()` em dois projetos Gradle independentes.
- Breakpoints, inspeção de variáveis, Step Over, Step Into, Step Out e Continue aprovados.
- Gradle Build e Gradle Test executados com sucesso.

**Limitações observadas:**

- O IncRename apresentou renomeação parcial e erro na interface durante os testes Kotlin. Sua configuração global foi preservada.
- O Kotlin LSP informa suporte à formatação, mas o comando testado não produziu alterações visíveis.
- O estilo Allman não foi forçado, para evitar incompatibilidades com a formatação Kotlin.

A auditoria foi concluída sem necessidade de modificar os arquivos Lua da configuração.

### Próxima sequência de auditorias

1. C++
2. Go
3. C#
4. Swift
5. PHP
6. JavaScript
7. TypeScript
8. JSON
9. HTML
10. CSS
11. SQL

Após as linguagens, o planejamento contempla frameworks e ferramentas associadas, refinamento global, auditoria do GrugFar, regressões e infraestrutura automatizada de testes.

## 🚀 Instalação

### 1. Pré-requisitos

Ambiente principal testado: **Linux Mint**.

- Neovim compatível com a versão do LazyVim utilizada.
- Git, curl, unzip, ripgrep e fd.
- Terminal com suporte a cores e Nerd Font.
- SDKs, LSPs e depuradores das linguagens desejadas.

No Linux Mint/Ubuntu:

```bash
sudo apt update
sudo apt install git curl unzip ripgrep fd-find build-essential
```

O pacote `fd-find` pode fornecer o executável `fdfind`.

### 2. Instalar a configuração

Antes de substituir uma instalação existente, faça backup de `~/.config/nvim`.

Coloque uma cópia versionada desta configuração em:

```text
~/.config/nvim/
```

Inicie o editor:

```bash
nvim
```

Comandos úteis:

```vim
:Lazy
:Mason
:checkhealth
```

O repositório é mantido com Git, utilizando branches de trabalho e integração à `main` pelo GitHub quando existem alterações versionadas.

Algumas ferramentas instaladas externamente, como SDKs, compiladores e servidores de linguagem, não são incluídas diretamente neste repositório.

### 3. Ferramentas das linguagens

Instale apenas os SDKs, compiladores, LSPs e depuradores necessários às linguagens que pretende utilizar.

Algumas ferramentas podem ser gerenciadas pelo Mason; outras exigem instalação externa ou configuração no `PATH`.

**Frameworks não são instalados nem impostos por esta configuração.**

## 🧩 Executor global C#

O C# utiliza um executor .NET compartilhado para executar classes de exercícios sem adicionar um `DesafioRunner.cs` a cada projeto.

O F6 identifica classes com:

```csharp
public static void Executar()
{
    // Codigo do exercicio
}
```

Ao abrir `Program.cs`, a execução convencional é preservada.

Projetos antigos com `EnableClassRunner=true` continuam utilizando seu dispatcher próprio.

### Reconstruir o executor compartilhado

O código-fonte versionado está em `tools/csharp-class-runner/`.

Com o .NET 10 SDK instalado, execute a partir da configuração:

```bash
cd ~/.config/nvim
dest="$HOME/.local/share/nvim/csharp-class-runner"
mkdir -p "$dest"
cp tools/csharp-class-runner/Program.cs "$dest/"
cp tools/csharp-class-runner/NeovimCSharpRunner.csproj "$dest/"
dotnet build "$dest/NeovimCSharpRunner.csproj" -c Debug
```

O executor compilado será utilizado pelo F6 e F8 nos projetos compatíveis.

A configuração atual do NetCoreDbg também contém um caminho local que deverá ser ajustado em outras instalações.

## ⌨️ Atalhos e comandos

| Atalho | Função |
|---|---|
| `F5` | Adicionar/remover breakpoint |
| `F6` | Executar arquivo ou projeto contextual |
| `F7` | Operações CMake, quando aplicável |
| `F8` | Iniciar/continuar depuração |
| `:Atalhos` | Central de atalhos |
| `:Temas` | Seletor de temas |
| `Espaço + u + t` | Abrir seletor de temas |
| `:KotlinMenu` / `Espaço + k + m` | Menu Kotlin |
| `:GoMenu` | Menu Go |
| `:PythonMenu` | Menu Python |
| `:PHPMenu` | Menu PHP |
| `Espaço + s + f` / `:SwiftMenu` | Criar e abrir projetos SwiftPM |

O `:TypeScriptMenu` (`Espaço + t + m`) cria projetos ESM com TypeScript e TSX locais. F6 executa e F8 depura o arquivo `.ts` aberto; `ts-nvim` abre a pasta de projetos.

O KotlinMenu permite criar projetos Gradle, gerar tipos Kotlin, compilar e executar testes.

## 🎨 Aparência

- Temas escuros alternáveis pelo seletor `:Temas`.
- Prévia imediata, Enter para confirmar e Esc para cancelar.
- Persistência da escolha em `tema-atual.json`.
- Ícones de linguagens com `mini.icons`.
- Lualine CosmicInk com cores dinâmicas e separadores LEGO.
- Dashboard padrão do LazyVim preservado.

## 🗂️ Estrutura do repositório

```text
~/.config/nvim/
├── init.lua
├── after/
├── formatters/
├── lua/
│   ├── config/        # Configuracoes globais
│   ├── languages/     # Modulos por linguagem
│   └── plugins/       # Plugins e interface
├── tools/
│   └── csharp-class-runner/
├── lazy-lock.json
├── lazyvim.json
├── README.md
└── LICENSE
```

Projetos de estudo, ferramentas compiladas e backups ficam fora do repositório.

## 🔧 Manutenção

Projeto pessoal com melhorias incrementais e auditorias por linguagem.

Antes de editar:

- Inspecionar a configuração existente.
- Criar e verificar backups.
- Alterar um arquivo por vez.
- Validar sintaxe, funcionamento e regressões.
- Conferir o estado do Git antes de integrar mudanças.

Quando existem alterações versionadas, o fluxo utilizado é:

**Branch de trabalho → Commit → Push → Pull Request → Merge na `main`.**

Auditorias concluídas sem alterações no repositório não exigem Pull Requests vazios.

## 👨‍💻 Autor e licença

**Richard Kawan Barbosa Oliveira**

- [GitHub](https://github.com/RichardKBO)
- [LinkedIn](https://www.linkedin.com/in/richard-k-b-oliveira-9a1a3b287/)
- [Repositório no GitHub](https://github.com/RichardKBO/neovim-lazyvim-config)

Consulte o arquivo [LICENSE](LICENSE).
