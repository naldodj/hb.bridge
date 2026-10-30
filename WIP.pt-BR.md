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
| Abertura / atualização | 2026-10-21 / 2026-10-30 |
| Situação | T01–T04 validadas nos escopos registrados. T05a de campos selecionados passou checks isolados e teve aceite visual manual confirmado. T05b de JOIN explícito e encerramento final do pacote permanecem abertos. |
| Objetivo | Definir valores SQL/metadados tipados explícitos e adapter de apresentação nativa pertencente ao chamador Protheus sobre Query/dataset homologados. |
| Referência | Base `8db2823`; artefatos da árvore de trabalho validados no pacote 001 identificados no manifesto de encerramento. Não é nova tag de release. |
| Próxima tarefa | T05b: implementar exemplos JOIN SRA/SRB e SRA/CTT explícitos conforme análise SX9, com metadados resolvidos pelo chamador e paginação determinística por linha resultante; manter política explícita de NULL/apresentação nativa. |

### Manutenção preparatória

- [x] 2026-10-30: enxugar os READMEs principais EN/PT para propósito, escolha
  de Harbour/C/Zig, recursos atuais, primeira execução e navegação dos guias.
  Manter documentação técnica versionada em docs; preservar os detalhes de
  depuração, arquitetura, enquadramento futuro e suporte corporativo em guias
  pareados. Organizar índices equivalentes por tarefa e redirecionar links das
  antigas seções dos READMEs. Gerar quatro arquivos de navegação Wiki bilíngue
  a partir dos índices por `scripts/prepare-wiki.ps1`, com destinos absolutos
  do repositório e saída determinística. O gerador não publica nem duplica a
  manutenção dos guias. Não reinicia o pacote 002 nem encerra seu aceite real
  de apresentação pendente.

