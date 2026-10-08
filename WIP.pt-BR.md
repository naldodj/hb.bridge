# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

WIP registra o pacote atual, a próxima ação e as evidências de conclusão.
Retome sua primeira tarefa pendente em vez de repetir a análise geral do
projeto. TODO mantém o roadmap completo; README descreve o produto; homologação
registra resultados verificados; ChangeLog e Git preservam o histórico.

## Pacote 001: homologação MSSQL real

| Item | Valor atual |
| --- | --- |
| ID | `001-mssql-acceptance` |
| Abertura / atualização | 2026-10-07 |
| Situação | MSSQL planejado; migração preparatória .hb autorizada explicitamente concluída. Nenhuma execução MSSQL registrada ainda. |
| Objetivo | Homologar RPCRDD.Query/dataset existentes em banco MSSQL real identificado, por Harbour, TCP Protheus e HTTP Protheus. |
| Referência do produto | Código publicado `50e1c65`; checkout na abertura `bce52d2` inclui atualização do badge de clones. |
| Próxima tarefa | M01: registrar perfil alvo, ambiente ODBC e autenticação sem guardar segredos aqui. |

### Decisões já tomadas

- Manter implementação única e contrato Query/páginas existentes. Usar
  SQLMIX/RDDSQL com SDDODBC; corrigir defeitos revelados por este aceite.
- Protheus resolve tenant/empresa/filial/xFilial, nomes de tabelas e regras de
  negócio. hbBridge executa SQL/parâmetros explícitos. Começar por SELECTs de
  constantes e fixture isolada de leitura; preservar tabelas ERP de produção.
- Perfis continuam aliases opacos selecionados explicitamente por chamada.
  `mssql/pData` é exemplo, sem perfil obrigatório nem resolução de contexto.
- Usar string ODBC privada ou autenticação integrada já suportadas. Credenciais
  cifradas/CLI portáveis ficam para pacote posterior; sua implementação não é
  pré-requisito deste aceite.
- O responsável esclareceu em 2026-10-07 que as credenciais SQL são estáveis;
  rotação automática da senha do banco fica fora do escopo escolhido. KV OpenBao
  dispensa plugin MSSQL dinâmico. Renovação do token do cofre tem ciclo separado.
- Preservar o mutex compartilhado do ciclo SQL. Verificar isolamento/limpeza
  com chamadas concorrentes; este pacote não promete execução SQL paralela.
- Manter capacidades reais do runtime e políticas configuráveis, sem teto
  fixo de payload de prova de conceito nem novo transporte.

### Ponto de partida verificado

- Suíte Harbour: **487 checks, zero falhas e nenhum skip**, repetida em 2026-10-07.
- Aceite SQLite do operador: **29 checks de dataset/páginas**, repetido em
  2026-10-07, thread 27136, perfil `sqlite_demo`.
- Configuração cliente revisada: **16 checks**, 2026-10-07, thread 30596.
- TCP do operador: relógio, Health, ADDON e os dois Echo exatos de 200000 bytes
  aprovados em 2026-10-07, thread 27084.
- Aceite HTTP TLPP do operador: **13 checks**, repetido em 2026-10-07,
  threads 27296 e 25456 após a recompilação informada.
  Perfil/backend SQL não informado; esse resultado não homologa MSSQL.
- Prova nativa THREAD STATIC: **31 asserções**; estado de worker difere do
  estado da requisição. O mutex SQL compartilhado continua intencional.
- Logs, escopo exato e detalhes do runtime estão na [homologação](docs/acceptance.pt-BR.md).

### Ajuste preparatório explícito: extensão dos fontes Harbour

Em 2026-10-07 o responsável autorizou adotar `.hb` nativo para todos os fontes
Harbour próprios. Este ajuste delimitado de organização antecede M01 e não
substitui o pacote 001, reinicia seu progresso nem homologa MSSQL.

- [x] **P01 — Migrar fontes e referências.** Renomear os 26 fontes Harbour
  em `src/hb/`, `tests/` e `addons/`; atualizar HBP/HBM, scripts de teste e os
  caminhos do addon nos exemplos TLPP TCP/HTTP. Preservar fontes de terceiros
  e suporte a addons `.prg`.
