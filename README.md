
# 🖥️ Neovim / LazyVim — IDE Multilinguagem

![Neovim](https://img.shields.io/badge/Editor-Neovim-57A143)
![LazyVim](https://img.shields.io/badge/Base-LazyVim-7C3AED)
![Lua](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Lua-2C2D72)
![Linguagens](https://img.shields.io/badge/Linguagens-8%2F11_auditadas-blue)
![Status](https://img.shields.io/badge/Status-Em_desenvolvimento-orange)

Configuração pessoal de **Neovim com LazyVim**, organizada em módulos por linguagem para criar um ambiente de desenvolvimento semelhante a uma IDE, com **LSP, autocomplete, diagnósticos, execução, depuração, menus e gerenciamento de projetos**.

O desenvolvimento é incremental. As alterações são acompanhadas com **Issues, branches, commits e Pull Requests**, depois de testes e revisão.

> **Estado atual:** Rust, Java, Kotlin, C++, Go, C#, Python e Ruby concluíram suas auditorias principais e estão integrados à `main` local. A M09 — PHP está em andamento na branch `feat/php-audit` (Issue #7). SQL e Dart permanecem pendentes. O projeto continua em desenvolvimento.

---

## 🎯 Objetivo

Criar uma configuração do Neovim que seja:

- **Modular:** cada linguagem possui seus próprios arquivos Lua, evitando uma configuração monolítica.
- **Portátil:** os recursos devem funcionar em projetos localizados em diferentes diretórios, sem depender de caminhos fixos de um único computador.
- **Contextual:** atalhos e menus devem reconhecer a linguagem, o arquivo e o projeto atual.
- **Prática:** execução, depuração, LSP e ferramentas de projeto acessíveis dentro do editor.
- **Verificável:** toda alteração importante é acompanhada de backup, validação de sintaxe e teste real.
- **Versionável:** o código da configuração fica no Git; plugins, caches e ferramentas instaladas permanecem fora do repositório.

---

# 🏗️ Arquitetura da configuração

A configuração utiliza o **LazyVim** como base e separa personalizações próprias em três áreas principais.

### `lua/config/`

Responsável pelo comportamento geral do editor: inicialização de plugins, opções, atalhos globais, autocmds, aparência e central `:Atalhos`.

### `lua/languages/`

Concentra os módulos específicos de cada linguagem, incluindo, conforme a necessidade, `runner.lua`, `debugger.lua` ou `dap.lua`, `lsp.lua`, `diagnostics.lua`, `keymaps.lua`, `menu.lua` e `projects.lua`.

### `lua/plugins/`

Contém as definições e integrações dos plugins que complementam o LazyVim.

A proposta é manter os projetos do usuário separados da configuração do editor. Não é necessário copiar os módulos Lua para cada novo projeto.

As funcionalidades compartilhadas continuam globais, enquanto as particularidades de execução, depuração e gerenciamento de projetos permanecem nos módulos de cada linguagem.

---

# 🌐 Linguagens suportadas e andamento

| Linguagem | Situação | Foco da configuração |
|---|---|---|
| **Rust** | ✅ Auditoria principal concluída | Cargo, workspaces, Rust Analyzer, execução e depuração |
| **Java** | ✅ Auditoria principal concluída | Maven, Gradle, JDTLS, execução e depuração |
| **Kotlin** | ✅ Auditoria principal concluída | Gradle, LSP, execução e depuração |
| **C++** | ✅ Auditoria principal concluída | Clangd, CMake, compilação e CodeLLDB |
| **Go** | ✅ Auditoria principal concluída | Gopls, Delve, módulos e gerador de projetos |
| **C#** | ✅ Auditoria concluída e integrada | .NET, projetos `.csproj`, LSP, F6/F8 e NetCoreDbg |
| **Python** | ✅ Auditoria concluída e integrada | Ambientes virtuais, Pyright, Ruff, debugpy e PythonMenu |
| **Ruby** | ✅ Auditoria concluída e integrada | Solargraph, Bundler, RuboCop, F6/F8 e RubyMenu |
| **PHP** | 🚧 Auditoria M09 em andamento | Intelephense, Composer, F6/F8, Xdebug e PHPMenu |
| **SQL** | ⏳ Pendente | LSP, execução de scripts e conexões |
| **Dart** | ⏳ Pendente | Dart Analysis Server e depuração |

**Progresso das auditorias principais: 8/11 (72,7%).**

Uma linguagem marcada como concluída passou pelos testes principais, mas ainda poderá receber melhorias na revisão geral, na fase de frameworks e nos testes de regressão finais.

---

# 🦀 Rust

A configuração do Rust passou por testes envolvendo Cargo, projetos e workspaces.

**Recursos verificados:**

- Integração com Rust Analyzer e Cargo.
- Reconhecimento do contexto do projeto e do workspace.
- Execução contextual pelo **F6**.
- Depuração com **F8** e CodeLLDB.
- Breakpoints pelo **F5**.
- Menu de ferramentas Rust e integração com `:Atalhos`.

---

# ☕ Java

O ambiente Java foi organizado para trabalhar com projetos **Maven e Gradle**.

**Recursos verificados:**

- JDTLS e recursos de linguagem.
- Identificação de programas e classes executáveis.
- Execução pelo **F6** e depuração pelo **F8**.
- Breakpoints pelo **F5**.
- JavaMenu, integração com `:Atalhos` e testes em projetos independentes.

---

# 🟣 Kotlin

A configuração Kotlin foi testada com projetos **Gradle**, execução e depuração contextual.

**Recursos verificados:**

- Integração com LSP e Gradle.
- Execução pelo **F6** e depuração pelo **F8**.
- KotlinMenu e gerenciamento de projetos.
- Integração com `:Atalhos`.
- Testes em projetos independentes.

O gerador utiliza um diretório inicial sugerido, mas permite escolher outro local para criar o projeto.

---

# ⚙️ C++

O ambiente C++ inclui suporte a programas independentes e projetos com **CMake**, inclusive com múltiplos arquivos.

**Recursos verificados:**

- Clangd e diagnósticos.
- Compilação e execução dinâmica pelo **F6**.
- Depuração com **F8** e CodeLLDB.
- Breakpoints pelo **F5**.
- CPPMenu, ferramentas de projeto e integração com `:Atalhos`.
- Testes em projetos independentes e de múltiplos arquivos.

---

# 🐹 Go

O Go passou por testes tanto dentro da pasta habitual de projetos quanto em um diretório externo.

**Recursos verificados:**

- Gopls, auto-import e diagnósticos inline.
- Reconhecimento do módulo e do pacote correspondente ao arquivo aberto.
- Execução pelo **F6**.
- Depuração com **F8** e Delve; breakpoints pelo **F5**.
- GoMenu, criação de projetos, compilação e testes.
- Integração com `:Atalhos`.
- Validação em um projeto independente fora da pasta habitual de desenvolvimento.

---

# 🟢 C#

A auditoria do C# foi concluída na **M06** e integrada à branch principal por meio de Pull Request.

A configuração foi revisada para trabalhar com projetos **.NET**, incluindo arquivos `.csproj`, execução contextual e depuração.

**Recursos verificados:**

- Integração com o ambiente .NET e recursos de linguagem.
- Reconhecimento de projetos e arquivos C#.
- Execução contextual pelo **F6**.
- Depuração pelo **F8** com NetCoreDbg.
- Breakpoints pelo **F5**.
- Menu contextual C# e integração com `:Atalhos`.
- Testes de funcionamento em projetos independentes.

A execução deve considerar o arquivo e o projeto atuais, sem reutilizar acidentalmente um projeto aberto anteriormente.

O objetivo é permitir trabalhar com diferentes projetos .NET sem manter caminhos absolutos específicos da máquina nas configurações versionadas.

---

# 🐍 Python

A auditoria principal do Python foi concluída na **M07**, desenvolvida na branch `feat/python-audit` e vinculada à **Issue #3**.

A configuração combina o extra oficial `lazyvim.plugins.extras.lang.python` com módulos próprios de execução, depuração, menu e atalhos contextuais.

**Recursos verificados:**

- Pyright e Ruff configurados pelo extra oficial do LazyVim.
- Autocomplete, autoimport e diagnósticos de linguagem.
- Diagnósticos inline, incluindo atualização durante a digitação.
- Execução do arquivo atual pelo **F6**.
- Depuração pelo **F8** com `nvim-dap` e `debugpy`.
- Breakpoints pelo **F5**.
- Identificação da raiz do projeto a partir de arquivos relevantes.
- Reconhecimento de ambientes `.venv` e `venv`.
- Fallback para o Python disponível no `PATH`, incluindo gerenciadores como mise.
- PythonMenu e atalhos específicos do buffer Python.
- Integração contextual com a central `:Atalhos`.
- Testes em projetos independentes, incluindo diretórios externos e arquivos em subpastas.

## Execução Python — F6

O módulo `lua/languages/python/runner.lua` identifica o arquivo atual e o contexto do projeto.

Quando encontra um ambiente virtual válido, utiliza seu interpretador. Caso contrário, procura o Python disponível no `PATH`.

A execução ocorre no diretório identificado como raiz do projeto, permitindo utilizar o mesmo Neovim em diferentes pastas.

## Depuração Python — F8

O módulo `lua/languages/python/dap.lua` utiliza o `debugpy` instalado pelo Mason.

Há uma separação entre:

- **Python do adaptador:** utilizado para executar o `debugpy` instalado pelo Mason.
- **Python do projeto:** utilizado para executar o código que está sendo depurado.

Essa separação evita exigir que cada ambiente virtual contenha uma instalação própria do adaptador.

O depurador também identifica a raiz do projeto e seleciona `.venv`, `venv` ou o interpretador disponível no `PATH`.

## Pyright e Ruff

O extra oficial Python do LazyVim é responsável pela configuração dos servidores.

Uma habilitação manual redundante do Pyright foi removida durante a auditoria.

Após essa simplificação, foram confirmados:

- Um cliente Pyright e um cliente Ruff associados ao buffer testado.
- Diagnósticos de importação não utilizada pelo Ruff.
- Diagnósticos de incompatibilidade de tipos pelo Pyright.
- Autocomplete de métodos Python.

A configuração de diagnósticos inline é compartilhada com as demais linguagens compatíveis.

## PythonMenu

O menu pode ser aberto com:

```vim
:PythonMenu
```

Ou, dentro de um buffer Python, com:

```text
Espaço + p + m
```

O menu reúne opções para executar o arquivo atual, iniciar a depuração e consultar informações do interpretador e do projeto.

O atalho é local ao buffer Python. Seu isolamento foi testado com um buffer C++, no qual o mapeamento não estava registrado.

A central `:Atalhos` também mostra a seção Python somente quando aberta a partir de um buffer Python.

---

# 🐘 PHP — M09 (em andamento)

**Issue #7 — Branch `feat/php-audit`.**

## Recursos testados

- Intelephense, Blink, diagnósticos inline, `gd` e `gr`.
- Composer PSR-4, namespaces, interfaces e herança.
- F6 executando o arquivo atual com validação de sintaxe.
- F8 com Xdebug, breakpoints e depuração CLI entre arquivos.
- PHPMenu, atalho `Espaço + p h` e central `:Atalhos`.
- Servidor HTTP local pelo PHPMenu: iniciar, verificar e parar.
- Testes independentes com polimorfismo e múltiplas classes.

## Funcionalidades pendentes

- Depuração de requisições HTTP com Xdebug.
- F6 inteligente com seleção de pontos de entrada.
- Geração de projetos Composer e ferramentas de formatação.
- Refinamento futuro da experiência visual semelhante ao PhpStorm.

---

# ⌨️ Atalhos principais

| Atalho / comando | Finalidade |
|---|---|
| **F5** | Adicionar ou remover breakpoint |
| **F6** | Executar o arquivo, programa ou pacote atual, conforme a linguagem |
| **F7** | Gerar ou atualizar configuração CMake, quando aplicável |
| **F8** | Iniciar ou continuar a depuração, conforme o contexto |
| `:Atalhos` | Abrir a central de atalhos do Neovim |
| `Espaço + u A` | Abrir a central de atalhos |
| `:GoMenu` | Abrir o menu do Go |
| `Espaço + g m` | Abrir o GoMenu em buffers Go |
| `Espaço + c m` | Abrir o menu contextual C# |
| `:PythonMenu` | Abrir o menu do Python |
| `Espaço + p m` | Abrir o PythonMenu em buffers Python |
| `:PHPMenu` | Abrir menu contextual de ações PHP e Composer |
| `Espaço + p h` | Abrir PHPMenu em buffers PHP |
| `:Temas` | Abrir o seletor de temas |

**Observação:** alguns atalhos são contextuais e só aparecem ou funcionam em determinadas linguagens.

A central `:Atalhos` apresenta os comandos globais e acrescenta as seções específicas de acordo com o buffer de origem.

As linguagens ainda pendentes passarão pela auditoria de execução, depuração e menus.

---

# 🔍 LSP, autocomplete e diagnósticos

A configuração combina os recursos de linguagem do LazyVim com módulos próprios.

Entre as ferramentas utilizadas ou previstas estão:

- **Rust:** Rust Analyzer.
- **Java:** JDTLS.
- **C++:** Clangd.
- **Go:** Gopls.
- **C#:** integração LSP do ambiente .NET.
- **Python:** Pyright e Ruff, ambos verificados na auditoria M07.
- **Ruby:** Solargraph e RuboCop, revisados na M08.
- **Kotlin:** integração LSP e Gradle revisada na M03.
- **PHP:** Intelephense validado na M09.
- **SQL e Dart:** auditorias previstas para M10 e M11.

O objetivo é manter autocomplete, navegação, diagnósticos e imports coerentes com o projeto aberto.

A configuração global de diagnósticos também permite atualizações durante o modo de inserção. A disponibilidade e a precisão dos diagnósticos continuam dependendo do servidor e da linguagem.

### Solargraph e RuboCop — M08

A auditoria Ruby M08 foi concluída e integrada a `main`
pelo Pull Request #6.

Foram revisados Solargraph, RuboCop, Bundler, execução F6,
depuração F8, RubyMenu e gerenciamento de projetos.

---

# 🗂️ Gerenciamento de projetos

Os menus e geradores específicos de linguagens têm como objetivo permitir criar e administrar projetos sem depender de um único diretório.

O funcionamento desejado é:

1. Identificar o arquivo e a linguagem do buffer atual.
2. Descobrir a raiz do projeto usando arquivos relevantes, como `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `CMakeLists.txt`, `.csproj` ou `pyproject.toml`.
3. Selecionar o programa, arquivo ou pacote correto quando houver mais de um candidato.
4. Executar ou depurar no contexto correto, sem reutilizar acidentalmente o projeto anterior.
5. Permitir projetos localizados fora das pastas habituais de desenvolvimento.

Os mecanismos exatos variam por linguagem.

No Python, por exemplo, o F6 e o F8 identificam o interpretador e a raiz do projeto. No C#, os módulos trabalham com o contexto dos arquivos e projetos .NET.

O PHP está em auditoria; SQL e Dart permanecem pendentes.

---

# 🐙 Desenvolvimento com Git e GitHub

O projeto utiliza um fluxo incremental de versionamento, com branch `main` protegida e desenvolvimento organizado por Issues e Pull Requests.

**Repositório:**

[RichardKBO/neovim-lazyvim-config](https://github.com/RichardKBO/neovim-lazyvim-config)

### Fluxo adotado

```text
Issue
  ↓
Branch da tarefa ou linguagem
  ↓
Implementação e testes
  ↓
Commits
  ↓
Push da branch
  ↓
Pull Request
  ↓
Revisão e merge
  ↓
main
```

Cada etapa deverá seguir estas regras:

- Trabalhar em um arquivo por vez, quando possível.
- Criar backup antes de alterar um arquivo existente.
- Validar a sintaxe Lua com `luac -p`.
- Fazer testes reais no Neovim antes dos commits.
- Evitar versionar credenciais, caches, dependências instaladas ou arquivos de backup.
- Manter o `lazy-lock.json` versionado para registrar as revisões dos plugins.
- Revisar as alterações antes de integrá-las à `main`.

### Auditorias registradas

- **M06 — C#:** concluída e integrada à `main` (PR #2).
- **M07 — Python:** concluída e integrada à `main` (PR #4).
- **M08 — Ruby:** concluída e integrada à `main` (PR #6).
- **M09 — PHP:** em andamento na `feat/php-audit` (Issue #7).

A `main` local contém as auditorias M01 a M08.
O PHP permanece na branch de desenvolvimento, sem merge.

---

# 🚀 Instalação e primeiros passos

## Pré-requisitos

- Neovim compatível com a versão do LazyVim utilizada.
- Git.
- Um terminal e as ferramentas de sistema exigidas pelos plugins.
- SDKs, compiladores, ferramentas de build, LSPs e debuggers das linguagens que você pretende usar.

Esta configuração está sendo desenvolvida e testada no **Linux Mint**. O funcionamento em outros sistemas ainda requer validação.

## Instalação a partir do GitHub

Antes de instalar, faça backup de qualquer configuração existente do Neovim.

Para uma instalação nova, o procedimento básico é:

```bash
git clone https://github.com/RichardKBO/neovim-lazyvim-config.git ~/.config/nvim

nvim
```

Depois da inicialização, utilize:

```vim
:Lazy sync
:Mason
```

O primeiro comando permite sincronizar os plugins. O segundo abre o gerenciador de ferramentas de linguagem.

Alguns SDKs e debuggers precisam ser instalados pelo gerenciador de pacotes do sistema ou por ferramentas próprias.

**Importante:** os plugins, os servidores LSP e os debuggers não fazem parte dos arquivos versionados. A configuração ainda não oferece um instalador totalmente automático para todas as linguagens.

O procedimento de instalação será revisado novamente durante a fase de portabilidade e publicação estável.

---

# 📁 Estrutura básica do repositório

```text
nvim/
├── .gitignore
├── .neoconf.json
├── LICENSE
├── README.md
├── init.lua
├── lazy-lock.json
├── lazyvim.json
├── stylua.toml
│
└── lua/
    ├── config/
    │   ├── atalhos.lua
    │   ├── autocmds.lua
    │   ├── keymaps.lua
    │   ├── lazy.lua
    │   ├── options.lua
    │   ├── theme_selector.lua
    │   └── snacks/
    │
    ├── languages/
    │   ├── rust/
    │   ├── java/
    │   ├── kotlin/
    │   ├── cpp/
    │   ├── go/
    │   ├── csharp/
    │   ├── python/
    │   │   ├── dap.lua
    │   │   ├── init.lua
    │   │   ├── keymaps.lua
    │   │   ├── menu.lua
    │   │   ├── runner.lua
    │   │   └── snacks.lua
    │   ├── ruby/
    │   ├── sql/
    │   └── cmake/
    │
    └── plugins/
        ├── diagnostics.lua
        ├── python-dap.lua
        └── python.lua
```

**Nota:** a árvore apresenta os diretórios principais e uma seleção de arquivos relevantes, não uma listagem completa.

Os arquivos Python exibidos correspondem aos módulos utilizados na auditoria M07. O diretório `plugins/` contém outros arquivos não representados nessa visão resumida.

Diretórios vazios, como `after/`, não são necessariamente registrados pelo Git.

---

# 🧭 Roadmap de desenvolvimento

## Fase 0 — Git e GitHub

- [x] Inicializar o repositório local na branch `main`.
- [x] Configurar exclusões básicas de backups e preferências locais.
- [x] Inspecionar os arquivos candidatos ao primeiro commit.
- [x] Preparar o primeiro commit-base.
- [x] Configurar o remoto GitHub e o fluxo de Issues, branches e Pull Requests.
- [ ] Concluir a atualização e revisão contínua do README.
- [ ] Finalizar a verificação de informações pessoais e segredos antes da publicação estável.

## Fase 1 — Auditoria das linguagens

- [x] M01 — Rust.
- [x] M02 — Java.
- [x] M03 — Kotlin.
- [x] M04 — C++.
- [x] M05 — Go.
- [x] M06 — C#.
- [x] M07 — Python.
- [x] M08 — Ruby.
- [ ] M09 — PHP (Issue #7, em andamento).
- [ ] M10 — SQL.
- [ ] M11 — Dart.

### Expansão futura — tecnologias adicionais

- [ ] Swift.
- [ ] JavaScript e TypeScript.
- [ ] HTML e CSS: LSP, formatação e validação.

Essas tecnologias serão planejadas após o ciclo M01–M11,
sem numeração definitiva neste momento.
Não integram o contador original de 11 auditorias.

## Fase 2 — Formatação BSD/Allman

- [ ] Configurar chaves na linha seguinte nas linguagens e ferramentas compatíveis.
- [ ] Revisar Enter, indentação e autopairs.
- [ ] Respeitar os formatadores oficiais e as exigências sintáticas de cada linguagem.

## Fase 3 — Frameworks e ecossistemas

- [ ] Go — Gin.
- [ ] Rust — Axum.
- [ ] Java — Spring Boot.
- [ ] Kotlin — Ktor.
- [ ] PHP — Laravel.
- [ ] Ruby — Rails.
- [ ] Python — FastAPI.
- [ ] C# — ASP.NET Core.
- [ ] Swift — Vapor.

Instalar e auditar gradualmente, conforme a necessidade.
Verificar primeiro as ferramentas já presentes no sistema,
especialmente o suporte ASP.NET Core do SDK .NET.

C++ permanece suportado. Dart e JavaScript/TypeScript
terão auditorias futuras, sem frameworks nesta fase.

## Fase 4 — Interface

- [ ] Refinar lualine, informações de projeto e indicadores de LSP.
- [ ] Padronizar menus, notificações e a central `:Atalhos`.

## Fase 5 — Auditoria e refinamento global

- [ ] Revisar módulos Lua, plugins, atalhos e autocmds.
- [ ] Refinar desempenho, menus e integração entre linguagens.
- [ ] Remover código obsoleto com segurança.

## Fase 6 — Portabilidade

- [ ] Documentar requisitos e instalação.
- [ ] Revisar caminhos locais e informações sensíveis.
- [ ] Validar instalação limpa em outro ambiente.

## Fase 7 — Infraestrutura global de testes

- [ ] Definir testes automatizados para módulos Lua.
- [ ] Criar testes de regressão para os recursos principais.
- [ ] Validar integração entre linguagens, F6, F8 e menus.
- [ ] Preparar execução reproduzível dos testes.

## Fase 8 — Publicação estável

- [ ] Revisar a documentação final.
- [ ] Confirmar os testes e requisitos de portabilidade.
- [ ] Publicar uma versão estável e reproduzível.

---

# 📊 Status do projeto

**Em desenvolvimento — 8/11 auditorias principais concluídas (72,7%).**

**Concluídas:** Rust, Java, Kotlin, C++, Go, C#, Python e Ruby.

**M09 — PHP:** em andamento na branch `feat/php-audit`,
vinculada à Issue #7.

Já testados: Intelephense, Blink, diagnósticos, F6,
Xdebug/F8 para CLI, Composer PSR-4 e PHPMenu.

Pendentes: depuração HTTP com Xdebug,
seleção inteligente de pontos de entrada e geradores Composer.

**Próximas auditorias:** M10 — SQL e M11 — Dart.

Após as linguagens: frameworks, refinamento da interface,
auditoria global, portabilidade e infraestrutura de testes,
seguidas da publicação estável.

---

# 👨‍💻 Autor

**Richard Kawan Barbosa Oliveira**

Configuração desenvolvida para estudo, prática de programação e aprimoramento de um ambiente de desenvolvimento com Neovim e LazyVim.

- **GitHub:** [RichardKBO](https://github.com/RichardKBO)
- **LinkedIn:** [Richard K. B. Oliveira](https://www.linkedin.com/in/richard-k-b-oliveira-9a1a3b287/)

---

# 📜 Licença

Consulte o arquivo [LICENSE](LICENSE) presente no repositório. A identificação e compatibilidade da licença serão verificadas antes da publicação estável.

---

## 📌 Observação

Este projeto é uma configuração pessoal em evolução. As funcionalidades serão ampliadas e verificadas à medida que avançarmos pelas linguagens, frameworks e auditorias previstas no roadmap.

O objetivo é reunir **organização modular, produtividade, execução e depuração contextuais, recursos de linguagem e boas práticas de versionamento** em um único ambiente de desenvolvimento.
