# Extensão dos conectores SQL tipados

[English](typed-sql-connectors.md) · [Contrato SQL tipado](typed-sql.pt-BR.md) · [WIP](../WIP.pt-BR.md)

**Decisão registrada em 2026-10-24; integração T03 validada em 2026-10-25.**
A extensão nativa de execução SDD usa a concessão SQL existente e o ciclo
comum de Query. A integração Windows SQLite/MSSQL passou em **133 verificações,
sem falhas**, incluindo chamadas reais TCP e HTTP/REST com gzip. Essa evidência
não homologa AppServer com banco real nem apresentação nativa.
O [manifesto de binding](validation/sql.bind.windows.json) preserva as provas
isoladas T02; não substitui a validação da integração.

## Decisão e pontos de extensão existentes

Usar uma requisição hash interna com identificador estrito por
`RDDI_EXECUTE`. Adicionar um caminho tipado aos callbacks nativos `Execute`
dos SDDs ODBC e SQLite, preservando o comportamento existente com strings.
Esse caminho recebe a conexão já pertencente à
[concessão SQL](../src/hb/services/hbbridge.sql.pool.hb); não abre uma conexão
independente nem expõe ponteiros nativos aos chamadores Harbour.

A revisão fixada do Harbour é
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, identificada no
[manifesto de dependências](../config/dependencies.json). Nessa revisão:

| Ponto existente | Consequência para a extensão |
| --- | --- |
| `sqlbaseRddInfo()` encaminha `RDDI_EXECUTE` para `pConn->pSDD->Execute`. | Reutilizar a localização da conexão e o despacho SDD existentes. |
| RDDSQL protege a conexão global por `uiAreaCount` durante Execute e aplica o mutex SDD quando configurado. | Manter o trabalho com statements dentro desse callback síncrono; preservar o mutex externo do ciclo SQL do hbBridge. |
| O callback Execute recebe `SQLDDCONNECTION *`. | ODBC pode usar seu `SQLHDBC`; SQLite pode usar seu `sqlite3 *`, sem copiar os layouts privados dessas estruturas. |
| `HB_RDDINFO` copia o item recebido; cópias de itens Harbour preservam o conteúdo compartilhado do hash. | Um hash interno mantido pelo chamador recebe o resultado/diagnóstico completo enquanto o retorno de RDDI_EXECUTE continua booleano. Os testes de integração verificam sucesso, rejeição e snapshots de entrada inalterados. |
| `SDDNODE` já possui o callback Execute. | Este desenho não exige novo membro de callback, alteração do layout das estruturas RDD nem da ABI SDD. |

