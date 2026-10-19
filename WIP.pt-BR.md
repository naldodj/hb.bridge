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
| Abertura / atualização | 2026-10-07 / 2026-10-18 |
| Situação | D02/M06/M07 mantêm seus aceites registrados. M08 concluída para a fixture Windows identificada: 43366 checks nativos do benchmark/0 e varreduras reais AppServer TCP/HTTP/0, com tempo e memória de processo pelo SO disponível. D03 e checks finais M09 continuam pendentes; pacote aberto. |
| Objetivo | Homologar RPCRDD.Query/dataset existentes em banco MSSQL real identificado, por Harbour, TCP Protheus e HTTP Protheus. |
| Referência do produto | Código publicado `50e1c65`; checkout na abertura `bce52d2` inclui atualização do badge de clones. |
| Próxima tarefa | V01/V02: validar benchmark visual, quatro rotas cliente e addon no servidor. Reutilizar um único REST 2.0 Protheus autenticado antes das medições; depois retomar M09. D03 permanece obrigatória para encerrar o pacote. |

### Decisões já tomadas

- Manter implementação única e contrato Query/páginas existentes. Usar
  SQLMIX/RDDSQL com SDDODBC; corrigir defeitos revelados por este aceite.
- Protheus resolve tenant/empresa/filial/xFilial, nomes de tabelas e regras de
  negócio. hbBridge executa SQL/parâmetros explícitos. Começar por SELECTs de
  constantes e fixture isolada de leitura; preservar tabelas ERP de produção.
- Perfis continuam aliases opacos selecionados explicitamente por chamada.
  `MSSQL/pData` é exemplo, sem perfil obrigatório nem resolução de contexto.
- Usar string ODBC completa privada ou chaves MSSQL estruturadas, com
  autenticação SQL/integrada explícita. Credenciais
  cifradas/CLI portáveis ficam para pacote posterior; sua implementação não é
  pré-requisito deste aceite.
- Esclarecido em 2026-10-07: as credenciais SQL são estáveis;
  rotação automática da senha do banco fica fora do escopo escolhido. KV OpenBao
  dispensa plugin MSSQL dinâmico. Renovação do token do cofre tem ciclo separado.
- Preservar o mutex compartilhado do ciclo SQL. Verificar isolamento/limpeza
  com chamadas concorrentes; este pacote não promete execução SQL paralela.
- Adaptar a posse de conexões aos leases lógicos de `HBBridgeSQLPool`, mantendo
  o ciclo de vida nativo RDDSQL por chamada. Reuso físico pertence ao ODBC
  Driver Manager nativo; é opcional e exige comprovação própria. SQLite
  `:memory:` mantém um banco novo a cada lease.
- Manter capacidades reais do runtime e políticas configuráveis, sem teto
  fixo de payload de prova de conceito nem novo transporte.
- Prioridade ajustada em 2026-10-13: adiar addons opcionais de metadados
  Protheus e reescrita decimal/CAST automática. Manter CAST no SQL do chamador
  e retomar falhas/recuperação independentes de M06. D03 UTF-8/FLOAT continua
  aberta; o pacote exige seu aceite de integridade, sem presumir correção por CAST.

### Ponto de partida verificado

- Suíte Harbour: **487 checks, zero falhas e nenhum skip**, repetida em 2026-10-07.
- Aceite SQLite manual no AppServer: **29 checks de dataset/páginas**, repetido em
  2026-10-07, thread 27136, perfil `sqlite_demo`.
- Configuração cliente revisada: **16 checks**, 2026-10-07, thread 30596.
- TCP manual no AppServer: relógio, Health, ADDON e os dois Echo exatos de 200000 bytes
  aprovados em 2026-10-07, thread 27084.
- Aceite HTTP TLPP manual no AppServer: **13 checks**, repetido em 2026-10-07,
  threads 27296 e 25456 após a recompilação informada.
  Perfil/backend SQL não informado; esse resultado não homologa MSSQL.
- Prova nativa THREAD STATIC: **31 asserções**; estado de worker difere do
  estado da requisição. O mutex SQL compartilhado continua intencional.
