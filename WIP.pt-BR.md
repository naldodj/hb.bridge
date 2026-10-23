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
| Abertura / atualização | 2026-10-21 / 2026-10-23 |
| Situação | Planejado; implementação não iniciada. |
| Objetivo | Definir valores SQL/metadados tipados explícitos e adapter de apresentação nativa pertencente ao chamador Protheus sobre Query/dataset homologados. |
| Referência | Base `8db2823`; artefatos da árvore de trabalho validados no pacote 001 identificados no manifesto de encerramento. Não é nova tag de release. |
| Próxima tarefa | T01: inventariar APIs existentes dos conectores/clientes e especificar contratos compatíveis de parâmetros/metadados de origem/lógicos/transporte antes da implementação. |

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
- `GetNonBlobColumns()` mantém textos longos e exclui tipos binários. Leitores
  LOB e transporte binário/streaming versionado permanecem futuros; nenhuma
  API é adicionada agora.
- Reutilizar/revisar `HBBridgeBrowseData` antes de outra camada de apresentação.
  Arrays nativos limitados às fronteiras exigidas pelo SDK/conector.

### Trabalho em ordem

- [ ] **T01 — Definir os contratos delimitados.** Inventariar APIs e apresentação
  já implementada. Especificar valores de bind tipados, NULL/vazio, esquema
  nativo/origem versus lógico do chamador, escala/faixa, compatibilidade/
  versionamento e capacidades não suportadas.
- [ ] **T02 — Comprovar bindings dos conectores.** Validar parâmetros preparados
  MSSQL/SQLite reais com texto/UTF-8/NUL, números/data, vazio/NULL, falhas e
  recuperação. Tipos/capacidades não suportados geram erro explícito, sem
  emulação de bind não comprovada nem conversão silenciosa.
- [ ] **T03 — Integrar contrato homologado de parâmetros/metadados.** Estender
  serviço comum e clientes/dataset TLPP, preservando chamadas SQL/páginas
  existentes, perfil do chamador e cópias defensivas. Testar erros de conversão/faixa.
- [ ] **T04 — Concluir apresentação nativa Protheus.** Adaptar browse existente
  ao esquema resolvido pelo chamador e recursos próprios FWTemporaryTable/
  FWMBrowse. Definir decode textual uma vez, políticas de NULL/tipo/escala,
  navegação e liberação após sucesso, falha e fechamento da interface.
  Preservar exemplos e posse dos recursos existentes.
- [ ] **T05 — Homologar e encerrar.** Executar checks nativos e AppServer real
  TCP/HTTP/apresentação, recuperação e liberação. Passar pelos três crivos de
  commit; atualizar documentos EN/PT e artefatos atribuíveis.

### Critérios de conclusão e pré-requisitos

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
credenciais cifradas portáveis/OpenBao/TLS, blocos/streams/leitores LOB,
DBF/NETIO/VF, serviços/Linux/administração e depuração. Benchmarks de addons
C/Zig e PostgreSQL/Protheus 12.1.2610 seguem como [trabalho futuro registrado](docs/benchmark-evolution.pt-BR.md).
TODO contém o roadmap completo. Não iniciar essas frentes enquanto T01–T05
estiverem pendentes sem repriorização explícita ou dependência/correção necessária.
