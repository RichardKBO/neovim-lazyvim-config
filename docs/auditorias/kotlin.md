# Auditoria Kotlin — Neovim / LazyVim

**Data:** 24 de outubro de 2026
**Etapas:** K01–K10
**Branch de trabalho:** `feat/kotlin-audit`
**Escopo:** ambiente Kotlin, LSP, KotlinMenu, geradores, Gradle, F6, DAP, testes, formatação e atalhos.

## Ambiente validado

- **Compilador Kotlin:** 2.4.21, gerenciado pelo SDKMAN (versão anterior 2.4.20 removida após validação).
- **Kotlin LSP:** servidor oficial da JetBrains, build `263.7084.0` (build anterior `263.6379.0` removida após validação). O servidor ainda está em fase Alpha.
- **Neovim:** 0.12.6 durante os testes.
- **Java:** JDK 25 instalado; projetos Gradle de auditoria criados com versão-alvo Java 21.
- **Projetos de teste:** `auditoria-kotlin-gradle-k03` e `auditoria-kotlin-gradle-k05`, ambos independentes em `~/Projetos/Kotlin/` e **fora do repositório Neovim**.

## Resultados por etapa

| Etapa | Teste | Resultado |
|---|---|---|
| K01 | Compilador, servidor e ambiente | Validado |
| K02 | Hover, autocomplete, diagnósticos, `gd` e `gr` | Aprovados |
| K02 | Renomeação nativa entre arquivos, imports e usos | Aprovada |
| K03 | Criação de projeto Kotlin pelo KotlinMenu, abertura e F6 inicial | Aprovados |
| K04 | Geradores: Class, Interface, Data Class, Object, Enum Class e Sealed Class | Seis estruturas válidas; build aprovado |
| K05 | F6 contextual com `App.kt`, `Exercicio01.kt` e `Exercicio02.kt` em dois projetos Gradle | Aprovado |
| K06 | Breakpoint F5, depuração F8, Locals, Step Over, Step Into, Step Out e Continue | Aprovados |
| K07 | Gradle Build e Gradle Test pelo KotlinMenu | Aprovados |
| K08 | Capacidade de formatação pelo LSP e inspeção de configurações | Inspecionada; sem alterações |
| K09 | Atalho `Espaço + k + m` e integração KotlinMenu | Aprovado |
| K10 | Documentação e fluxo Git | Registro documental da auditoria |

### K03–K05 — Evidências de execução

O KotlinMenu criou projetos Gradle válidos, e o primeiro projeto executou `Hello World!` pelo F6. Os geradores produziram os arquivos `Animal.kt`, `Exibivel.kt`, `Produto.kt`, `Configuracao.kt`, `StatusPedido.kt` e `ResultadoOperacao.kt`; a compilação conjunta terminou com `BUILD SUCCESSFUL`.

No projeto K03, o F6 executou corretamente três arquivos com funções `main()` distintas, inclusive retornando ao `App.kt` após executar outro arquivo. No projeto K05, o F6 também selecionou os pontos de entrada dos três arquivos, sem executar inadvertidamente os programas do primeiro projeto.

Exemplos de saídas verificadas: `Carro: Fusca`, bônus de funcionário (`1000.0` e `400.0`), `Animal: Rex`, `Som: Au au!`, processamento de PIX (`150.0`) e cartão (`300.0`). Os testes de execução terminaram com `BUILD SUCCESSFUL`.

### K06–K07 — Depuração e testes

O depurador parou no breakpoint de `Exercicio02.kt`, exibiu um objeto `PagamentoPix` com `valor = 150.0`, avançou até o objeto de valor `300.0` e permitiu entrar e sair de um método `processar()` sobrescrito. A continuação por F8 encerrou sem erros. A opção de testes Gradle do KotlinMenu executou `:app:test` com `BUILD SUCCESSFUL`.

## Limitações e decisões

- **IncRename:** a renomeação interativa apresentou atualização parcial entre arquivos em Kotlin; uma execução direta de `:IncRename` também apresentou erro relacionado a `cmd_prefix_len` nulo. A renomeação nativa com `vim.lsp.buf.rename()` funcionou. **Decisão:** preservar o atalho e o IncRename globais, sem aplicar exceção ao Kotlin nesta auditoria.
- **Formatação:** o servidor declarou suporte a `textDocument/formatting`, mas a chamada testada não produziu alterações visíveis. Isso **não comprova** ausência de formatação nem suporte ao estilo Allman. **Decisão:** não forçar Allman ou formatador externo.
- **Desempenho:** foi relatada uma inicialização lenta durante uso intensivo do sistema; em teste posterior o LSP iniciou em menos de cinco segundos. Não houve mudança de configuração por esse motivo.

## Resultado e manutenção

A auditoria funcional K01–K09 foi concluída sem necessidade de alterar os arquivos Lua da configuração. As instalações externas Kotlin/Kotlin LSP foram atualizadas e as versões anteriores removidas após validação.

Esta documentação e a atualização do `README.md` registram a auditoria no controle de versão. O fluxo previsto é **commit na branch → push → Pull Request → merge na `main`**, com conferência de Git e testes antes da integração.

**Próxima auditoria:** C++. A sequência posterior definida é Go, C#, Swift, PHP, JavaScript, TypeScript, JSON, HTML, CSS e SQL.