- Logs, escopo exato e detalhes do runtime estão na [homologação](docs/acceptance.pt-BR.md).

### Ajuste preparatório explícito: extensão dos fontes Harbour

Em 2026-10-07 foi autorizada a adoção de `.hb` nativo para todos os fontes
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
Informada a recompilação, seguida de execuções manuais aprovadas no AppServer
de TCP, SQLite, configuração revisada e HTTP. Evidências:
`tmp/protheus-http-hb-operator-20261007.log` e
`tmp/protheus-suite-hb-operator-20261007.log`; veja a [homologação](docs/acceptance.pt-BR.md).
A regressão TLPP preparatória está homologada nos casos exercitados. Retomar M01;
não repetir a migração concluída nem deduzir homologação MSSQL.

<a id="exemplo-preparatório-de-tabela-http-aceite-do-operador"></a>

### Exemplo preparatório de tabela HTTP: validação manual

- [x] **F01 — Homologar o exemplo de tabela HTTP FWWebEx.** Confirmada a
  validação como OK em 2026-10-13, com seis capturas da fixture constante e SX5.
  Resultados visíveis abrangem telas de 5/10 linhas, pesquisa global, filtro
  por igualdade em Description, totais filtrados/gerais e texto literal.
  Veja as [evidências](src/tlpp/tests/protheus/hbbridge.http.table.test/README.pt-BR.md)
  e a [homologação](docs/acceptance.pt-BR.md#tabela-http-fwwebex-validação-confirmada-em-2026-10-13).
  A preparação solicitada está concluída nas telas demonstradas. D02/D03
  mantêm suas tarefas específicas de execução mock e integridade dos dados.

- [x] **F02 — Corrigir e homologar a regressão da tabela HTTP.** Confirmada a
  execução manual de `U_HBBridgeHTTPTableTest` em 2026-10-13 às 17:46:56 São Paulo,
  thread 27708: **71 checks, zero falhas**, incluindo NUL nas extremidades/
  preservação da entrada, recuperação e totais. Consumidas as 19 respostas
  mock sem chamadas inesperadas. Encerradas as três falhas da rodada anterior
  de 62 checks; veja o [registro](docs/acceptance.pt-BR.md#validação-da-regressão-da-tabela-http-em-2026-10-13).
  Execução dataset/helpers tem aceite posterior em D02; integridade permanece em D03.

### Trabalho em ordem

Ampliada a análise em 2026-10-08 após os aceites HTTP: acesso ao
header/varredura automática do dataset, encoding/collation e tamanhos/decimais
lógicos. Uma prova com constantes revelou perda numérica FLOAT no JSON e a
inspeção dos fontes encontrou inconsistência de codepage TCP. São novas
constatações de aceite, sem motivo para repetir o inventário concluído.

- [x] **D01 — Revisar a interface consumidora.** Conferir exemplos locais
  FileRead/FileNavigator fornecidos; adotar `MoreToRead()` e métodos de metadados,
  preservando `Eof()`/`Skip()` locais à página. A API canônica atual é
  `Header()`; `DSStruct()` foi removido depois.
- [x] **D02 — Homologar a extensão TLPP do dataset.** Compilar/exercitar cópias
  de cabeçalho/campo/linha, ordem das colunas, varredura automática, verificações
  repetidas, vazio/fechado e falha/recuperação de página. Novos mocks sem dados ERP.
  Confirmada a validação manual no AppServer em 2026-10-13, São Paulo:
  `U_HBBridgeDataSetTest`, 17:56:23, thread 32332, **67 checks/31 chamadas mock**;
  `U_HBBridgeHelperTest`, 17:56:45, thread 28300, **12 checks**. Todos true,
  ambos os resultados OK. Veja [escopo/evidências](docs/acceptance.pt-BR.md#validação-do-dataset-e-helpers-em-2026-10-13).
  Homologado o contrato mock/interface; integridade textual/numérica nativa permanece em D03.
- [ ] **D03 — Corrigir integridade textual e numérica.** Garantir execução/
  transporte UTF-8 consistentes, conversão textual cliente explícita e binários;
  corrigir a perda FLOAT fracionária reproduzida no JSON e definir decimal
  exato/metadados nativos versus lógicos do chamador sem consultas ERP implícitas.
  Veja [constatações e contrato](docs/dataset.pt-BR.md). Os aceites ASCII/DECIMAL
  anteriores não homologam esses casos recém-identificados.
  As observações de apresentação em 2026-10-13 mantêm o exemplo HTTP funcional
  e validação desktop ampliada. Separar preservação FLOAT genérica da escala
  DECIMAL de negócio definida pelo chamador; CAST é projeção disponível,
  sem ser pré-requisito para transporte FLOAT genérico. Metadados lógicos
  explícitos seguem como extensão proposta. Veja a [análise](docs/dataset.pt-BR.md#escala-de-negócio-e-float-bruto-análise-em-2026-10-13).
  Addons de metadados e reescritor opcional da projeção SQL em TLPP/Zig adiados;
  sua [avaliação](docs/dataset.pt-BR.md#addon-de-metadados-e-reescrita-sql-adiados)
  não adiciona API/dependência nem bloqueia casos independentes de M06.
- [x] **S01 — Ampliar desenho de credenciais.** Abranger SQL, NETIO/admin e
  HTTP no hbBridge e segredos cliente locais do AppServer, chaves externas por
  instalação, provedores portáveis e suporte TLPP verificado separadamente.
  Criptografia permanece sem implementação; o [escopo](docs/credentials.pt-BR.md)
  registra o restante. Senhas SQL estáveis/atualizações manuais mantidas.

- [x] **M01 — Identificar o alvo.** Registrar alias SQL real, banco, endpoint,
  versão MSSQL, driver/versão/arquitetura ODBC, método de autenticação e
  identidade do processo hbBridge. Verificar acesso à configuração privada.
  Senhas, tokens e strings completas com credenciais ficam fora de Git/WIP.
- [x] **M02 — Preparar aceite reproduzível.** Usar o [launcher SQL](examples/sql/README.pt-BR.md)
  e INI/JSON privado. Preparar uma rota de teste MSSQL real opt-in, separada da
  suíte SQLite padrão. Falta de conector/configuração obrigatória é falha de
  pré-requisito, nunca teste MSSQL bem-sucedido. Identificar o backend no resultado.
- [x] **M03 — Homologar SQL Harbour.** Executar SELECTs de constantes e fixture
  reproduzível com colunas nomeadas, números/decimais suportados, nulos, datas
  e textos acentuados/Unicode. Definir representações esperadas antes das
  asserções; registrar restrições de runtime/tipo sem conversão silenciosa.
- [x] **M04 — Homologar TCP Protheus.** Executar
  [U_HBBridgeQueryTest](src/tlpp/tests/protheus/hbbridge.query.test/hbbridge.query.test.tlpp) no alias
  MSSQL explícito, incluindo os 29 checks. Acrescentar casos de backend
  necessários ao produto/testes compartilhados, sem outra implementação Query.
- [x] **M05 — Homologar HTTP Protheus.** Executar
  [U_HBBridgeHTTPTest](src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp) com o mesmo
  alias MSSQL explícito e dataset comum. Conferir perfil/backend escolhido,
  valores e páginas; sucesso HTTP genérico não basta.
- [x] **M06 — Verificar falhas e recuperação.** Homologada em 2026-10-14:
  SQL inválido, perfil desconhecido, porta loopback reservada sem listener,
  timeout nativo MSSQL de um segundo por instrução, erros seguros exatos e
  recuperação seguinte. Nativo local/NETIO/TCP/HTTP: **46 checks**; execução
  automatizada do RPO no AppServer CLI: **38 TCP / 51 HTTP checks**, cada
  transporte com 21 chamadas; **zero falhas**, saída 0. Regressão padrão:
  **636 checks**; repetição MSSQL nativa: **92**. Compilados os 30 fontes TLPP
  com zero erros de fonte. A validação manual AppServer às 14:30:50 São Paulo,
  thread 13796, também aprovou todos os **38 TCP / 51 HTTP checks**, resolvendo
  as sete falhas anteriores por transporte. [Escopo/evidências manuais](docs/acceptance.pt-BR.md#manual-protheus-failure-recovery-on-2026-10-14). Veja
  [escopo, artefatos e limitações](docs/acceptance.pt-BR.md#sql-native-timeouts-and-appserver-recovery-on-2026-10-14)
  e o [guia de testes](src/tlpp/tests/protheus/hbbridge.failure.test/README.pt-BR.md).
  Timeouts opcionais de login/instrução pertencem ao perfil MSSQL; zero
  desativa a opção nativa e omissão preserva o padrão do driver. Cada instrução,
  inclusive COUNT, tem timeout próprio. Isso não impõe prazo global à requisição
  nem implementa cancelamento após timeout/desconexão do cliente.
- [x] **M07 — Verificar concorrência e liberação.** Baseline homologada em
  2026-10-14; complemento sob carga homologado em 2026-10-15 nos escopos
  nativo Windows e de resumos manuais exercitados abaixo. Preservar as
  evidências intermediárias de falhas com 140 workers:
  nativo **458 checks, 8 workers/192 chamadas**, local/NETIO/TCP/HTTP e três
  aliases; AppServer CLI **417 checks, 4 jobs/112 chamadas**, dois jobs TCP e
  dois HTTP alternando MSSQL/SQLite. Zero falhas; verificadas áreas/conexão
  padrão, reuso de handles nativos, isolamento de perfil/schema/valores,
  recuperação e limpeza própria. Manter mutex SQL; não homologa consultas
  paralelas no banco nem ausência de vazamentos físicos ODBC/heap.
  [Evidências](docs/acceptance.pt-BR.md#sql-concurrency-and-release-on-2026-10-14).
  Logs manuais adicionais informam 40/100 workers sem falhas; somente dois
  usam TCP ao aumentar a carga. Em 2026-10-15, os controles independentes de
  coleta/limpeza passaram nos 417 checks com quatro workers e drenaram um
  aborto controlado de um segundo. Com prazo de 300 segundos, retornaram os
  140 relatos/3920 chamadas: **16329 checks, 857 falhas**, incluindo status
  zero com diagnóstico nativo de recusa. Os 32 fontes TLPP compilaram sem
  erros de fonte; depois, o compilador do fornecedor saiu com **0xC0000409**,
  registrado separadamente da compilação.
  A regressão nativa anterior passou em **656 checks, zero falhas** com backlog HTTP
  configurável; tanto backlog 10 quanto o padrão do SO falharam com 140 workers.
  Isso não homologa uma correção por backlog.
  O anexo fornecido de 22 KB contém proposta de pool e erro ODBC 10048 do DBAccess,
  não um teste aprovado. Contagens elevadas de TIME_WAIT e dois eventos Windows
  Tcpip 4227 registram pressão de portas no host, sem atribuir a um processo
  ou comprovar a causa única das falhas HTTP.
  A proposta foi adaptada a `HBBridgeSQLPool`: leases lógicos em hash contêm
  ID único, perfil, thread proprietária e conexão nativa. Devoluções forjadas,
  obsoletas, duplicadas ou por outra thread são rejeitadas; aquisição não tem
  laço de repetição e encerramento recusa leases ativos. Reconfigurar a política
  ODBC preserva a instância da fachada. Conexões lógicas mantêm seu ciclo por
  chamada e bancos SQLite em memória continuam novos. Passaram build isolado
  do produto, **266 checks de leases/configuração** e a regressão nativa
  completa de **712 checks**, com zero falhas.
  A política física do Driver Manager tem padrão `off`. `driver` é uma opção
  Windows com ODBC 3.8; Linux permanece `off` até homologação própria.
  A primeira tentativa de reuso físico MSSQL
  abriu 13 conexões físicas distintas para 13 leases lógicos. Manter o ambiente
  ODBC do processo demonstrou depois reuso aquecido e limpeza de configurações,
  tabelas temporárias, transações e banco selecionado na mesma conexão física;
  o aceite isolado final passou em **61 checks/0** em cada processo separado
  `driver` e `off`. Após dois leases de aquecimento frio usarem duas conexões
  físicas, os 13 leases medidos em `driver` reutilizaram uma conexão TCP física;
  `off` usou 13. A suíte nativa com pooling de oito workers/192 chamadas passou
  em **458 checks/0**, incluindo isolamento e liberação. Linux, autenticação
  integrada e perfil opcional de segundo banco para pooling não foram
  exercitados. Os resumos manuais não identificam essa adaptação nativa nem
  estabelecem que ela causou o sucesso das suas rodadas.
  Informada execução de 125 workers sem falhas, sem análise do log completo.
  O log completo de 130 workers foi analisado: todos os 130 relatos/3640
  chamadas, **15159 checks/41 falhas**. Treze recusas HTTP na etapa 4 causaram
  33 assertivas dos workers e oito checks do pai indicando falhas; os TCP
  passaram. Não há THREAD ERROR. As recusas ocorreram em 460 ms, sem expiração
  do orçamento do teste.
  Resumos posteriores de **5/15/20/30/150/500 workers** informam todos os jobs
  coletados e **83934 checks, zero falhas**; a rodada de 500 informa **58449/0**.
  Homologado o escopo exercitado desses resumos com espaçamento. Faltam rastros
  individuais, duração real e identificação do binário/pool; os resumos não
  comprovam essas propriedades separadamente nem estabelecem a causa anterior.
  O espaçamento agora é explícito nos argumentos 10–12/CLI: os padrões
  300/50/5000 ms preservam a rampa fornecida e `GetEnvServer()`. As pausas
  planejadas somam 431450 ms com 130 workers e 481450 ms com 140; `0/0/0`
  fornece um controle sem pausas. O orçamento inclui lançamento e planos de
  pausas inviáveis são rejeitados antes de `StartJob`; a barreira READY/GO de
  todos os workers ainda libera o trabalho em conjunto. Os resumos posteriores
  incluem esses campos explícitos, registrando execução manual dessa revisão
  de relatório. Não foi fornecido novo recibo de compilação; o resultado
  anterior de 32 fontes precede o espaçamento configurável.
  [Evidências ODBC nativas](docs/acceptance.pt-BR.md#odbc-physical-reuse-on-2026-10-15),
  [complemento histórico](docs/acceptance.pt-BR.md#sql-concurrency-follow-up-on-2026-10-15)
  e [evidências manuais com espaçamento](docs/acceptance.pt-BR.md#manual-protheus-concurrency-on-2026-10-15)
  mantêm seus escopos separados. M08 tem aceite posterior abaixo; checks finais M09 permanecem pendentes.
- [x] **M08 — Registrar referência de desempenho.** Concluída em 2026-10-16
  com a fixture comum somente de leitura `m08.constant.v1`: 1000 linhas,
  páginas de 100, dois aquecimentos e cinco varreduras completas medidas,
  concorrência um. Harbour direto/TCP/HTTP nativos em processos separados
  com políticas off/driver passaram em 43366 checks do benchmark, zero falhas;
  há amostras working/private do SO na fase medida das seis rotas. AppServer
  TCP e HTTP reais passaram nas cinco varreduras medidas de cada um,
  50 chamadas/5000 linhas por rota, além dos aquecimentos, saída 0. Memória
  externa de cliente/servidor cobre o ciclo AppServer combinado e mantém esse
  escopo. Os 34 fontes TLPP compilaram sem erros de fonte; finalização do
  compilador do fornecedor retornou 0xC0000409; serviços restaurados e execução
  real aprovadas separadamente. Sem limiar de velocidade, ranking de rotas,
  aceite Linux/vazamentos ou integridade D03. [Metodologia](docs/benchmarking.pt-BR.md)
  e [resultados/artefatos](docs/acceptance.pt-BR.md#m08-performance-baseline-on-2026-10-16).
  Resumo manual adicional às 04:53:47 São Paulo aprovou as cinco varreduras
  medidas e dois aquecimentos por rota, médias 1039.60 ms TCP/1122.12 ms HTTP.
  Manter memória não medida e pool/build/saída não informados em escopo separado.
  [Evidência manual](docs/acceptance.pt-BR.md#m08-manual-protheus-validation-on-2026-10-16).
- [ ] **V01 — Adicionar benchmark visual e verificar ciclo do cliente.**
  Reutilizar o núcleo M08 em formulário FWWebEx com gráficos e exportação
  JSON/HTML. Perfil/endpoints/credenciais ficam no controlador confiável do
  servidor. Substituir o socket estático provisório por um componente nativo
  reutilizado por cliente, fechamento explícito e checks de independência e
  recuperação. A rodada manual ampliada concluiu as 500 iterações TCP, mas
  falhou na primeira chamada da iteração HTTP 136, após 135 sucessos, em
  30020.834 ms. O relatório antigo não registra código de serviço/status HTTP;
  adicionar diagnóstico seguro antes de atribuir causa. Essa carga nova não
  invalida a referência M08 menor nem homologa a rodada ampliada completa.
  Registrar compilação, testes CLI e navegador separadamente do aceite
  interativo FWWebEx.
- [ ] **V02 — Comparar onde executar.** Solicitação explícita de 2026-10-16/18:
  comparar hbBridge TCP/HTTP com DBAccess via StartJob e REST 2.0 Protheus,
  usando a mesma fixture/páginas/COUNT e checks do dataset. Adicionar HRB que
  consome páginas no próprio hbBridge e devolve somente métricas; separar
  tempo de varredura no servidor do tempo total da chamada. Credenciais ERP
  ficam na configuração confiável do AppServer. Reutilizar porta 4323,
  Security=1 e um worker, sem listener adicional/provedor bearer próprio.
  Efetuado backup do INI ativo antes da consolidação autorizada. Verificar
  credenciais ausentes/incorretas/válidas no framework real e registrar
  evidências. Manter limites do executor genérico e D03/M09 abertas.
- [ ] **M09 — Concluir regressões e documentação.** Executar checks adequados
  à implementação alterada, compilar TLPP modificado e obter aceite AppServer.
  Executar os três validadores de commit; atualizar instruções EN/PT, TODO,
  ChangeLog e homologação com evidências sanitizadas e versões dos artefatos.

### Critérios de conclusão

Encerrar somente com M01–M09 marcadas e evidências atribuíveis: MSSQL/backend/
configuração reais identificados, chamadas Harbour/TCP/HTTP bem-sucedidas,
valores/páginas, recuperação de falhas, isolamento/liberação e regressões
pertinentes. Cada marcação distingue código implementado, verificações locais
automatizadas e execução manual no AppServer. Registrar limitações e próximos
trabalhos sem deduzir HTTPS, Linux, outros drivers ou tipos não suportados deste
aceite Windows.
Qualquer alteração do escopo/critério obrigatório deve ser registrada antes do encerramento.

### Pré-requisitos atuais e nota para retomada

O inventário local somente de leitura identificou a instância padrão
`MSSQLSERVER` ativa, escutando em TCP 1433. O DSN ODBC `pData` de 64 bits aponta
para `(local)` e banco `pData`. Microsoft ODBC Driver 18 for SQL Server instalado, versão
do produto **18.6.2.1**, x64; Driver 17 também disponível. Identidade do console:
`DNA-TECH-01\marin`; identidades de serviço exigem homologação separada.

Selecionado um INI privado para preenchimento local, sem conexão pronta.
`C:/tmp/hbBridge.ini` continha inicialmente apenas o perfil SQL `sqlite_demo`.
Em 2026-10-08 foi acrescentado um modelo comentado `MSSQL/pData`, com backup
privado e preservação byte a byte das configurações existentes. Ele usa DSN
`pData` instalado, `Authentication=sql` explícita e campos `Username`/`Password`
vazios para preenchimento local e remoção dos comentários. A
política local explícita `Encrypt=optional` acompanha o DSN de desenvolvimento;
TLS de uma instalação exige sua configuração de certificado. Nenhuma credencial
SQL foi lida do DBAccess, alterada no ODBC ou guardada no repositório.

O perfil foi habilitado e as credenciais foram preenchidas localmente durante
este trabalho.
A configuração estruturada foi validada sem exibir valores. Uma prova somente
de leitura com `System.Data.Odbc`, as credenciais privadas e autenticação SQL
conectou ao **SQL Server 16.0.1200.5**, banco **pData**, em 2026-10-08.
M01 está concluída. Nenhuma credencial foi alterada ou copiada ao repositório.

A rota nativa dedicada compilou. Quatro casos controlados de argumento/
configuração/perfil ausente ou backend incorreto retornaram saída 2, sem abrir
conexão SQL. M02 está concluída. A rota opt-in é
`scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData`;
compila componentes compartilhados independentemente do host instalado e
informa falta de pré-requisito com saída 2. Sua primeira conexão nativa real
retornou `CONNECTION_FAILED`: uma comparação reproduziu Driver Manager `IM002`
com `DSN={pData}` e conectou com `DSN=pData` sem chaves. Essa serialização
foi corrigida mantendo o escape de credenciais. O serializador corrigido
conectou nativamente. As fixtures revelaram então o tratamento incorreto de
`SQL_NO_TOTAL` pelo SDDODBC na conversão VARCHAR/Unicode e um erro de flag
binária. Um patch verificado do conector em cópia gerenciada preserva dados
variáveis, vazio/nulo e blocos UTF-16, sem alterar o checkout fixado original.
O patch do conector também converte pares substitutos UTF-16 em UTF-8 válido,
inclusive quando separados entre blocos. Em 2026-10-08 a fixture nativa passou
em **92 checks, zero falhas/sem skips**, incluindo VARCHAR/NVARCHAR/binários
longos, NUL embutido, vazio/nulo, Unicode suplementar, datas/timestamps,
paginação, recuperação, restauração dos recursos do chamador e quatro workers
sem mistura de resultados. Evidências:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log` e
`tmp/mssql-native-normalized-20261008.log`. M03 concluída neste alvo Windows.
A referência do núcleo leu 1000 linhas constantes em três execuções:
31/32/31 ms, total 94 ms, concorrência 1, incluindo conexão/materialização/
desconexão; memória não medida. Naquela etapa M06/M07 tinham evidência parcial.
M06 tem aceite posterior em 2026-10-14; isolamento ampliado de perfis de M07
tem aceite posterior registrado abaixo.
M08 tem aceite posterior TCP/HTTP e memória em 2026-10-16, registrado acima. A regressão padrão passou em **566 checks,
zero falhas/sem skips**: `tmp/tests-f84004277a8d4cc2905131f706a1e181/results.log`.

Informadas execuções TCP manuais no AppServer em 2026-10-08, horário de São Paulo:
`U_HBBridgeQueryTestMSSQL`, 10:06:10, thread 660, perfil `MSSQL/pData`, e
`U_HBBridgeQueryTestSQLite`, 10:06:43, thread 3192, perfil `sqlite_demo`.
Ambos os relatos contêm os 29 checks verdadeiros. Acrescentados esses
wrappers ao teste TLPP existente; seus padrões continuam somente nos testes,
sem alterar o alias SQL opcional do produto. Evidência:
`tmp/protheus-mssql-sqlite-operator-20261008.log`. M04 homologada nos casos
exercitados; sem novo log de compilador ou hash do artefato servidor fornecido.

Informadas também execuções HTTP manuais no AppServer em 2026-10-08, horário
de São Paulo:
`U_HBBridgeHTTPTestMSSQL`, programa 10:33:32, thread 25976, corpo 10:33:33–34,
e `U_HBBridgeHTTPTestSQLite`, programa 10:34:06, thread 9916, corpo 10:34:07.
Ambas contêm os 13 checks true/PASS e Health HTTP 200. Os wrappers acrescentados
e conferidos no fonte definem `MSSQL/pData` e `sqlite_demo`,
respectivamente, encaminhando ao teste HTTP comum; padrões da biblioteca preservados.
Evidência: `tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
M05 homologada nesses casos. A duração informada de 1 s/0 s tem resolução de
segundos inteiros e não substitui as medições de M08. Sem log de compilador,
argumentos explícitos da chamada ou hash do artefato servidor fornecidos.
HTTPS, transporte ampliado de tipos nativos e Linux têm aceites separados.

Progresso/evidência: P01/P02/F01/F02/D02 e M01–M06 concluídas nos casos exercitados.
O aceite automatizado TCP/HTTP no AppServer em 2026-10-14 sucede a recompilação;
passaram a suíte nativa de falhas, regressão padrão e repetição MSSQL de 92 checks.
A nova consulta identifica SQL Server **16.0.1210.3**; 16.0.1200.5 permanece
como resultado histórico de 2026-10-08.
O teste anterior no servidor comum teve sete falhas por transporte porque
seu INI não continha os aliases da fixture; consultas confirmaram PROFILE_NOT_FOUND.
A execução manual posterior às 14:30:50 São Paulo, thread 13796, aprovou todos
os 38 TCP/51 HTTP checks e resolve aquela rodada no escopo de M06. Diagnósticos
nativos de handshake permanecem registrados sem causa/resolução comprovada;
não foram inferidos duração precisa nem acionamento por interface gráfica.
Os 458 checks nativos e 417 checks AppServer CLI permanecem a baseline histórica aceita
de M07. A repetição controlada com 140 workers em 2026-10-15 continuou falhando
após validar controles independentes de coleta/limpeza. Análises de reuso de
conexões, pressão de portas e aceite do ciclo lógico/físico adaptado concluíram
depois M07 no escopo Windows registrado. As falhas com 130 foram analisadas;
resumos posteriores com espaçamento até 500 workers estão homologados no seu
escopo. A referência de tempo/memória M08 foi concluída em 2026-10-16; retomar M09.
Preservar mutex SQL e distinguir requisições concorrentes de execução paralela
no banco. Integridade D03 continua
pendente após o ajuste explícito da prioridade, mantendo CAST no chamador.
Sem nova evidência que exija revisão, não repetir migração, inventário ou
casos nativos/TCP/HTTP homologados. M09, D03 e critérios do pacote permanecem.

A [observação de reuso de conexões SQL](docs/sql-connections.pt-BR.md) de
2026-10-12 foi repriorizada para M07 em 2026-10-15. `HBBridgeSQLPool` agora
controla leases lógicos exclusivos sob o mutex de ciclo de vida existente.
O reuso físico ODBC nativo passou no aceite MSSQL Windows, com política
padrão `off` e opção `driver`. Manter a comprovação de identidade física/
limpeza de sessão separada dos resumos manuais e da persistência RPC futura.

## Pacotes seguintes: direção reservada

A [análise de extensões](docs/extensions-review.pt-BR.md) de 2026-10-12 registra
SQLRDD, Duktape e CCHarbour como pacotes opcionais posteriores, sem adotar
dependências nem reiniciar este pacote. O [guia de exemplos](examples/protheus/README.pt-BR.md)
catalogou consumidores atuais. A regressão nativa passou 583 checks sem falhas;
browses nativos/UI restantes continuam pendentes. As telas de tabela HTTP,
seu mock de 71 checks e execuções dataset/helpers de 67/12 checks têm aceite próprio acima.
UTF-8/FLOAT e implementação de credenciais cifradas continuam pendentes.

| Ordem | Direção |
| --- | --- |
| 002 | Parâmetros/metadados SQL tipados e apresentação FWTemporaryTable/FWMBrowse; materialização/liberação MSSQL com escopo separado. |
| 003 | Dependências externas via hb_compile, provedores/gestão portável de credenciais, OpenBao opcional e homologação HTTPS. |
| 004 | Compressão/blocos negociados, consumo incremental e capacidades reais do cliente; persistência/pool RPC após medições. |
| 005 | Homologação DBF/NETIO nativo e fachada TLPP para Harbour VF IO. |
| 006 | Serviço Windows/Linux, diagnóstico, administração e pacotes reproduzíveis. |
| Posteriores | Jobs/batches/progresso/cancelamento e extensões nativas úteis. |

São prioridades, sem especificações concluídas nem tarefas do pacote 001.
A RFC OpenBao fornecida foi analisada em 2026-10-07 em
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
