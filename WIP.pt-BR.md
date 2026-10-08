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
| Abertura / atualização | 2026-10-07 / 2026-10-08 |
| Situação | MSSQL nativo homologado: 92 checks; Protheus TCP: 29 e HTTP: 13 em cada banco MSSQL/SQLite. Pacote permanece aberto. |
| Objetivo | Homologar RPCRDD.Query/dataset existentes em banco MSSQL real identificado, por Harbour, TCP Protheus e HTTP Protheus. |
| Referência do produto | Código publicado `50e1c65`; checkout na abertura `bce52d2` inclui atualização do badge de clones. |
| Próxima tarefa | Aceite da API dataset solicitada e correções UTF-8/FLOAT abaixo; depois retomar M06. |

### Decisões já tomadas

- Manter implementação única e contrato Query/páginas existentes. Usar
  SQLMIX/RDDSQL com SDDODBC; corrigir defeitos revelados por este aceite.
- Protheus resolve tenant/empresa/filial/xFilial, nomes de tabelas e regras de
  negócio. hbBridge executa SQL/parâmetros explícitos. Começar por SELECTs de
  constantes e fixture isolada de leitura; preservar tabelas ERP de produção.
- Perfis continuam aliases opacos selecionados explicitamente por chamada.
  `mssql/pData` é exemplo, sem perfil obrigatório nem resolução de contexto.
- Usar string ODBC completa privada ou chaves MSSQL estruturadas, com
  autenticação SQL/integrada explícita. Credenciais
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

O responsável ampliou a análise em 2026-10-08 após os aceites HTTP: acesso ao
header/varredura automática do dataset, encoding/collation e tamanhos/decimais
lógicos. Uma prova com constantes revelou perda numérica FLOAT no JSON e a
inspeção dos fontes encontrou inconsistência de codepage TCP. São novas
constatações de aceite, sem motivo para repetir o inventário concluído.

- [x] **D01 — Revisar a interface consumidora.** Conferir exemplos locais
  FileRead/FileNavigator fornecidos; adotar `MoreToRead()` e métodos de metadados,
  preservando `Eof()`/`Skip()` locais à página e `DSStruct()` do usuário.
- [ ] **D02 — Homologar a extensão TLPP do dataset.** Compilar/exercitar cópias
  de cabeçalho/campo/linha, ordem das colunas, varredura automática, verificações
  repetidas, vazio/fechado e falha/recuperação de página. Novos mocks sem dados ERP.
  Implementação e fixture de 45 checks preparados. A tentativa de compilação de
  2026-10-08 falhou antes de compilar os fontes: `COMPILEERROR-300`, RPO custom
  em uso (`tmp/totvs-compile.log`, thread 36788). Aceite de execução pendente.
- [ ] **D03 — Corrigir integridade textual e numérica.** Garantir execução/
  transporte UTF-8 consistentes, conversão textual cliente explícita e binários;
  corrigir a perda FLOAT fracionária reproduzida no JSON e definir decimal
  exato/metadados nativos versus lógicos do chamador sem consultas ERP implícitas.
  Veja [constatações e contrato](docs/dataset.pt-BR.md). Os aceites ASCII/DECIMAL
  anteriores não homologam esses casos recém-identificados.
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
  [U_HBBridgeQueryTest](src/tlpp/tests/protheus/hbbridgequerytest.tlpp) no alias
  MSSQL explícito, incluindo os 29 checks. Acrescentar casos de backend
  necessários ao produto/testes compartilhados, sem outra implementação Query.
- [x] **M05 — Homologar HTTP Protheus.** Executar
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

O inventário local somente de leitura identificou a instância padrão
`MSSQLSERVER` ativa, escutando em TCP 1433. O DSN ODBC `pData` de 64 bits aponta
para `(local)` e banco `pData`. Microsoft ODBC Driver 18 for SQL Server instalado, versão
do produto **18.6.2.1**, x64; Driver 17 também disponível. Identidade do console:
`DNA-TECH-01\marin`; identidades de serviço exigem homologação separada.