As fontes fixadas relevantes são
[despacho RDDSQL](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/rddsql/sqlbase.c#L1245),
[estruturas SDD](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/rddsql/hbrddsql.h#L195),
[tratamento do argumento de RDDINFO](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/rdd/dbcmd.c#L2092)
e [semântica de cópia de itens/hashes](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/vm/itemapi.c#L1663).
Esses pontos de implementação não constituem uma nova API exposta pelo hbBridge.

A requisição interna deve conter identificador explícito de operação/versão,
SQL validado e um snapshot imutável dos bindings. Uma saída aninhada separada
recebe um resultado nativo completo ou uma falha sanitizada. Os nomes exatos
dos membros internos permanecem um detalhe de implementação; não são campos
adicionais da requisição pública QueryTyped. Rejeitar identificadores,
estruturas e capacidades desconhecidas antes da execução. Um hash não
reconhecido nunca deve seguir para a execução de strings.

## Um serviço e um ciclo de propriedade

`RPCRDD.QueryTyped` usa o
[serviço Query](../src/hb/services/hbbridge.query.hb) comum, compartilhando
validação do perfil, planejamento das páginas, aquisição da concessão,
totais, envelopes de erro, limpeza e restauração. O leitor existente
de Query/resultado versão 1 continua pelo caminho SQLMIX homologado. O leitor
tipado obtém metadados nativos e valores exatos de transporte na fronteira SDD;
não deve forçar strings exatas por campos numéricos aproximados do RDD.
Trata-se de um único fluxo de serviço com leitores específicos dos conectores,
sem criar um segundo serviço SQL ou pool de conexões.

Para uma chamada tipada, o ciclo implementado é:

1. Validar a requisição pública e obter o snapshot dos bindings antes da execução
   nativa.
2. Entrar no mutex SQL existente e adquirir a concessão lógica habitual.
3. Executar o statement da página ou da consulta sem paginação pelo callback
   nativo identificado: preparar, validar marcadores/quantidade nativos, vincular,
   executar, descrever, ler e fechar todos os recursos do statement antes de
   retornar.
4. Na paginação, preparar e vincular independentemente o statement de contagem
   com o mesmo snapshot e a mesma concessão. Liberar o leitor da página antes;
   não pressupor suporte a leitores simultâneos. Os limites de linhas gerados
   continuam literais inteiros validados e não alteram os ordinais dos bindings.
5. Publicar o resultado completo do serviço somente após o sucesso de mapeamento,
   leitura, contagem e limpeza dos statements. Caso contrário, descartar linhas
   parciais e retornar a categoria estável de falha.
6. Liberar a concessão e restaurar a conexão/área de trabalho anterior, inclusive
   nos erros. Uma falha de liberação continua visível e mantém a propriedade.

O callback nativo possui seu statement, buffers de parâmetros e descritores
temporários até o término da leitura e do fechamento. Nunca possui a conexão
de banco concedida. Statements, handles nativos e ponteiros dos buffers de
binding não são expostos aos chamadores Harbour. Os caminhos de falha nativa devem liberar
buffers e statements antes de retornar; lançar um erro Harbour antes da limpeza
nativa não substitui essa limpeza. Chamadas repetidas e recuperação após erros
não podem depender de opções pendentes na thread nem de uma requisição anterior.

Preservar o pooling físico opcional do gerenciador ODBC, as verificações das
concessões e o mutex SQL. Esta decisão não introduz SQL paralelo, cursores
persistentes, snapshot transacional entre página/contagem nem cache de resultados
entre requisições.

## Metadados nativos, valores exatos e NULL

Aplicar integralmente o
[contrato de mapeamento da versão 2](typed-sql.pt-BR.md#resultado-versão-2-e-mapeamento-estável-por-coluna).
Preservar os descritores nativos antes de reduções ou substituições de valores
pelo RDD; observações RDD, definições da origem e esquema lógico do chamador
continuam separados. Metadados desconhecidos são null, sem inventar zero,
false ou texto vazio.

| Fronteira | Comportamento obrigatório |
| --- | --- |
| Preparação/binding ODBC | Usar preparação, descoberta de parâmetros e binding de entrada nativos com capacidades verificadas e tamanhos explícitos. Manter os buffers válidos durante execução/leitura. Aplicar o timeout de consulta configurado a cada statement. |
| Descritores ODBC | Preservar tipo SQL com sinal, precisão, base da precisão, escala e nulabilidade nativa. Ler atributos suportados de tipo/origem/tamanho sem derivar a precisão da origem do tamanho de apresentação do RDD. Nulabilidade desconhecida e atributos indisponíveis continuam null; collation exige evidência específica. |
| Valores ODBC | Detectar `SQL_NULL_DATA` antes da conversão. Preservar UTF-8/NUL por leitura Unicode comprovada. Obter DECIMAL exato e bigint com sinal sem double intermediário, usando as strings canônicas do contrato. FLOAT aproximado continua aproximado. |
| Preparação/binding SQLite | Verificar quantidade nativa de parâmetros, nomes de marcadores anônimos, tamanhos explícitos, statement único e o restante do SQL preparado. Usar somente tipos de binding nativos comprovados. |
| Descritores SQLite | Selecionar um mapeamento estável a partir de colunas declaradas suportadas. Declarações desconhecidas, expressões sem declaração e metadados ambíguos falham explicitamente, inclusive para resultados vazios/todos NULL. |
| Valores SQLite | Verificar NULL com `sqlite3_column_type()` antes da conversão, usar tamanhos explícitos em bytes para texto e verificar a classe de armazenamento/faixa de cada valor não nulo contra o mapeamento fixo. Não amostrar a primeira linha nem mudar tipos silenciosamente. |

Os leitores tipados evitam os caminhos existentes de conversão de strings e
resultados SDD: ODBC mapeia DECIMAL para um leitor numérico RDD aproximado;
SQLite pode substituir NULL mapeado por valores numéricos padrão e ler texto
por um caminho de string terminada. Preparação nativa isoladamente não comprova
as garantias da versão 2. O contrato Query existente permanece igual; adicionar
o leitor tipado não atribui garantias da versão 2 a Query/resultado versão 1.

A prova MSSQL em seu escopo informa precisão FLOAT 53 com base 2; isso não
significa 53 dígitos decimais nem escala de negócio. Preservar
`source.precisionRadix` junto à precisão informada. Texto decimal nativo como
`.00000000` exige normalização lexical para `0.00000000`, preservando a escala
da origem e o zero canônico sem parsing numérico intermediário, double ou
arredondamento.

Preservar SQL NULL no serviço, transporte e dataset, separadamente de texto
vazio, zero e false. Protheus define sua interpretação de negócio e eventual
substituição explícita, inclusive para campos de dicionário tornados anuláveis
por joins. O adaptador de apresentação nativa pode rejeitar um NULL não
representável conforme sua política explícita; isso não autoriza o hbBridge a
substituir ou rejeitar um resultado válido de consulta. Não adicionar consulta
automática à SX3/TOP_FIELD nem inferência de escala de negócio.

## Extensão gerenciada e alternativas

Compilar a extensão sobre as dependências fixadas por patches gerenciados
revisados e recibos. Reutilizar o
[patch ODBC existente](../config/patches/sddodbc.patch), incluindo os helpers
de timeout de consulta e leitura variável; o
[script de preparação ODBC](../scripts/prepare-odbc.ps1) aplica o patch em uma
cópia gerenciada descartável, preservando o checkout da origem fixada.
O [patch SQLite correspondente](../config/patches/sddsqlt3.patch) é preparado
por [prepare-sqlite.ps1](../scripts/prepare-sqlite.ps1), chamado pela preparação
ODBC antes de verificar o cache. Ambos os recibos incluem revisão fixada,
patch, plataforma/compilador, biblioteca instalada e hashes dos helpers nativos
do projeto; alterações dos helpers invalidam o reaproveitamento.
Os [helpers tipados comuns](../src/c/hbbridge.sql.typed.h) e o
[validador de bindings](../src/c/hbbridge.sql.binding.c) preservam adaptadores
[ODBC](../src/c/hbbridge.odbc.typed.c) e
[SQLite](../src/c/hbbridge.sqlite.typed.c) explícitos.

A guarda de admissão SQL aceita uma gramática limitada SELECT/CTE e rejeita
operações, lotes e formas de marcadores não suportados antes da execução
nativa. Não é um parser SQL geral. Preparação nativa, descoberta de parâmetros
e verificações de restante do statement/somente leitura do SQLite continuam
determinantes. Expressões SQLite sem declaração não recebem mapeamento de
transporte por amostragem de linhas; a operação interna reservada de contagem
é separada do mapeamento de resultados comuns.

Uma ponte nativa externa não consegue obter atualmente a conexão nativa de
uma concessão RDDSQL por um accessor exportado suportado. Abrir outra conexão
duplicaria propriedade, comportamento de timeout/configuração e decisões de
pooling; copiar layouts privados das estruturas SDD acoplaria código externo
a detalhes internos. Nenhuma dessas opções foi selecionada. Um novo callback
SDD genérico poderia ser uma API futura para upstream, mas exige alterações
coordenadas de estrutura/ABI e é maior que a extensão Execute necessária aqui.

O vocabulário SQL delimitado rejeita palavras de comandos, incluindo `FETCH`;
não aceita toda expressão válida dos dialetos. CTEs no nível principal do MSSQL
podem ser usadas sem página; paginação/contagem exigem consulta-base válida
dentro de tabela derivada. CTE principal MSSQL com `page` falha na preparação
nativa, sem reescrita SQL ou fallback para batch. Em páginas SQLite, nomes com
dois-pontos ou prefixo reservado de ordinal são rejeitados para preservar a
detecção de duplicatas renomeadas pelo SQLite. Comentário de linha final é
encerrado antes do sufixo gerado para página/contagem.

## Evidências da integração e escopo restante

O [manifesto Windows de binding](validation/sql.bind.windows.json) delimita
as provas isoladas SQLite/MSSQL por fonte, driver, plataforma e operação. É
evidência de recursos nativos individuais, sem anunciar capacidade do serviço.
As execuções isoladas Windows de 2026-10-24 passaram em 252 verificações SQLite
e 75 MSSQL, sem falhas; não executam a extensão hash SDD selecionada.
Executar a [prova SQLite](../scripts/test-harbour-sqlite-bind.ps1) e a
[prova MSSQL](../scripts/test-harbour-mssql-bind.ps1) versionadas com seus
pré-requisitos documentados; as credenciais privadas permanecem externas.

O [executor de integração](../scripts/test-hbbridge-typed-sql.ps1) versionado
compila os adaptadores gerenciados e o serviço compartilhado em diretório
descartável novo. Executar apenas SQLite ou adicionar perfil MSSQL privado
explícito:

```powershell
./scripts/test-hbbridge-typed-sql.ps1
./scripts/test-hbbridge-typed-sql.ps1 -Config '<ini-privado>' -Profile '<alias>'
```

A rodada Windows de 2026-10-25 passou em 133 verificações: 111 nativas
SDD/serviço e 22 reais TCP/HTTP/REST com gzip entre SQLite e MSSQL. O executor
grava `result.json` sanitizado e `receipt.json` com identidades de fontes,
binário e dependências, além de logs descartáveis de compilação/console.
Credenciais não são copiadas para esses recibos. A reprodução depende de
fontes versionados e dependências gerenciadas, nunca de uma pasta tmp anterior.
Os comportamentos cobertos incluem:

- A saída no hash compartilhado sobrevive à substituição do item local de
  `RDDI_EXECUTE` por um booleano, inclusive para false/erros, mantendo os snapshots
  de entrada intactos.
- O despacho identificado nunca executa hashes inválidos/desconhecidos como
  SQL, preserva a execução de strings e não vaza estado compartilhado de
  requisições pendentes.
- A descoberta nativa dos marcadores verifica o contrato posicional; marcadores
  nomeados/numerados, quantidades incompatíveis e múltiplos statements são
  rejeitados explicitamente.
- Colunas declaradas anuláveis, resultados vazios/todos NULL, NUL/Unicode,
  limites exatos de inteiros/decimais, classes de armazenamento inválidas e
  resultados não suportados preservam a semântica prevista ou falham explicitamente.
- Página/contagem usam o mesmo snapshot de descritores em uma concessão; página
  vazia preserva metadados/totais estáveis e as falhas exercitadas de mapeamento
  dos resultados descartam saídas parciais.
- Chamadas com sucesso e caminhos de rejeição exercitados liberam statements/
  concessões; desconexão, restauração do estado e chamadas válidas posteriores
  têm sucesso.

Os checks de transporte verificam valores/metadados exatos após chamadas TCP,
de serviço HTTP com gzip e pelo roteamento REST, falha estruturada/recuperação
e encerramento dos listeners próprios. Usam consumidores Harbour; registrar
separadamente o aceite do dataset TLPP e do AppServer com banco real.
Injeção de falhas de alocação/fechamento no driver, Linux e outras combinações
de driver não são comprovados por essa rodada Windows. Decimais fixos exatos
no SQLite, tipos de resultado não suportados, metadados nativos indisponíveis
e combinações de driver/plataforma não comprovadas continuam sem suporte.
