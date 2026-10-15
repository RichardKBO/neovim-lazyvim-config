# 🖥️ Neovim / LazyVim — IDE Multilinguagem

![Neovim](https://img.shields.io/badge/Editor-Neovim-57A143)
![LazyVim](https://img.shields.io/badge/Base-LazyVim-7C3AED)
![Lua](https://img.shields.io/badge/Configura%C3%A7%C3%A3o-Lua-2C2D72)
![Linguagens](https://img.shields.io/badge/Linguagens-5%2F11_conclu%C3%ADdas-blue)
![Status](https://img.shields.io/badge/Status-Em_desenvolvimento-orange)

Configuração pessoal de **Neovim com LazyVim**, organizada em módulos por linguagem para criar um ambiente de desenvolvimento semelhante a uma IDE, com **LSP, autocomplete, diagnósticos, execução, depuração, menus e gerenciamento de projetos**.

O desenvolvimento é incremental. As alterações serão acompanhadas com **Issues, branches, commits e Pull Requests**, depois de testes e revisão.

> **Estado atual:** Rust, Java, Kotlin, C++ e Go passaram pela auditoria principal. As outras seis linguagens ainda precisam de revisão ou implementação de recursos. Este repositório está em desenvolvimento, não é uma distribuição pronta para todos os ambientes.

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

---

# 🌐 Linguagens suportadas e andamento

| Linguagem | Situação | Foco da configuração |
|---|---|---|
| **Rust** | ✅ Auditoria principal concluída | Cargo, workspaces, Rust Analyzer, execução e depuração |
| **Java** | ✅ Auditoria principal concluída | Maven, Gradle, JDTLS, execução e depuração |
| **Kotlin** | ✅ Auditoria principal concluída | Gradle, LSP, execução e depuração |
| **C++** | ✅ Auditoria principal concluída | Clangd, CMake, compilação e CodeLLDB |
| **Go** | ✅ Auditoria principal concluída | Gopls, Delve, módulos e gerador de projetos |
| **C#** | ⏳ Próxima auditoria | .NET, projetos `.csproj`, F6/F8 e NetCoreDbg |
| **Python** | ⏳ Pendente | Ambientes virtuais, Pyright, Ruff e debugpy |
| **Ruby** | ⏳ Pendente | Ruby LSP/Solargraph, Bundler e RuboCop |
| **SQL** | ⏳ Pendente | LSP, execução de scripts e conexões |
| **Dart** | ⏳ Pendente | Dart Analysis Server e depuração |
| **PHP** | ⏳ Pendente | PHP, Composer, LSP e Xdebug |

**Progresso da auditoria por linguagem: 5/11 (45,5%).** Uma linguagem marcada como concluída passou pelos testes principais, mas ainda poderá receber melhorias na revisão geral e na fase de frameworks.

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
| `:Temas` | Abrir o seletor de temas |

**Observação:** alguns atalhos são contextuais e só aparecem ou funcionam em determinadas linguagens. As linguagens pendentes ainda passarão pela auditoria de F6, F8 e menus.

---

# 🔍 LSP, autocomplete e diagnósticos

A configuração combina os recursos de linguagem do LazyVim com módulos próprios. Entre as ferramentas já utilizadas ou previstas na auditoria estão:

- **Rust:** Rust Analyzer.
- **Java:** JDTLS.
- **C++:** Clangd.
- **Go:** Gopls.
- **Python:** Pyright e Ruff — revisão pendente.
- **Ruby:** Ruby LSP ou Solargraph, além de RuboCop — revisão pendente.
- **C#:** revisão do servidor de linguagem e da integração .NET pendente.

O objetivo é manter autocomplete, navegação, diagnósticos e imports coerentes com o projeto aberto. Recursos como auto-import e atualização de diagnósticos durante a digitação dependem do servidor e da linguagem.

### Desempenho do Ruby e Solargraph

Na futura auditoria do Ruby, será verificado qual LSP está realmente ativo e como ocorre a indexação dos projetos. Se o Solargraph estiver em uso, serão avaliados `include`, `exclude` e `max_files: 5000`, sem sobrescrever configurações existentes. Um `.solargraph.yml` será criado **somente se necessário**.

---

# 🗂️ Gerenciamento de projetos

Os menus e geradores específicos de linguagens têm como objetivo permitir criar e administrar projetos sem depender de um único diretório.

O funcionamento desejado é:

1. Identificar o arquivo e a linguagem do buffer atual.
2. Descobrir a raiz do projeto usando arquivos relevantes, como `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle` ou `CMakeLists.txt`.
3. Selecionar o programa ou pacote correto quando houver mais de um candidato.
4. Executar ou depurar no contexto correto, sem reutilizar acidentalmente o projeto anterior.
5. Permitir projetos localizados fora das pastas habituais de desenvolvimento.

Os mecanismos exatos variam por linguagem. O suporte às seis linguagens pendentes ainda será validado.

---

# 🐙 Desenvolvimento com Git e GitHub

O projeto utiliza um fluxo incremental de versionamento. O repositório Git local já foi inicializado na branch `main`; a organização de commits e a publicação no GitHub fazem parte da etapa atual.

### Fluxo planejado

```text
Issue
  ↓
Branch da tarefa ou linguagem
  ↓
Implementação e testes
  ↓
Commit
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

---

# 🚀 Instalação e primeiros passos

## Pré-requisitos

- Neovim compatível com a versão do LazyVim utilizada.
- Git.
- Um terminal e as ferramentas de sistema exigidas pelos plugins.
- SDKs, compiladores, ferramentas de build, LSPs e debuggers das linguagens que você pretende usar.

Esta configuração está sendo desenvolvida e testada no **Linux Mint**. O funcionamento em outros sistemas ainda requer validação.

## Instalação futura a partir do GitHub

Quando o repositório estiver publicado, a instalação poderá seguir este procedimento, usando a **URL real do projeto**:

```bash
# Faça backup de uma configuração existente antes de substituí-la.
# Clone o repositório em ~/.config/nvim:
git clone <URL_DO_REPOSITORIO> ~/.config/nvim

# Inicie o editor:
nvim
```

Depois da inicialização, utilize `:Lazy sync` para sincronizar os plugins e `:Mason` para verificar ou instalar ferramentas de linguagem. Alguns SDKs e debuggers precisam ser instalados pelo gerenciador de pacotes do sistema ou por ferramentas próprias.

**Importante:** os plugins, os servidores LSP e os debuggers não fazem parte dos arquivos versionados. A configuração ainda não oferece um instalador totalmente automático para todas as linguagens.

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
    │   ├── ruby/
    │   ├── sql/
    │   └── cmake/
    │
    └── plugins/
```

**Nota:** a árvore acima mostra os diretórios existentes na etapa atual, não significa que todos já estejam auditados. Diretórios vazios, como `after/`, não são necessariamente registrados pelo Git.

---

# 🧭 Roadmap de desenvolvimento

## Fase 0 — Git e GitHub

- [x] Inicializar o repositório local na branch `main`.
- [x] Configurar exclusões básicas de backups e preferências locais.
- [x] Inspecionar os arquivos candidatos ao primeiro commit.
- [ ] Finalizar e revisar este README.
- [ ] Conferir informações pessoais e segredos antes da publicação.
- [ ] Preparar o primeiro commit-base.
- [ ] Configurar o remoto GitHub e o fluxo de Issues, branches e Pull Requests.

## Fase 1 — Auditoria das linguagens

- [x] Rust.
- [x] Java.
- [x] Kotlin.
- [x] C++.
- [x] Go.
- [ ] C#.
- [ ] Python.
- [ ] Ruby, incluindo desempenho de indexação do Solargraph, se utilizado.
- [ ] SQL.
- [ ] Dart.
- [ ] PHP.

## Fase 2 — Formatação BSD/Allman

- [ ] Configurar chaves na linha seguinte nas linguagens e ferramentas compatíveis.
- [ ] Revisar Enter, indentação e autopairs.
- [ ] Respeitar os formatadores oficiais e as exigências sintáticas de cada linguagem.

## Fase 3 — Frameworks e ecossistemas

- [ ] Avaliar integrações com ASP.NET Core, Spring Boot, Ktor, Axum, FastAPI, Django, Rails, Laravel, Flutter e outros frameworks relevantes.
- [ ] Integrar execução, depuração, testes e gerenciamento de projetos conforme as ferramentas escolhidas.

## Fase 4 — Interface

- [ ] Refinar lualine, informações de projeto e indicadores de LSP.
- [ ] Padronizar menus, notificações e a central `:Atalhos`.

## Fase 5 — Auditoria geral

- [ ] Revisar módulos Lua, plugins, conflitos de atalhos, autocmds e desempenho.
- [ ] Executar testes de regressão nas 11 linguagens.
- [ ] Remover código obsoleto e dependências desnecessárias com segurança.

## Fase 6 — Portabilidade e publicação estável

- [ ] Documentar requisitos e procedimentos de instalação.
- [ ] Verificar caminhos locais e possíveis informações sensíveis.
- [ ] Validar uma instalação limpa quando possível.
- [ ] Publicar uma versão estável e reproduzível.

---

# 📊 Status do projeto

**Em desenvolvimento — 5 de 11 linguagens com auditoria principal concluída.**

O projeto evolui gradualmente. A conclusão das cinco primeiras linguagens não significa que toda a configuração já tenha passado por uma auditoria global de plugins, segurança, compatibilidade e desempenho.

---

# 👨‍💻 Autor

**Richard Kawan Barbosa Oliveira**

Configuração desenvolvida para estudo, prática de programação e aprimoramento de um ambiente de desenvolvimento com Neovim e LazyVim.

- **GitHub:** [RichardKBO](https://github.com/RichardKBO)
- **LinkedIn:** [Richard K. B. Oliveira](https://www.linkedin.com/in/richard-k-b-oliveira-9a1a3b287/)

---

# 📜 Licença

Consulte o arquivo [LICENSE](LICENSE) presente no repositório. A identificação e compatibilidade da licença serão verificadas antes da publicação.

---

## 📌 Observação

Este projeto é uma configuração pessoal em evolução. As funcionalidades serão ampliadas e verificadas à medida que avançarmos pelas linguagens, frameworks e auditorias previstas no roadmap.

O objetivo é reunir **organização modular, produtividade, execução e depuração contextuais, recursos de linguagem e boas práticas de versionamento** em um único ambiente de desenvolvimento.