O operador escolheu preencher um INI privado, sem conexão pronta.
`C:/tmp/hbBridge.ini` continha inicialmente apenas o perfil SQL `sqlite_demo`.
Em 2026-10-08 foi acrescentado um modelo comentado `mssql/pData`, com backup
privado e preservação byte a byte das configurações existentes. Ele usa DSN
`pData` instalado, `Authentication=sql` explícita e campos `Username`/`Password`
vazios para preenchimento local e remoção dos comentários pelo operador. A
política local explícita `Encrypt=optional` acompanha o DSN de desenvolvimento;
TLS de uma instalação exige sua configuração de certificado. Nenhuma credencial
SQL foi lida do DBAccess, alterada no ODBC ou guardada no repositório.

O operador habilitou o perfil e preencheu as credenciais durante este trabalho.
A configuração estruturada foi validada sem exibir valores. Uma prova somente
de leitura com `System.Data.Odbc`, as credenciais privadas e autenticação SQL
conectou ao **SQL Server 16.0.1200.5**, banco **pData**, em 2026-10-08.
M01 está concluída. Nenhuma credencial foi alterada ou copiada ao repositório.

A rota nativa dedicada compilou. Quatro casos controlados de argumento/
configuração/perfil ausente ou backend incorreto retornaram saída 2, sem abrir
conexão SQL. M02 está concluída. A rota opt-in é
`scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData`;
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
desconexão; memória não medida. M06/M07 têm evidência parcial; conexão
indisponível/timeout nativo controlados e isolamento ampliado de perfis faltam.
M08 ainda exige TCP/HTTP e memória. A regressão padrão passou em **566 checks,
zero falhas/sem skips**: `tmp/tests-f84004277a8d4cc2905131f706a1e181/results.log`.

O operador forneceu execuções TCP em 2026-10-08, horário de São Paulo:
`U_HBBridgeQueryTestMSSQL`, 10:06:10, thread 660, perfil `mssql/pData`, e
`U_HBBridgeQueryTestSQLite`, 10:06:43, thread 3192, perfil `sqlite_demo`.
Ambos os relatos contêm os 29 checks verdadeiros. O operador acrescentou esses
wrappers ao teste TLPP existente; seus padrões continuam somente nos testes,
sem alterar o alias SQL opcional do produto. Evidência:
`tmp/protheus-mssql-sqlite-operator-20261008.log`. M04 homologada nos casos
exercitados; sem novo log de compilador ou hash do artefato servidor fornecido.

O operador também forneceu execuções HTTP em 2026-10-08, horário de São Paulo:
`U_HBBridgeHTTPTestMSSQL`, programa 10:33:32, thread 25976, corpo 10:33:33–34,
e `U_HBBridgeHTTPTestSQLite`, programa 10:34:06, thread 9916, corpo 10:34:07.
Ambas contêm os 13 checks true/PASS e Health HTTP 200. Os wrappers acrescentados
pelo operador e conferidos no fonte definem `mssql/pData` e `sqlite_demo`,
respectivamente, encaminhando ao teste HTTP comum; padrões da biblioteca preservados.
Evidência: `tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
M05 homologada nesses casos. A duração informada de 1 s/0 s tem resolução de
segundos inteiros e não substitui as medições de M08. Sem log de compilador,
argumentos explícitos da chamada ou hash do artefato servidor fornecidos.
HTTPS, transporte ampliado de tipos nativos e Linux têm aceites separados.

Progresso/evidência: P01/P02 e M01–M05 concluídas nos casos exercitados.
Tratar D02/D03 da nova solicitação antes de retomar M06 com conexão
indisponível/timeout nativo controlados, erros sanitizados e recuperação;
SQL inválido/perfil desconhecido já têm evidências no núcleo e TCP.
Sem nova evidência que exija revisão, não repetir migração, inventário ou
casos nativos/TCP/HTTP homologados. M07–M09 e critérios do pacote permanecem.

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
