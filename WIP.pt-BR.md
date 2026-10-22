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
| Abertura / atualização | 2026-10-21 / 2026-10-22 |
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