- [x] 2026-10-30: implementar projeções selecionadas do dicionário T05a por
  `HBBridgePresentationTable.Project()` e seleção opcional na SRA. Reutilizar
  expressões confiáveis e CASTs do dicionário; preservar mapas saída/origem,
  inventário completo e motivos `notSelected` explícitos. Exigir posições,
  aliases e origens únicos, sem acrescentar campos de sistema implicitamente.
  Validar predicados de negócio antes da seleção e exigir identidade projetada
  do registro para paginação determinística. Adicionar entrada de browse SRA
  selecionado por TCP/HTTP gzip sobre pesquisa/filtro/View existentes. Criar
  fixtures de aliases inválidos por atribuição em JSONObject, evitando literais
  TLPP inválidos e macros, com rejeição real e sem aprovação incondicional.
  Usar HasProperty para não adicionar flag opcional ausente ao snapshot de
  entrada. Compilação final de 78 fontes e 730 checks de dez suítes passaram,
  incluindo 142 de planejamento/seleção/SQLite nativo SRA. Preservar as
  [evidências sanitizadas](docs/validation/selected.presentation.windows.json).
  Aceite visual manual confirmado posteriormente em 2026-10-30; seu
  [escopo informado](docs/acceptance.pt-BR.md#validação-visual-sra-selecionada-em-2026-10-30)
  permanece separado das identidades automatizadas dos fontes. T05b e o
  encerramento T05 continuam abertos.

- [x] 2026-10-29: revisar SX9Tools e os sete utilitários FWWebEx fornecidos.
  Inspeção local somente leitura do dicionário encontrou SRA para SRB
  (`RA_MAT/RB_MAT`, 1:N) e a relação de entrada CTT para SRA
  (`CTT_CUSTO/RA_CC`, 1:N). Registrar metadados bidirecionais, resolução de
  filial/compartilhamento e restrições de JOIN explícito na
  [análise SX9](docs/sx9-relationships.pt-BR.md). Registrar na
  [revisão dos utilitários](docs/fwwebex-tools-review.pt-BR.md) o clone JSON
  defensivo e restrito como primeiro candidato, sujeito a regressões de
  correção e medição. Reutilizar o relógio atual para fases de tempo opcionais;
  adiar merge/flatten até existir contrato concreto e evitar clonagem genérica
  de recursos. A análise não adiciona APIs em execução ou dependência ao núcleo,
  não encerra T05 nem altera sua próxima tarefa de aceite interativo.

- [x] 2026-10-29: resolver os apontamentos restantes de origem, MsMGet,
  builder compartilhado e teste SRA desatualizado. Busca por origem rejeita
  ambiguidades uniformemente e encontra uma origem única mesmo com projeção
  homônima sem origem. Manter identidade do dicionário em `aFields`/`M->` do
  MsMGet, incluindo `RA_BITMAP`, e título pela projeção. Compartilhar caminhos
  puros Build/Plan com os exemplos, rejeitar projeções vazias e campos de
  filtro/ordenação ausentes e recusar opções inválidas de pesquisa sem mudar
  a ordem atual. Compilados 78 fontes TLPP, zero erros; checks isolados
  aprovados: esquema 76, conversão por página 31, planejamento SRA/SX5 66,
  RDDs locais 100, mapeamento 36, datasets tipado/comum 77/67, SDK 5,
  TOPCONN/FWBulk 122 e callbacks do browse 74. Dataset comum retornou -4 após
  os 67 checks e APPLICATION END, aceito pela política existente do runner;
  demais suítes retornaram 0. Ajuste final das variáveis do dicionário em
  MsMGet compilado separadamente, zero erros. Preservar escopo interativo
  separado do View e [identidades/resultados sanitizados](docs/validation/presentation.review.windows.json).

- [x] 2026-10-29: documentar limpeza imediata de TLPP copiado/gerado em tmp,
  inclusive em falhas, e tradução de comentários em português para inglês
  durante revisões/edições. Validação do índice agora remove sua cópia dos
  fontes em `finally`; a regressão de seleção remove suas fixtures. Tradução
  nos três fontes TLPP revisados preservou código executável e strings.
  Seleção/limpeza passaram 57 checks; validação real do índice passou nos
  três utilitários com seleção vazia, índice preservado e nenhuma cópia TLPP
  temporária remanescente. Links de 104 documentos passaram. Essa manutenção
  não encerra T05.

- [x] 2026-10-29: manter `projectionFields` opcional no esquema lógico versão
  1. Aceitar esquemas anteriores com duas propriedades e validar os mapas
  fornecidos: chaves projetadas existentes e origens textuais não vazias e
  sem NUL; mapas vazios/parciais e origens repetidas continuam válidos.
  Preservar valores/metadados do chamador durante a conversão e transferir
  o mapa do builder para seu esquema. Validação focada no AppServer isolado:
  nove fontes compilados, zero erros; 76 checks de esquema/conversão e 31
  de conversão por página passaram, saída 0. Esse escopo não encerra os
  testes SRA, buscas por origem, validação do builder ou apresentação
  interativa ainda pendentes.

- [x] 2026-10-27: adicionar metadados SX3 reutilizáveis e exemplos SRA/SX3
  independente. Registrar inventário completo e exclusões explícitas; manter
  CASTs do dicionário e resolução de tabela/filial no Protheus. Preservar os
  sentidos origem/projeção/nativo, datas compactas vazias e NULL. Compilados
  73 fontes TLPP, zero erros; checks no AppServer isolado: conversão 54,
  página 31, planejamento SRA 49, datasets tipado/comum 77/67, SDK 5,
  armazenamento nativo 89 e callbacks do browse 59. Conversão por página
  valida invariantes uma vez e mantém checks dos valores; posições resolvidas
  antes do desenho. Comparação local de 100 colunas, 100 linhas e três rodadas:
  médias 8842,354 ms por linha e 1936,071 ms por página, excluindo SQL,
  transporte, DDL nativo e interface. Precede a revisão de RDD/índices
  solicitada e não mede ganho completo da SRA. Commit-check seleciona
  alterados/novos e preserva snapshot do índice, revisão completa por mudança
  de política e três validadores obrigatórios. Seleção Git passou 41 checks
  isolados, sem alterar o índice. Veja a
  [evidência sanitizada](docs/validation/sra.presentation.windows.json).

- [x] 2026-10-27, validado em 2026-10-29: revisar os caminhos SQLITE_MEM/SQLITE_TMP adicionados e adotar
  um índice inicial após popular, com os demais criados sob demanda pelo
  adaptador. Mapear detalhes FWSeek para projeções/ordens físicas, preservar
  aliases indexados nas recargas e liberar recursos próprios. Manter cobertura
  TOPCONN/FWBulk explícita e validar separadamente os dois RDDs locais.
  RDDs locais passaram 100 checks; TOPCONN/FWBulk passou 122 checks, com
  escrita bulk de 1025 linhas; callbacks do browse passaram 74 checks.
  Liberação SQLite ao fim da conexão permanece como comportamento documentado
  do SDK, sem classificar vazamento confirmado.

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
- [x] **T05a — Demonstrar campos específicos do dicionário.** Adicionar exemplo
  de projeção com colunas/aliases selecionados pelo chamador e esquema lógico/
  mapa de origem por saída. A API Project e o exemplo SRA selecionado estão
  implementados e passaram checks isolados de planejamento/armazenamento
  nativo. Validação visual manual confirmada em 2026-10-30, sem logs por
  transporte ou identidades compiladas dessa rodada. Preservar esse escopo
  separado da fixture automatizada; veja o
  [guia da seleção](docs/sx3-metadata.pt-BR.md#campos-específicos-e-consultas-com-join).
- [ ] **T05b — Demonstrar resultados de JOIN explícito.** Adicionar exemplos
  INNER/LEFT JOIN com aliases únicos, metadados/regras resolvidos pelo chamador,
  paginação determinística por linha resultante e política explícita de NULL/
  apresentação nativa. Validar origens duplicadas pelo acesso projetado e
  preservar identidade do dicionário no MsMGet sem confundir campos repetidos.
  Usar a [revisão SX9](docs/sx9-relationships.pt-BR.md) como referência:
  incluir relações de entrada/saída, resolver compartilhamento no Protheus e
  manter exclusão lógica do lado direito no ON de LEFT JOIN. O snapshot SX9
  somente leitura continua proposto; expressões arbitrárias do dicionário
  não são SQL.
  Esses exemplos estão planejados; execução SQL genérica não comprova seu
  aceite na interface. Veja o [plano de projeções/JOIN](docs/sx3-metadata.pt-BR.md#campos-específicos-e-consultas-com-join).
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

Continuação com SELECT real em 2026-10-26 após `6945aa5`: adicionar
`U_HBBridgeNativeBrowseSX5(cProfile,cTransport,nPageSize)`, padrão TCP, 100 por página,
na mesma janela local. Protheus resolve RetSQLName/xFilial/TamSX3 e o esquema
de cinco colunas, bindings imutáveis de filial/exclusão e desempate por RECNO.
A origem SQL do exemplo fornece SQL/bindings/ordenação e critérios tipados
parametrizados; campos do filtro vêm do esquema atual. Nenhuma resolução ERP
automática passa ao hbBridge nem BrowseNative vira API pública genérica.

Host MSSQL isolado novo e TCP/HTTP gzip/AppServer/armazenamento nativo reais
passaram em **83 checks de integração real**. Um SELECT sobre cinco linhas
VALUES constantes exercita sete projeções, conferência independente dos valores
nativos, paginação/totais, Unicode de entrada/saída, metadados decimais exatos,
filtros numéricos/lógicos/data/texto vinculados, aspas/curingas literais,
falhas/recuperação e liberação. Executa SQL real sem ler/atualizar tabelas ERP.
Entradas TLPP mantêm codificação do chamador; clientes codificam o JSON completo
uma vez. Resultados ficam UTF-8 até conversão explícita de apresentação.
A nova asserção de pesquisa Unicode impede dupla codificação dos bindings.

A execução isolada final compilou **69 fontes**, sem erros, e manteve os
checks 32/77/67/5/62/59 de conversão/datasets/SDK/tabela/browse, sem falhas de
asserção, além dos 83 reais. Hashes compilados iguais após executar. Regressão
nativa de backend/transporte passou em **133 checks**; a fixture própria
encerrou os dois listeners sem leases ativos. Veja o
[manifesto SQL real/apresentação](docs/validation/native.presentation.sql.windows.json).
SELECT automatizado e consulta SX5 interativa possuem aceites distintos:
esta ainda precisa de execução visual manual no ambiente Protheus preparado.
INI/RPOs da instalação e serviços existentes não foram substituídos.
Os três validadores passaram em 320 arquivos e links em 102 documentos;
o índice não foi alterado nesta continuação.

2026-10-26 aceite visual posterior: capturas fornecidas confirmam exibição do
browse SX5 real por TCP/HTTP e do View do registro atual. Essa observação manual
não fornece hashes compilados nem comprova isoladamente todos os caminhos de
filtro/falha/liberação.

O próximo exemplo solicitado amplia T05 para SRA e um snapshot reutilizável
`HBBridge.Protheus.HBBridgeSX3Metadata:Read()`. A resolução de dicionário/
tabela/filial permanece no Protheus. Combinar metadados FWSX3Util e catálogo
físico MSSQL para selecionar todo campo físico suportado do dicionário e campo
de sistema disponível; informar motivos explícitos para campos virtuais, memo/
binários, texto longo, ausentes e incompatíveis, sem truncamento silencioso.
Manter inventário completo mesmo quando os valores forem excluídos. CASTs
numéricos são definições explícitas do exemplo no chamador, sem parser SQL
genérico ou processamento SX3 automático no servidor. Transporte LOB permanece
futuro. Veja o [guia SX3/SRA](docs/sx3-metadata.pt-BR.md). A extensão requer
compilação, regressões e aceite interativo próprios antes de encerrar T05;
hashes e quantidades anteriores permanecem como evidência histórica.

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