- [x] **P02 — Validar e registrar o padrão.** Compilar o produto e executar
  regressões Harbour, validadores de commit e links locais da documentação.
  Registrar resultados e a situação da recompilação/homologação TLPP.

Evidências: 487 verificações Harbour, zero falhas/sem skips; build isolado do
produto e verificações de ajuda/configuração; três validadores para 141 arquivos;
links locais em 61 documentos e whitespace aprovados. Logs/detalhes estão na
[homologação](docs/acceptance.pt-BR.md#extensão-nativa-dos-fontes-harbour-em-2026-10-07).
O operador informou recompilação e apresentou execuções aprovadas de TCP,
SQLite, configuração revisada e HTTP. Evidências:
`tmp/protheus-http-hb-operator-20261007.log` e
`tmp/protheus-suite-hb-operator-20261007.log`; veja a [homologação](docs/acceptance.pt-BR.md).
A regressão TLPP preparatória está homologada nos casos exercitados. Retomar M01;
não repetir a migração concluída nem deduzir homologação MSSQL.

### Trabalho em ordem

- [ ] **M01 — Identificar o alvo.** Registrar alias SQL real, banco, endpoint,
  versão MSSQL, driver/versão/arquitetura ODBC, método de autenticação e
  identidade do processo hbBridge. Verificar acesso à configuração privada.
  Senhas, tokens e strings completas com credenciais ficam fora de Git/WIP.
- [ ] **M02 — Preparar aceite reproduzível.** Usar o [launcher SQL](examples/sql/README.pt-BR.md)
  e INI/JSON privado. Preparar uma rota de teste MSSQL real opt-in, separada da
  suíte SQLite padrão. Falta de conector/configuração obrigatória é falha de
  pré-requisito, nunca teste MSSQL bem-sucedido. Identificar o backend no resultado.
- [ ] **M03 — Homologar SQL Harbour.** Executar SELECTs de constantes e fixture
  reproduzível com colunas nomeadas, números/decimais suportados, nulos, datas
  e textos acentuados/Unicode. Definir representações esperadas antes das
  asserções; registrar restrições de runtime/tipo sem conversão silenciosa.
- [ ] **M04 — Homologar TCP Protheus.** Executar
  [U_HBBridgeQueryTest](src/tlpp/tests/protheus/hbbridgequerytest.tlpp) no alias
  MSSQL explícito, incluindo os 29 checks. Acrescentar casos de backend
  necessários ao produto/testes compartilhados, sem outra implementação Query.
- [ ] **M05 — Homologar HTTP Protheus.** Executar
  [U_HBBridgeHTTPTest](src/tlpp/tests/protheus/hbbridgehttptest.tlpp) com o mesmo
  alias MSSQL explícito e dataset comum. Conferir perfil/backend escolhido,
  valores e páginas; sucesso HTTP genérico não basta.
- [ ] **M06 — Verificar falhas e recuperação.** SQL inválido, perfil desconhecido,
  conexão indisponível controlada, timeout nativo aplicável, erros sem segredos
  e consulta seguinte bem-sucedida. Registrar chamadas de driver não
  interrompíveis; timeout/desconexão do cliente não significa cancelamento servidor.
- [ ] **M07 — Verificar concorrência e liberação.** Intercalar consultas/perfis
  e conferir restauração de workarea/conexão, ausência de mistura de resultados
  e limpeza após sucesso/falha. Preservar o contrato de sincronização atual.
- [ ] **M08 — Registrar referência de desempenho.** Identificar SQL, fixture/
  volume, quantidade de execuções e concorrência; registrar tempo e medições
  de memória disponíveis por Harbour, TCP e HTTP. É uma referência, sem
  garantia de velocidade nem novo limiar de desempenho.
- [ ] **M09 — Concluir regressões e documentação.** Executar checks adequados
  à implementação alterada, compilar TLPP modificado e obter aceite AppServer.
  Executar os três validadores de commit; atualizar instruções EN/PT, TODO,
  ChangeLog e homologação com evidências sanitizadas e versões dos artefatos.

### Critérios de conclusão

Encerrar somente com M01–M09 marcadas e evidências atribuíveis: MSSQL/backend/
configuração reais identificados, chamadas Harbour/TCP/HTTP bem-sucedidas,
valores/páginas, recuperação de falhas, isolamento/liberação e regressões
pertinentes. Cada marcação distingue código implementado, execução do agente
e execução do operador. Registrar limitações e próximos trabalhos sem deduzir
HTTPS, Linux, outros drivers ou tipos não suportados deste aceite Windows.
Qualquer alteração do escopo/critério obrigatório deve ser registrada antes do encerramento.

### Pré-requisitos atuais e nota para retomada

Endpoint/banco/ODBC/autenticação/configuração privada específicos ainda não
foram confirmados para este pacote. É um pré-requisito pendente, sem evidência
de conexão malsucedida. O ambiente Protheus informado usa MSSQL, mas seu
DBAccess não define um perfil de conexão hbBridge. Enquanto os dados do
ambiente estiverem pendentes, preparar tarefas independentes do próprio aceite.

Progresso/evidência: P01/P02 concluídas; tarefas MSSQL continuam pendentes.
Próxima ação: M01. Registrar novos progressos/evidências aqui em ambos os
idiomas; não reiniciar M01 quando suas informações estiverem registradas e válidas.

## Pacotes seguintes: direção reservada

| Ordem | Direção |
| --- | --- |
| 002 | Parâmetros/metadados SQL tipados e apresentação FWTemporaryTable/FWMBrowse; materialização/liberação MSSQL com escopo separado. |
| 003 | Dependências externas via hb_compile, provedores/gestão portável de credenciais, OpenBao opcional e homologação HTTPS. |
| 004 | Compressão/blocos negociados, consumo incremental e capacidades reais do cliente; persistência/pool após medições. |
| 005 | Homologação DBF/NETIO nativo e fachada TLPP para Harbour VF IO. |
| 006 | Serviço Windows/Linux, diagnóstico, administração e pacotes reproduzíveis. |
| Posteriores | Jobs/batches/progresso/cancelamento e extensões nativas úteis. |

São prioridades, sem especificações concluídas nem tarefas do pacote 001.
A RFC OpenBao do operador foi analisada em 2026-10-07 em
[credenciais](docs/credentials.pt-BR.md#provedor-openbao-opcional-análise-da-rfc-em-2026-10-07).
Continua como provedor futuro opcional para credenciais estáveis. Rotação
automática de senha SQL e plugins dinâmicos de banco ficam fora do escopo
inicial do pacote 003. Atualização manual continua possível quando necessária;
renovar token do cofre não altera a senha SQL. OpenBao não bloqueia o pacote MSSQL 001.
hbdebug pode avançar como item paralelo com escopo explícito; HBDAP e HTTP Zig
opcional ficam para depois. Correções/dependências necessárias ao pacote atual
entram em seu escopo registrado, sem abrir outra frente silenciosamente.

## Atualização e renovação do WIP

1. Ao iniciar trabalho do pacote, ler AGENTS, este WIP e somente o contexto
   referenciado necessário à próxima tarefa. Retomar pelo progresso registrado.
2. Atualizar marcações, evidências, pré-requisitos e próxima ação ao longo do
   pacote. Commits/publicações intermediários não reiniciam nem substituem WIP.
3. Reabrir decisão quando nova evidência, falha reproduzível, requisito/
   dependência alterados ou instrução explícita do usuário justificarem.
   Registrar motivo/impacto; um novo turno não exige repetir a análise.
4. Com os critérios atendidos, transferir resumo/evidências de encerramento
   para homologação e ChangeLog, conciliar TODO e registrar revisão final
   quando disponível. Preservar pendências como próximos trabalhos explícitos.
5. Renovar estes mesmos dois arquivos para o próximo pacote delimitado:
   ID/data, objetivo, referência, decisões, tarefas ordenadas, critérios,
   pré-requisitos e próxima ação. Git mantém versões anteriores; evitar copiar o TODO inteiro.

A renovação ocorre por **pacote de trabalho concluído**, não por commit,
publicação ou simples mudança de versão. Instruções do usuário podem alterar
a prioridade do pacote ativo; atualizar escopo/progresso sem descartar pendências.
