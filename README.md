
# 🖥️ Neovim / LazyVim — IDE Multilinguagem

![Neovim](https://img.shields.io/badge/Editor-Neovim-57A143)
![LazyVim](https://img.shields.io/badge/Base-LazyVim-7C3AED)
![Lua](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Lua-2C2D72)
![Status](https://img.shields.io/badge/Status-Em_desenvolvimento-orange)

Configuração pessoal do **Neovim + LazyVim**, escrita em Lua e organizada por linguagem.
O objetivo é reunir recursos de IDE — **LSP, autocomplete, diagnósticos, execução,
depuração e menus contextuais** — sem perder a flexibilidade do editor.

> **Status:** projeto em desenvolvimento. As integrações possuem níveis diferentes
> de validação; funcionalidades ainda não testadas são identificadas abaixo.

## ✨ Recursos principais

- Configuração modular: cada linguagem possui seu próprio diretório em `lua/languages/`.
- **F6** para execução contextual e **F8** para depuração nas linguagens já integradas.
- **F5** para alternar breakpoints nos depuradores configurados.
- LSP, autocomplete, navegação para definições e diagnósticos de código.
- Menus por linguagem, notificações e central de ajuda `:Atalhos`.
- Detecção de projetos por arquivos como `Cargo.toml`, `pom.xml`, `go.mod` e `.csproj`.
- Integrações com Git, GitHub e ferramentas de desenvolvimento do LazyVim.

## 🌐 Linguagens e ferramentas

| Linguagem | Integração e ferramentas | Situação |
|---|---|---|
| **Rust** | Cargo, Rust Analyzer, F6/F8, CodeLLDB | Auditoria principal concluída |
| **Java** | Maven, Gradle, JDTLS, F6/F8 | Auditoria principal concluída |
| **Kotlin** | Gradle, LSP, F6/F8, KotlinMenu | Auditoria principal concluída |
| **C / C++** | Clangd, CMake, F6/F8, CodeLLDB | Auditoria principal concluída |
| **Go** | Gopls, Delve, F6/F8, GoMenu | Auditoria principal concluída |
| **C#** | .NET, projetos `.csproj`, F6/F8, NetCoreDbg | Auditoria principal concluída |
| **Python** | Pyright, Ruff, ambientes virtuais, debugpy, PythonMenu | Auditoria principal concluída |
| **Ruby** | Solargraph, RuboCop, Bundler, RubyMenu, F6/F8 | Auditoria principal concluída |
| **PHP** | Intelephense, Composer, Xdebug, PHPMenu, execução CLI/web | Configurado; refinamentos pendentes |
| **Swift** | Swift 6.4.1, Swiftly, SwiftPM, SourceKit-LSP, F6/F8, LLDB-DAP | Integração principal validada |

### Swift

A integração Swift foi validada no Linux Mint com a toolchain oficial
**Swift 6.4.1**, gerenciada pelo Swiftly.

Funcionalidades verificadas:

- Compilação com `swift build`.
- Execução com `swift run` e execução direta do binário compilado.
- SourceKit-LSP conectado ao Neovim.
- Diagnósticos, autocomplete, navegação e informações de código pelo LSP.
- **F6** para compilar e executar o projeto SwiftPM atual.
- **F5** para alternar breakpoints.
- **F8** para iniciar ou continuar a depuração com LLDB-DAP.
- Depuração de código orientado a objetos.
- Projeto de teste com classes, repositório, serviço e operações CRUD.
- Persistência dos produtos em arquivo JSON.
- **11 testes automatizados Swift Testing aprovados** com `swift test`.

Esses testes pertencem ao projeto SwiftPM utilizado na auditoria.
A infraestrutura global de testes do Neovim ainda será desenvolvida.

Os módulos Swift estão organizados em:

- `lua/languages/swift/lsp.lua`
- `lua/languages/swift/runner.lua`
- `lua/languages/swift/dap.lua`
- `lua/plugins/swift-dap.lua`

### JSON

O suporte JSON existente no Neovim também foi verificado.

Funcionalidades confirmadas:

- Realce de sintaxe.
- Servidor LSP `jsonls` ativo.
- Diagnósticos de erros de sintaxe.
- Formatação por meio do LSP.
- Autocomplete com sugestões de propriedades.
- Integração com schemas do SchemaStore.

Os testes foram realizados com arquivos temporários, preservando
os dados do projeto CRUD Swift.

**Próxima auditoria:** TypeScript.

**Integrações e auditorias pendentes:** SQL, HTML e CSS.
A auditoria de Dart foi cancelada e não faz parte da configuração atual.

## 🚀 Instalação

### 1. Pré-requisitos

- **Linux Mint** é o ambiente utilizado nos testes; outros sistemas ainda não foram validados.
- **Neovim** em uma versão compatível com o LazyVim utilizado pelo repositório.
- **Git**, **curl**, **unzip**, **ripgrep**, **fd** e ferramentas básicas de compilação.
- Um terminal com suporte a cores; uma **Nerd Font** é recomendada para os ícones.
- SDKs, runtimes, LSPs e depuradores das linguagens que pretende utilizar.

Instale o Neovim por uma distribuição compatível com o LazyVim; consulte os
[lançamentos oficiais do Neovim](https://github.com/neovim/neovim/releases).
Evite depender de uma versão antiga disponível no gerenciador de pacotes.

No Linux Mint/Ubuntu, instale as ferramentas básicas:

```bash
sudo apt update
sudo apt install git curl unzip ripgrep fd-find build-essential
```

> No Ubuntu/Mint, o executável do pacote `fd-find` pode se chamar `fdfind`.
> Verifique a exigência do seu plugin antes de criar qualquer alias.

### 2. Preserve uma instalação existente

**Execute os passos abaixo em uma máquina onde deseja instalar a configuração.**
Se já usa Neovim, faça backup antes de clonar:

```bash
mkdir -p ~/.config
if [ -e ~/.config/nvim ]; then
  mv ~/.config/nvim ~/.config/nvim.backup.$(date +%Y%m%d-%H%M%S)
fi
```

Este comando move a pasta existente para um backup, sem apagá-la.
Não é necessário executá-lo na máquina onde o repositório já está configurado.

### 3. Clone o repositório

```bash
git clone https://github.com/RichardKBO/neovim-lazyvim-config.git ~/.config/nvim
nvim
```

Na primeira abertura, permita que o gerenciador de plugins inicialize.
Depois, dentro do Neovim, utilize:

```vim
:Lazy sync
:Mason
:checkhealth
```

O `:Lazy sync` sincroniza plugins, `:Mason` gerencia ferramentas suportadas
e `:checkhealth` ajuda a identificar dependências e problemas do ambiente.

### 4. Instale as ferramentas das linguagens necessárias

A configuração Lua **não instala automaticamente todos os SDKs e debuggers**.
Prepare apenas os ambientes que pretende usar:

| Linguagem | Ferramentas externas principais |
|---|---|
| Rust | Rustup, Cargo, Rust Analyzer, CodeLLDB |
| Java / Kotlin | JDK, Maven e/ou Gradle; LSP e depurador apropriados |
| C / C++ | Compilador C/C++, CMake, Clangd, CodeLLDB |
| Go | Go SDK, Gopls, Delve |
| C# | .NET SDK, servidor LSP, NetCoreDbg |
| Python | Python, Pyright, Ruff, debugpy |
| Ruby | Ruby, Bundler, Solargraph, RuboCop |
| PHP | PHP, Composer, Intelephense, Xdebug e adaptador PHP Debug |
| Swift | Swiftly, Swift SDK, SourceKit-LSP e LLDB-DAP |

Para Swift no Linux, utilize as instruções oficiais do
[Swift.org](https://www.swift.org/install/linux/) e o gerenciador Swiftly.

O SourceKit-LSP e o LLDB-DAP são fornecidos pela toolchain Swift utilizada.
Os executáveis devem estar acessíveis pelo `PATH` no terminal que inicia o Neovim.

A disponibilidade das ferramentas pelo Mason depende de cada pacote;
SDKs e toolchains externos podem exigir instalação separada.

## ⌨️ Atalhos e comandos

| Atalho ou comando | Ação |
|---|---|
| `F5` | Ativar ou remover breakpoint, quando disponível |
| `F6` | Executar o arquivo ou projeto atual, nas linguagens integradas |
| `F7` | Gerar ou atualizar configuração CMake, quando aplicável |
| `F8` | Iniciar ou continuar depuração, quando disponível |
| `:Atalhos` | Mostrar a central de atalhos |
| `Espaço + u A` | Abrir a central de atalhos |
| `:Temas` | Abrir seletor de temas |
| `:GoMenu` | Menu de ações Go |
| `:PythonMenu` | Menu de ações Python |
| `:PHPMenu` | Menu de ações PHP/Composer |

Atalhos locais ao buffer incluem `Espaço + g m` (Go), `Espaço + c m`
(C#), `Espaço + p m` (Python) e `Espaço + p h` (PHP).
Os atalhos e menus dependem da linguagem do arquivo aberto.

No Swift, **F6** executa o projeto SwiftPM atual e **F8** utiliza o
depurador LLDB-DAP configurado para a linguagem.

## 🗂️ Organização do repositório

```text
~/.config/nvim/
├── init.lua                 # Entrada da configuração
├── lazy-lock.json           # Revisões dos plugins
├── lazyvim.json             # Extras LazyVim
├── README.md
└── lua/
    ├── config/              # Atalhos, autocmds, opções, aparência
    ├── languages/           # Módulos específicos por linguagem
    │   ├── rust/  java/  kotlin/  cpp/  go/  csharp/
    │   ├── python/  ruby/  php/  swift/
    │   └── cmake/
    └── plugins/             # Configurações e integrações de plugins
```

Os diretórios e módulos disponíveis variam conforme a etapa da auditoria.
Os programas de teste e projetos pessoais ficam **fora** deste repositório.

## 🧩 Como a configuração funciona

- `lua/config/` concentra configurações gerais, atalhos, aparência e inicialização.
- `lua/languages/` organiza `lsp.lua`, `runner.lua`, `dap.lua`, `menu.lua` e outros
  módulos, conforme as necessidades de cada linguagem.
- `lua/plugins/` configura extensões compartilhadas e recursos do LazyVim.
- F6 e F8 devem respeitar o arquivo e a raiz do projeto atuais, sem reutilizar
  acidentalmente executáveis ou contextos de outro projeto.

## 🧭 Próximos passos

- [x] Finalizar e testar o SourceKit-LSP do Swift no Neovim.
- [x] Implementar e validar Swift F6/F8 com projeto OOP, CRUD e persistência JSON.
- [x] Validar JSON com `jsonls`, diagnósticos, formatação e autocomplete.
- [ ] Auditar TypeScript, SQL, HTML e CSS.
- [ ] Revisar formatação, menus, atalhos, desempenho e portabilidade.
- [ ] Revisar o comportamento das integrações quando ferramentas externas estiverem indisponíveis.
- [ ] Adicionar infraestrutura global de testes, incluindo a integração F9 planejada.
- [ ] Adicionar testes de regressão e validar uma instalação limpa.
- [ ] Preparar uma versão estável da configuração.

O desenvolvimento é incremental: **backup antes de editar, um arquivo e um teste
por vez, validação de sintaxe e revisão do `git diff`** antes de commits ou PRs.

## 👨‍💻 Autor e licença

**Richard Kawan Barbosa Oliveira**

- [GitHub — RichardKBO](https://github.com/RichardKBO)
- [LinkedIn](https://www.linkedin.com/in/richard-k-b-oliveira-9a1a3b287/)
- Repositório: [neovim-lazyvim-config](https://github.com/RichardKBO/neovim-lazyvim-config)

Consulte o arquivo [LICENSE](LICENSE). Projeto pessoal em evolução;
a publicação estável dependerá da revisão das dependências e dos testes.
