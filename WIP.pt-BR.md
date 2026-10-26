# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

Retome a próxima tarefa pendente deste pacote delimitado. Commits/publicações
intermediários não o reiniciam. Renove o par com os critérios atendidos e
registre o encerramento na homologação e no ChangeLog.

## Pacote anterior: 001 concluído em 2026-10-21

Homologação MSSQL real concluiu M01–M09, D01–D03 e V01/V02 no escopo
Windows/AppServer identificado. Checks nativos finais: **752 / 92 / 73**, zero
falhas. TLPP: **49 fontes**, zero erros/saída 0, mais o último helper JSON
compilado e homologado separadamente. AppServer real final: **31 JSON / 80
TCP+HTTP checks**, zero falhas/saída 0. Mutex SQL, posse lógica por chamada e
pooling físico ODBC opcional preservados. Sem inferir suporte geral a Linux,
HTTPS ou BLOB JSON. Veja [encerramento, artefatos e limites](docs/acceptance.pt-BR.md#package-001-m09-closure-on-2026-10-21).

## Pacote 002: parâmetros SQL tipados, metadados e apresentação nativa

| Item | Valor atual |
| --- | --- |
| ID | `002-typed-sql-presentation` |
| Abertura / atualização | 2026-10-21 / 2026-10-26 |
| Situação | T01–T04 validadas nos escopos registrados. A apresentação nativa local T05 preserva armazenamento indexado entre páginas, usa FWBulk quando disponível e expõe dados sintéticos configuráveis com ordenação ID_CODE. Checks revisados e resultados manuais registrados abaixo. Homologação conjunta backend/UI continua aberta. |
| Objetivo | Definir valores SQL/metadados tipados explícitos e adapter de apresentação nativa pertencente ao chamador Protheus sobre Query/dataset homologados. |
| Referência | Base `8db2823`; artefatos da árvore de trabalho validados no pacote 001 identificados no manifesto de encerramento. Não é nova tag de release. |
| Próxima tarefa | T05: validar execução conjunta AppServer TCP/HTTP/backend real e apresentação nativa interativa; depois encerrar o pacote. |

### Manutenção preparatória

- [x] 2026-10-21: revisar fontes próprios conforme AGENTS: agrupar declarações por tipo,
  preservar ordem das inicializações e antecipar invariantes comprovados.
  Corrigida a referência ao parâmetro de token ignorado, com dois novos checks
  de regressão. Checks nativos, AppServer real e crivos do repositório aprovados;
  veja as [evidências dessa revisão](docs/acceptance.pt-BR.md#source-conventions-review-on-2026-10-21).
  A manutenção não implementa T01; T01 permanece como próxima tarefa.

- [x] 2026-10-22: adicionar [script de limpeza de artefatos](scripts/README.pt-BR.md#limpeza-de-artefatos)
  solicitado, com simulação/aplicação explícita, caminhos delimitados e idade.
  Alinhar tmp inteiramente descartável, sem retenção por docs/manifests/ponteiros.
  Versionar runners, probes e [resumos históricos](docs/validation/README.pt-BR.md).
  Validação: 22 fixtures aprovadas, incluindo ausência de tmp/out; simulações
  reais sem exclusões. Probe versionado: 31 asserções aprovadas.
  Registrar convenção mínima de includes TLPP e preservar
  fontes de benchmark revisados. Manter T01 planejado.

- [x] 2026-10-22/23: implementar e validar automaticamente manutenção de confiabilidade/controle do benchmark
  explicitamente solicitada antes de retomar T01: execução real de rotas
  isoladas por seleção CLI/TLPP/visual compatível, dependências somente das
  rotas escolhidas, estados ignorado/falha explícitos e estatísticas das
  amostras medidas. Manter configuração de destino/perfil/módulo/autenticação
  confiável; separar varreduras cliente dos tempos internos/RPC do addon e
  internos/job completo do Protheus. Adicionar `protheusServer` opcional
  (um StartJob para todas as varreduras), normalizar mapas antigos de cinco
  rotas e preservar requisições anteriores com cinco/seis campos. Estimar
  timeout automático pela carga/páginas, com teto editável de 900s, modo manual
  explícito e política efetiva própria do relatório.
  Compilar e verificar cenários determinísticos, de navegador e AppServer
  real antes de registrar aceite. Essa repriorização não implementa contratos
  SQL/apresentação de T01. Veja o [guia do benchmark](docs/benchmarking.pt-BR.md#seleção-de-rotas-e-estatísticas-medidas).
  Evidência atual: compilação isolada de 54 fontes TLPP aprovada, zero erros/
  saída 0; AppServer isolado aprovou controle/visual/REST/JSON com 82/81/43/31. Teste
  MSSQL de correção em um job aprovado (10 linhas, página 5, duas medidas +
  um aquecimento). Suítes nativas completa/addon pós-codec: 752/93, com
  precisão/ABI e TCP 254/255/256/500 exatos com SQL simulado/sem pausas.
  Compilação TLPP final: 54 fontes, zero erros/saída 0.
  Chromium principal: 3 suítes, 69 observações de DOM + 30 de servidor/timeout/
  layout. Prévia opcional do relatório também passou com rede da página bloqueada. Em 2026-10-23, diagnosticar falha fornecida de 255
  iterações e reprodução TLPP/SQL simulado com 500 como arredondamento da média
  JSON na ABI addon/host sob SET DECIMALS 2, sem limite de iterações. Checks de
  amostras retornadas passam; falha somente a precisão dos agregados. Chamada
  fornecida: 87.9255s frente ao prazo de 900s. Usar HBBridgeJSONEncode/Decode
  existentes na ABI, manter validação estrita e remover pausas de 1.5s que
  alteravam apenas ritmo. Host/HRB recompilados e cliente TLPP real passaram
  255 medidas mais dois aquecimentos e 500 mais zero contra host/HRB TCP reais
  e Query simulado, preservando agregados estritos. Separar fixture Windows de
  outras plataformas. MSSQL255 real também passou com TLPP/TCP/HRB,
  1000 linhas/página100, dois aquecimentos, agregados estritos, pooling off/
  sem pausas. Tentativa automática de 500 iterações separada esgotou o prazo do executor
  próprio; é inconclusiva, sem resumo AppServer aprovado. Evidência FWWebEx1500
  fornecida segue abaixo, sem identificar fontes/pooling. T01 permanece planejada.

- [x] 2026-10-23: revisar JSON/HTML FWWebEx1500 fornecidos com cinco rotas;
  recálculos independentes de total/média/mediana/P95/desvio populacional
  coincidem em tolerância 1e-9. Reunir métricas internas do addon Harbour e
  Protheus em job único em cards alinhados, gráficos compartilhados e tabela
  única; mover chamadas completas e duração do benchmark para seção separada
  de totais. Preservar resultados imutáveis, métricas oficiais, exports seguros
  e escopos cliente/servidor. Compilação final: 54 fontes TLPP/zero erros;
  AppServer 82/81/43/31; Chromium 69+30 e prévia do relatório aprovados.
  Matriz SET nativa: 93 checks DECIMALS 2/18 × FIXED off/on e restauração do estado
  do chamador. Serve mode agora aplica/imprime SQL/ODBCPooling privado;
  a rodada histórica 255/off preserva seu escopo. Manual1500 fornecido passou
  1500+2 por rota escolhida; fontes/RPO compilados e pooling efetivo não foram
  identificados. Confirmar o layout FWWebEx ativo após recompilar; não deduzir
  ganho comparativo nem aceite de todas as plataformas. Pacote 002 T01 planejado.

### Manutenção HTTP priorizada em 2026-10-23

Novos relatórios de benchmark exigem revisão delimitada do hbhttpd antes da
integração SQL. O [rascunho T01](docs/typed-sql.pt-BR.md) registra o inventário
dos conectores, sem declarar API implementada ou T01 concluído. A ideia MEMIO
permanece no [trabalho futuro](docs/evolution.pt-BR.md#resultados-em-memoria-entre-requisicoes).

- [x] H01: analisar relatórios fornecidos e envio nativo; comparar cargas
  equivalentes e distinguir orçamento de espera do socket de atraso medido.
- [x] H02: corrigir envio de respostas e adicionar negociação HTTP de compressão
  comprovada onde suportada, usando hbhttpd gerenciado e núcleo compartilhado.
  Preservar UTF-8/NUL, envios parciais, posse do payload e semântica de falha.
- [x] H03: validar HTTP nativo identity/gzip e suporte TLPP/FWRest real, incluindo
  erros, respostas grandes e timeouts. Registrar escopo e documentos EN/PT;
  redução de bytes isolada não comprova ganho de desempenho.

Evidências em 2026-10-24: suíte nativa 777/0; probe de envio 18/0; AppServer
isolado compilou 55 fontes/zero erros e passou nos 14 checks FWRest/cliente,
saída 0. Comparação MSSQL/AppServer alternou identity/gzip duas vezes, cinco
medidas + dois aquecimentos por rodada, 10000 linhas em uma página, pooling off.
Passaram as 20 varreduras medidas e oito aquecimentos. Médias combinadas:
identity 1869,279 ms, gzip 910,453 ms. Verificação independente no fio:
582624 versus 107099 bytes, SHA-256 descompactado idêntico. Esta comparação
curta no mesmo build mede a política de encoding, sem isolar cada outra
alteração HTTP nem prometer aceleração geral em produção. Veja
[evidências HTTP](docs/http.pt-BR.md#http-review-on-2026-10-24) e
[manifesto sanitizado](docs/validation/http.response.windows.json).

O benchmark AppServer atual exige gzip na rota HTTP, independentemente de
`HTTPAcceptEncoding` no INI, e registra a política efetiva da requisição.
Fallback para identity falha explicitamente. A comparação acima utilizou a
política opcional anterior no mesmo build do servidor, antes desta exigência.
Checks MSSQL/AppServer reais confirmaram os dois resultados mesmo com INI
identity: gzip ativo passou duas medidas e um aquecimento (10000/página10000,
saída 0); compressão off produziu a rejeição esperada
`HTTP_COMPRESSION_REQUIRED` / HTTP 406 (saída 1), sem fallback identity.

O ajuste final resolve `CR_LF + CR_LF` uma vez por worker e passa o valor ao
parser; campos Accept-Encoding separados preservam todas as exclusões.
Regressão/envio finais: 777/18, zero falhas. Uma compilação posterior com 56
fontes e 14 checks FWRest passou, seguida de 12 probes diretos por etapa.
Expansão gzip: média 1,511 ms; parsing JSON: 43,158 ms; requisição nativa:
179,851 ms (inclui servidor/rede). Microbenchmarks separados do cache de
codepage preservaram bytes e SETs, sem comprovar aceleração estável.

### Decisões preservadas

- Manter implementação única e comportamento homologado de `RPCRDD.Query`,
  páginas e dataset. Preservar fronteiras UTF-8, NUL íntegro e números nativos.
- Protheus resolve contexto ERP, tenant/empresa/filial, tabelas físicas,
  filtros, esquema lógico e escala de negócio. hbBridge executa entradas
  explícitas. Aliases são opacos; nenhum perfil demonstrativo é obrigatório.
- Valores de bind e identificadores têm contratos diferentes. Validar
  identificadores a partir de metadados confiáveis do chamador; substituição
  de literais SQL não equivale a bind nativo. Comprovar prepared/bind de cada
  conector antes de declarar suporte.
- Preservar mutex do ciclo SQL e liberação dos leases. Tipagem não implica SQL
  paralelo, cursor persistente ou snapshot entre páginas.
- CAST do chamador continua disponível. Decimais grandes exatos podem ficar
  textuais; separar metadados de origem, definições lógicas e representação no
  transporte. SX3/TOP_FIELD automático, addons e reescrita SQL seguem adiados.
- NULL SQL é resultado válido e permanece distinto de vazio/zero/falso no
  serviço, transporte e dataset. A substituição de negócio pertence ao Protheus;
  somente conversão explícita para apresentação nativa pode rejeitar valor irrepresentável.
- `GetNonBlobColumns()` mantém textos longos e exclui tipos binários. Leitores
  LOB e transporte binário/streaming versionado permanecem futuros; nenhuma
  API é adicionada agora.
- Reutilizar/revisar `HBBridgeBrowseData` antes de outra camada de apresentação.
  Arrays nativos limitados às fronteiras exigidas pelo SDK/conector.

### Trabalho em ordem

- [x] **T01 — Definir os contratos delimitados.** Inventariar APIs e apresentação
  já implementada. Especificar valores de bind tipados, NULL/vazio, esquema
  nativo/origem versus lógico do chamador, escala/faixa, compatibilidade/
  versionamento e capacidades não suportadas.
- [x] **T02 — Comprovar bindings dos conectores.** Validar parâmetros preparados
  MSSQL/SQLite reais com texto/UTF-8/NUL, números/data, vazio/NULL, falhas e
  recuperação. Tipos/capacidades não suportados geram erro explícito, sem
  emulação de bind não comprovada nem conversão silenciosa.
- [x] **T03 — Integrar contrato homologado de parâmetros/metadados.** Estender
  serviço comum e clientes/dataset TLPP, preservando chamadas SQL/páginas
  existentes, perfil do chamador e cópias defensivas. Testar erros de conversão/faixa.
- [x] **T04 — Concluir apresentação nativa Protheus.** Adaptar browse existente
  ao esquema resolvido pelo chamador e recursos próprios FWTemporaryTable/
  interface nativa. Definir decode textual uma vez, políticas de NULL/tipo/escala,
  navegação e liberação após sucesso, falha e fechamento da interface.
  Preservar exemplos e posse dos recursos existentes.
- [ ] **T05 — Homologar e encerrar.** Executar checks nativos e AppServer real
  TCP/HTTP/apresentação, recuperação e liberação. Passar pelos três crivos de
  commit; atualizar documentos EN/PT e artefatos atribuíveis.

### Critérios de conclusão e pré-requisitos

T04 em 2026-10-25 adiciona `HBBridgePresentationSchema` e `HBBridgeNativeTable`.
O browse nativo agora é função estática local do exemplo interativo; uma API
nativa pública genérica fica adiada. A API `HBBridgeBrowseData.Browse` existente
permanece disponível.
O adapter converte snapshot próprio da página atual, confere estrutura/leitura
nativas e não busca outra página nem fecha dataset/cliente emprestados.
NULL é rejeitado somente neste destino nativo explícito. Esquema do chamador,
nomes gerados, UTF-8, roundtrip numérico, páginas vazias/falhas e posse têm
testes AppServer versionados. A sonda SDK distingue formatação numérica de
valor nativo armazenado; não altera SETs nem substitui por DEC_CREATE.
`FWGetTopInfo()` e liberação explícita de erros capturados passam a ser padrões.
Compilação AppServer isolada final: 64 fontes, zero erros/saída 0. Conversão:
32 checks; armazenamento/posse FWTemporaryTable real: 34; regressão do dataset
tipado: 77; dataset comum: 67, zero falhas. A sonda SDK passou cinco asserções
e registra formatação separada da igualdade numérica nativa. Os 64 hashes dos
fontes compilados continuam iguais aos da árvore. Veja o
[guia](docs/native-presentation.pt-BR.md) e
[manifesto sanitizado](docs/validation/native.presentation.windows.json).
`U_HBBridgeNativeBrowse()` está compilado para homologação visual manual;
ativação/fechamento do browse e execução conjunta do backend permanecem em T05.
A convenção de erro capturado foi conferida nos 42 blocos `catch xError`,
incluindo handlers antigos de benchmark/ciclo de vida. Os três validadores
passaram em 313 arquivos; links de 102 documentos aprovados, sem depender de tmp/out.

Feedback visual T05 em 2026-10-25 confirma abertura do primeiro exemplo nativo,
mas rejeita perguntar pela próxima página após fechar e relata desalinhamento
das colunas Flag/Day/Float. Essa observação não homologa navegação, pesquisa,
filtros nem fechamento. Ajustar o exemplo local para manter essas ações na
mesma janela, preservar posse do chamador e usar FWBulk quando disponível.
Recompilar/testar os fontes revisados e registrar novas identidades separadas
do manifesto T04 anterior; homologação visual manual continua necessária.

Revisão em 2026-10-26: manter `BrowseNative` local ao exemplo e a API pública
`Browse` existente. Navegação/pesquisa/filtros ficam na mesma janela;
preenchimento de página preserva tabela física, alias, área e índices. Usar
FWBulk quando disponível, com releitura completa opcional. Manter Flag lógico
e indexar auxiliar textual privado por `SearchFieldName()` / `IndexOrder()`;
Day/Float preservam vínculos independentes.

A fixture interativa sintética aceita `U_HBBridgeNativeBrowse(10000,100)` e
mantém padrões de 1000 linhas, 13 por página. A carga da tabela aceita
`U_HBBridgePresentationTableTest(10000)` ou CLI `--native-rows=10000`, padrão
1025. Nenhuma lê dados do ERP. Sete projeções visíveis incluem `ID_CODE` C(10)
com zeros à esquerda para ordenar caracteres nativos, preservando `ID` textual
exato. Corrigida a repetição do código 42 em `Result()`, com checks de código
por linha e passagem de 9 para 10 no índice. Pesquisa/filtro atua em toda a origem
sintética antes da paginação; isso não implementa nem testa reescrita SQL.

Saída manual AppServer fornecida em 2026-10-26 passou em 50 checks do browse e
56 da tabela nativa, com 1025 linhas por bulk, cruzando o buffer de 1024 linhas e
sete índices válidos. Esses logs não identificam hashes do executável/RPO e
os checks sem interface não homologam interação visual. Manter essa observação
separada da reexecução isolada posterior e do histórico T04.

A reexecução isolada posterior compilou 66 fontes/zero erros e passou em
59 checks do browse, 62 da tabela nativa, 32 de conversão, cinco SDK, 77 do
dataset tipado e 67 do comum, sem falhas de asserção. A carga principal gravou
10.000 linhas por bulk, com releitura independente completa, incluindo
ID_CODE/ID correspondentes; hashes dos fontes compilados permaneceram iguais.
Veja o [manifesto da revisão](docs/validation/native.presentation.revision.windows.json)
para identidades/saídas. Interação com o widget e homologação tipada conjunta
AppServer-hbBridge-backend real continuam abertas em T05.
Os três validadores de commit passaram em 316 arquivos; links aprovados em
102 documentos, sem dependências de tmp/out ou alterações no índice.

Continuação em 2026-10-24 após publicar o commit HTTP `98054b45`: a
[especificação T01](docs/typed-sql.pt-BR.md) fixa versões de entrada/resultado,
tipos estáveis por coluna, metadados fonte/RDD/lógicos, NULL/vazio, falhas
reservadas e posse da apresentação. As duas versões contêm três exemplos
JSON com sintaxe validada. A observação T01 é histórica; a implementação T03 segue abaixo.
O `scripts/test-harbour-sqlite-bind.ps1` independente passou em 252 checks/
zero falhas no Windows x64, SQLite 3.53.4. Comprovados comprimentos explícitos
UTF-8/NUL, NULL, descoberta de marcadores, metadados declarados/vazios/só NULL,
reset/recuperação e extremos int64 canônicos exatos. DECIMAL fixo exato permanece
não suportado; a afinidade NUMERIC comprovadamente perde dígitos ou escala.
`scripts/test-harbour-mssql-bind.ps1` passou em 75 checks/zero falhas contra
SQL Server 16.00.1210, ODBC 18.07.0001: Unicode/NUL, NULL por tipo, limites de
inteiros seguros/int64, DECIMAL(38,8), DATE/BIT/FLOAT nativos, colunas anuláveis
declaradas, metadados de vazios/só NULL, binds independentes página/contagem,
falhas por classe/recuperação e liberação de statements/conexão. É prova com
tabela temporária da sessão, sem homologar serviço/AppServer.
Registrar precisão FLOAT nativa 53/base 2 e zero decimal nativo `.00000000`;
a versão 2 adiciona precisionRadix e exige normalização lexical exata de zero.
O [desenho selecionado](docs/typed-sql-connectors.pt-BR.md) estende hashes
internos identificados de RDDI_EXECUTE nas conexões próprias dos SDDs, sem
exportar handles, abrir outra conexão ou alterar ABI. Compartilhamento do hash
e despacho foram comprovados em T03. Veja a
[evidência nativa sanitizada](docs/validation/sql.bind.windows.json).
T02 concluída nesse escopo Windows independente; T04/T05 permanecem pendentes.
Estas alterações posteriores não fazem parte do commit HTTP publicado.

2026-10-25 T03: `RPCRDD.QueryTyped` compartilha plano de página, mutex SQL,
lease, totais e liberação da Query existente; leitores SDD nativos identificados
preservam NULL e valores exatos estáveis por coluna, sem conexão adicional ou
exportação de handles. A integração passou em 133 checks Windows, zero falhas,
com SQLite/MSSQL reais, incluindo TCP/HTTP gzip/REST. Métodos TLPP versionados
preservam cópias de bindings/metadados sem fallback sem bind. AppServer isolado
compilou 57 fontes sem erros e passou em 77 checks tipados com mock e 67 antigos,
incluindo validação estrita de chaves compostas. Regressão nativa completa:
777 checks, zero falhas. O resultado manual de 67 checks informado em
2026-10-25 confirma navegação, sem identificar novo RPO. O
[manifesto da integração](docs/validation/typed.sql.windows.json) registra
identidades e contagens finais. Isso não conclui T04 nem implica homologação
tipada AppServer/backend/apresentação real; esse aceite permanece em T05.
Os três validadores de commit passaram sem alterar o índice; links de 98
documentos aprovados. Esta continuação não inclui commit ou publicação.

Cada capacidade implementada exige evidência do conector nativo e aceite
AppServer real no escopo registrado. Compilar TLPP alterado, preservar
compatibilidade Query/páginas, valores tipados e liberação dos recursos
próprios. Registrar identidades dos fontes/binários/RPO/configuração sem
segredos. Capacidades não suportadas ficam explícitas. Mock isolado não
homologa backend nem interface visual.

Usar dependências gerenciadas, perfil SQL privado explícito e SDK/runtime
AppServer licenciado. Preferir builds/RPOs isolados; não sobrescrever artefatos
em execução. Ler [contrato do dataset](docs/dataset.pt-BR.md), [apresentação
nativa](docs/evolution.pt-BR.md) e [contrato SQL](docs/milestone3-sql.pt-BR.md) em T01.

### Frentes seguintes preservadas

`RPCRDD.Materialize`/Release no MSSQL exige desenho/aceite próprios; tabela
temporária pertencente ao cliente não o implica. Pacotes seguintes mantêm
reuso MEMIO explícito e imutável, com handles autorizados, atualidade,
memória/expiração e posse dos leitores; veja [a viabilidade](docs/evolution.pt-BR.md#resultados-em-memoria-entre-requisicoes).
Também mantêm
credenciais cifradas portáveis/OpenBao/TLS, blocos/streams/leitores LOB,
DBF/NETIO/VF, serviços/Linux/administração e depuração. Benchmarks de addons
C/Zig e PostgreSQL/Protheus 12.1.2610 seguem como [trabalho futuro registrado](docs/benchmark-evolution.pt-BR.md).
TODO contém o roadmap completo. Não iniciar essas frentes enquanto T01–T05
estiverem pendentes sem repriorização explícita ou dependência/correção necessária.
