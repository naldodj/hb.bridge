# SQL tipado e apresentação nativa: contrato do pacote 002

[English](typed-sql.md) · [WIP](../WIP.pt-BR.md) · [SQL atual](milestone3-sql.pt-BR.md)

**Especificação T01 concluída em 2026-10-24**, sobre a base `98054b45` do
projeto e Harbour `6deac9cf3ad977ae829e5bca543d553b92dd4b6d` com patches
gerenciados. T03 implementa o serviço e dataset tipados sob este contrato;
a [evidência de integração](validation/typed.sql.windows.json) distingue testes
de backend/transporte nativos de testes com mock no AppServer. T04 implementa
[apresentação nativa](native-presentation.pt-BR.md), com checks AppServer de
conversão/armazenamento; homologação conjunta backend/UI permanece em T05.
Permanecem preservados
`RPCRDD.Query`, resultado versão 1 e chamadas atuais do dataset.

## Inventário e fronteira de implementação

O inventário abaixo registra a base de T01, anterior à extensão T03.

| Componente | Implementação observada | Consequência |
| --- | --- | --- |
| [Serviço Query](../src/hb/services/hbbridge.query.hb) | Texto SQL, página opcional, área SQLMIX e contagem separada | Sem contrato de bindings de valores ou metadados físicos de colunas. |
| [Leases SQL](../src/hb/services/hbbridge.sql.pool.hb) | Conexão por chamada sob mutex SQL compartilhado; pooling físico ODBC opcional | Preservar posse/restauração; não implica cursor persistente ou cache. |
| SDDODBC | Execução direta; patch gerenciado de UTF-8/leitura/timeouts/pooling | Sem caminho atual de `SQLBindParameter`; comprovar a menor extensão nativa. |
| SDDSQLITE3 | Prepara/executa SQL sem bind | Preparação isolada não comprova bind nem fidelidade de NULL. |
| `hbodbc` | Wrappers prepare/execute; sem wrapper bind no contrib fixado | Não substitui diretamente a rota SDDODBC homologada. |
| `hbsqlit3` | Wrappers nativos prepare/bind/step/column | Candidato para prova/referência, sem integração Query/SQLMIX. |
| [Dataset](../src/tlpp/hbbridge.rpc.dataset.tlpp) | Linhas nomeadas, cópias defensivas de metadados/linhas, totais e navegação | Reutilizar validação/navegação; métodos tipados ainda não existem. |
| [BrowseData](../src/tlpp/hbbridge.browse.data.tlpp) | Arrays da página atual no FWBrowse, navegação, filtros e títulos/máscaras do dicionário no chamador | Reutilizar a UI; FWTemporaryTable com esquema explícito é trabalho adicional. |

Fontes fixados inspecionados: [SDDODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddodbc/core.c),
[SDDSQLITE3](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddsqlt3/core.c),
[wrappers ODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c)
e [wrappers SQLite](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbsqlit3/core.c).
O [manifesto](../config/dependencies.json) e o [patch ODBC](../config/patches/sddodbc.patch)
identificam insumos gerenciados. Compilar um contrib não expõe suas APIs no hbBridge.

Query atual pode ignorar parâmetros desconhecidos; acrescentar `bindings` nesse
serviço poderia executar SQL sem bind. BrowseData antigo decodifica a linha
serializada; o caminho adicional T04 converte campos individualmente pelos
helpers JSON seguros para NUL e usa esquema explícito do chamador, não comprimento RDD.
SDDSQLITE3 atual pode substituir NULL mapeado por defaults e ler texto por
terminador. Testes de expressão NULL não comprovam fidelidade de colunas
anuláveis/NUL. Os novos leitores tipados nativos resolvem essas lacunas de
binding/metadados/NULL sem alterar o leitor Query/versão 1. T04 preserva a API
Browse antiga e adiciona posse explícita da tabela da página atual.
`BrowseNative` pertence ao exemplo interativo local; uma API pública genérica
de browse nativo permanece futura.

## Entrada tipada e requisição estrita

Usar **`RPCRDD.QueryTyped`**, `requestVersion: 1`, **`resultVersion: 2`**.
Servidor antigo retorna `SERVICE_NOT_FOUND`; nunca repetir por Query sem bind
ou interpolar literais SQL. As entradas compartilham execução, paginação e
liberação, estendendo a fronteira nativa apenas onde necessário.

```json
{
    "service": "RPCRDD.QueryTyped",
    "params": {
        "requestVersion": 1,
        "alias": "MSSQL/pData",
        "sql": "SELECT ID, NAME FROM explicit_table WHERE ID > ? AND NAME = ?",
        "bindings": {
            "1": { "type": "integer", "isNull": false, "value": 10 },
            "2": { "type": "text", "isNull": false, "value": "Harbour" }
        },
        "page": { "number": 1, "size": 10, "orderBy": "ID ASC" }
    }
}
```

Essa entrada é registrada quando existem perfis SQL configurados. `params` exige `requestVersion`,
`alias`, `sql`, `bindings`; apenas `page` é opcional. Rejeitar membros
desconhecidos em cada nível do novo contrato, versões incorretas, perfil/SQL
vazios, tipos JSON inválidos e descritores malformados antes da execução.
`page` exige exatamente `number`, `size`, `orderBy`, preservando faixas inteiras
verificadas, validação de identificadores/ordem e ordenação determinística do
chamador. Permanecem as regras atuais de envelope/autenticação do transporte.

`bindings` é objeto com chaves ordinais canônicas contíguas `"1"` até `"N"`;
`{}` significa zero parâmetros. Vincular por ordinal, não pela enumeração do
hash. Permitir apenas marcadores posicionais anônimos `?`, um descritor por
ocorrência. Marcadores nomeados/numerados, parâmetros de saída, lotes e stored
procedures ficam fora da versão 1. Validar quantidade nativa de parâmetros
preparados e, onde expostos, nomes nativos: no SQLite, os nomes devem ser null.
Não contar caracteres nem reescrever literais/comentários. Sem comprovar esse
contrato de marcadores no conector, rejeitar como não suportado. Bindings
fornecem valores, nunca identificadores, expressões ou direção de ordenação.
Protheus resolve tenant/empresa/filial, nomes físicos e predicados; aliases
são opacos. Bind não concede permissões de tabelas nem implementa parser SQL.

Na paginação, copiar descritores uma vez e vincular os mesmos valores de base
independentemente aos statements de página e contagem, no mesmo lease.
Validar quantidades nativas de parâmetros em ambos. Limites de linhas gerados
continuam literais inteiros verificados, sem novos marcadores ou deslocamento
de ordinais. É um **snapshot de entrada**, não isolamento transacional:
statements separados e páginas posteriores podem observar alterações
concorrentes. Não há promessa de snapshot do banco entre chamadas.

## Valores de bind, NULL e faixas

Cada descritor exige `type` e `isNull` lógico. Valor não nulo exige `value`;
NULL proíbe esse membro. Somente `decimal` também exige `precision` e `scale`,
inclusive para NULL tipado. Rejeitar membros contraditórios, ausentes ou
desconhecidos. NULL, texto vazio, zero e falso são distintos.

NULL SQL é resultado válido, sem motivo para rejeitar a consulta. Preservá-lo
no serviço, transporte e dataset; qualquer substituição de negócio pertence
ao Protheus. A presença no dicionário ou coluna de origem não anulável não muda
essa regra: outer joins e expressões ainda podem produzir NULL. Os erros de
conversão do adapter descritos adiante tratam de destino nativo incapaz de
representá-lo, não de rejeição de NULL pelo serviço de consulta ou dataset.

| Tipo | Valor de transporte não nulo | Requisito nativo |
| --- | --- | --- |
| `text` | String JSON UTF-8, inclusive vazio/NUL | Comprimento explícito em bytes; comprovar bind/leitura Unicode. |
| `integer` | Número JSON integral em `[-9007199254740991, 9007199254740991]` | Bind inteiro e redução de faixa verificada. Protheus também deve preservar exatamente o inteiro fornecido. |
| `int64` | String decimal canônica com sinal em `[-9223372036854775808, 9223372036854775807]` | Conversão/bind int64 verificados, sem double intermediário. |
| `number` | Número JSON finito, semântica aproximada | Bind de ponto flutuante; rejeitar NaN/infinito e overflow. |
| `decimal` | String decimal exata simples e inteiros `precision >= 1`, `0 <= scale <= precision` | Bind exato suportado pelo driver, sem double. Decimal fixo SQLite não é suportado sem mapeamento exato comprovado separadamente. |
| `boolean` | true/false JSON | Comprovar BIT nativo MSSQL ou entrada inteira explícita 0/1 SQLite; sem conversão implícita por valor verdadeiro. |
| `date` | Calendário válido `YYYY-MM-DD`, sem fuso | Comprovar DATE SQL nativo MSSQL ou entrada textual ISO explícita SQLite. A última não cria resultado DATE nativo no SQLite. |

Strings inteiras seguem `-?(0|[1-9][0-9]*)`, sem zero negativo. Decimal de
entrada segue `-?(0|[1-9][0-9]*)([.][0-9]+)?`, sem espaços, sinal positivo ou
expoente. Dígitos fracionários cabem em `scale`; inteiros em
`precision - scale`, sem contar o zero inicial de valor fracionário. Rejeitar
zero negativo e arredondamento. Verificar limites do conector separadamente.
É o vocabulário do contrato; o [guia dos conectores](typed-sql-connectors.pt-BR.md)
registra mapeamentos implementados e seus limites. Sem restaurar teto de payload do MVP.

## Resultado versão 2 e mapeamento estável por coluna

Escolher uma representação por coluna a partir de descritores preparados/
nativos antes de ler linhas. Mantê-la entre linhas/páginas; nunca inferir pelo
primeiro valor não nulo. Preservar `header`/`rows` por chave, nomes únicos de
projeção em maiúsculas, posições contíguas `1..FieldCount` e significados atuais
de página/totais. Toda linha contém todas as chaves do header; chave ausente é
resultado malformado, enquanto null JSON indica exclusivamente NULL SQL.
Resultados vazios/só NULL mantêm metadados completos e o mesmo mapeamento.
Rejeitar nomes normalizados duplicados.

Todos os grupos/membros abaixo são obrigatórios. `position` é inteiro positivo;
`rdd.type` é string/null e seus tamanhos são inteiros não negativos/null.
Na origem, `typeCode` é inteiro nativo/null; nomes de tipo/origem são strings/
null; precisão/escala/comprimentos são inteiros não negativos/null;
`precisionRadix` é inteiro positivo/null e `nullable` é lógico/null. Preservar
as unidades nativas: FLOAT MSSQL pode informar precisão 53 com base 2;
precisão DECIMAL usa base 10. Metadado desconhecido é **null**, sem inventar zero, texto
vazio ou falso. `wire.kind`/`jsonType` seguem a tabela; encoding é `UTF-8` para
strings e null nos demais. Observações RDD não substituem definições da origem.
Base nativa zero, inaplicável ou desconhecida, torna-se null na versão 2;
a prova nativa bruta ainda pode registrar zero como observação.

Exemplo de resultado do serviço, com DECIMAL exato textual e metadados de
origem da expressão desconhecidos:

```json
{
    "success": true,
    "resultVersion": 2,
    "driver": "mssql",
    "header": {
        "AMOUNT": {
            "position": 1,
            "rdd": { "type": null, "length": null, "decimals": null },
            "source": {
                "typeCode": 3,
                "typeName": "decimal",
                "precision": 12,
                "precisionRadix": 10,
                "scale": 2,
                "characterLength": null,
                "octetLength": null,
                "nullable": true,
                "catalog": null,
                "schema": null,
                "table": null,
                "column": null,
                "collation": null
            },
            "wire": { "kind": "decimal", "jsonType": "string", "encoding": "UTF-8" }
        }
    },
    "rows": { "1": { "AMOUNT": "123.45" }, "2": { "AMOUNT": null } },
    "rowCount": 2,
    "totalRows": 2,
    "totalPages": 1,
    "page": { "number": 1, "size": 10, "hasNext": false, "firstRow": 1, "lastRow": 2 }
}
```

Versão 2 exige `totalRows`/`totalPages` como inteiros JSON seguros, exatos e não
negativos; sem paginação, totais equivalem a rowCount e 0/1 páginas. `page`
aparece apenas em requisições paginadas. Chaves de linhas reiniciam em `"1"`
por página; firstRow/lastRow vazios são zero. Ocultar ordinais internos de
paginação. Sem sucesso parcial se contagem/mapeamento/leitura falhar.

| Classe nativa da origem | `wire.kind` / `jsonType` | Regra fixa |
| --- | --- | --- |
| Caractere/texto com encoding comprovado | `text` / `string` | UTF-8, comprimento explícito; preservar vazio/NUL. |
| Inteiro exato cuja faixa declarada inteira cabe em inteiros JSON seguros | `integer` / `number` | Número integral finito sem redução inexata. |
| Inteiro de 64 bits com sinal, inclusive colunas SQLite declaradas com afinidade inteira | `int64` / `string` | Todas as linhas não nulas usam strings inteiras canônicas, inclusive valores pequenos. |
| DECIMAL/NUMERIC exato | `decimal` / `string` | Strings simples exatas com exatamente a escala da origem; sem expoente/zero negativo. Exigir precisão/escala conhecidas e leitura nativa sem perda. |
| FLOAT/REAL/DOUBLE nativo | `number` / `number` | Aproximado finito pelo codec compartilhado que preserva precisão; sem inferência de escala de negócio. |
| BIT/boolean nativo | `boolean` / `boolean` | Apenas tipos de origem lógicos comprovados; sem conversão implícita de números. |
| DATE nativo | `date` / `string` | ISO `YYYY-MM-DD`; `YYYYMMDD` da versão 1 permanece preservado. |
| TIME, TIMESTAMP, tipos com fuso, binário/BLOB | não suportado | Sem formatação implícita, descarte de horário ou conversão binário-texto. |

Tipos sem sinal fora dessas garantias de sinal/faixa não são suportados.
Determinar NULL por indicadores/tipos de armazenamento nativos **antes** da
substituição por defaults RDD. Getter Nil em EOF/campo ausente não comprova
NULL SQL. Preservar descritores/NULL junto ao caminho compartilhado da query;
não forçar strings exatas em campos numéricos RDD aproximados. FLOAT da origem
não recupera dígitos ausentes; CAST não restaura precisão inexistente no
armazenamento. Nunca derivar precisão decimal de comprimento de exibição ou
tamanho de coluna FLOAT.
Texto decimal nativo pode omitir o zero inteiro (`.00000000`); o transporte
canônico deve inseri-lo (`0.00000000`) sem parsing numérico nem arredondamento.
A prova dos conectores em 2026-10-24 justifica base explícita da precisão e
normalização lexical de zero; ambos estão implementados no leitor tipado.

Afinidade SQLite declarada texto/inteiro/real é apenas candidata a mapeamento.
Verificar classe de armazenamento/faixa de cada valor não nulo contra o
mapeamento fixo; rejeitar classes incompatíveis misturadas, sem trocar tipo de
transporte. Armazenamento inteiro em mapeamento REAL só converte se exatamente
representável. BOOL/DATE/DECIMAL declarados não comprovam semântica nativa de
lógico/data/decimal fixo e não são suportados neste contrato de resultado.
Expressões sem declaração, declarações desconhecidas e metadados indisponíveis/
ambíguos falham explicitamente, inclusive resultados vazios/só NULL. CAST no
SQLite não fornece automaticamente tipo declarado de saída nem resolve essa
limitação. Nunca amostrar valores ou substituir pela semântica da versão 1.

## Falhas tipadas e evidência de capacidades

O caminho tipado usa as categorias abaixo no envelope seguro atual de erros
do serviço. Elas não alteram erros da Query existente:

| Código | Significado |
| --- | --- |
| `INVALID_TYPED_REQUEST` | Membros desconhecidos/ausentes ou formato malformado. |
| `UNSUPPORTED_REQUEST_VERSION` | requestVersion não suportada. |
| `INVALID_BINDINGS` | Ordinais não contíguos, parâmetros ausentes/excedentes ou nomes nativos proibidos. |
| `BINDING_RANGE_ERROR` | Calendário inválido, valor não canônico/inexato, overflow ou violação de precisão/escala. |
| `UNSUPPORTED_BINDING_TYPE` | Mapeamento nativo de entrada indisponível. |
| `UNSUPPORTED_RESULT_TYPE` | Mapeamento de resultado desconhecido, misto ou não suportado. |
| `RESULT_RANGE_ERROR` | Valor nativo não cabe no mapeamento fixo sem perda. |
| `RESULT_NULL_UNAVAILABLE` | Fidelidade de NULL nativo não pode ser comprovada. |
| `STATEMENT_PREPARE_FAILED` / `STATEMENT_BIND_FAILED` / `STATEMENT_EXECUTE_FAILED` / `STATEMENT_FETCH_FAILED` | Falha nativa; liberar recursos antes de retornar. |

Autenticação, perfil, conexão e erros comuns preservam categorias atuais.
Diagnósticos podem identificar etapa, chave do perfil, driver, ordinal/posição
da coluna e código nativo sanitizado; nunca expor SQL, connection strings,
credenciais ou valores vinculados. Não expor texto bruto do driver que os
contenha. Limpar resultados parciais e permitir recuperação por chamada válida.

T02 registra `supportedCapabilities` como **evidência de testes delimitada por
conector, driver/versão, plataforma e tipo/operação**, não como anúncio atual
do serviço. A tabela é vocabulário permitido, não suporte universal. Discovery
só anuncia QueryTyped/versão após integração T03, sem implicar capacidades de
perfil ainda não comprovadas.

## Dataset e apresentação lógica do chamador

Usar `OpenSQLTyped(sql, bindings[, page])` e
`OpenPageTyped(sql, bindings, number, size, orderBy)` no dataset existente,
mantendo `New(oClient)` e `SetAliasProfile(profile)` para selecionar perfil;
sem novo argumento posicional de perfil. Assinaturas atuais preservadas.
O **validador da versão 2** mantém validação da versão 1 para os
resultados antigos. Validar tipos fixos de transporte, metadados/linhas
contíguos, nulls, totais e versão antes de publicar estado. Preservar cópias
defensivas de header/linhas/bindings em Next/PreviousPage; limpar em close/
reabertura/falha. Sem fallback por OpenSQL antigo ou reinterpretação de strings
numéricas exatas.

`Header()`/`FieldInfo()` retornam cópias defensivas aninhadas da versão 2 para
resultados tipados. `FieldGet()` preserva valores do transporte, inclusive
int64, decimal e date textuais, sem conversão de negócio. Com linha atual e
verificação de `FieldExist()`, Nil significa NULL SQL; EOF/campo ausente exige
sua própria verificação. Não é necessário novo método público IsNull aqui.

`logicalSchema` pertence ao Protheus/apresentação, não à requisição QueryTyped.
Chaves correspondem à projeção; sem inferência automática de SX3, TOP_FIELD,
tabela/filial ou escala de negócio. Entrada reservada do adapter:

```json
{
    "schemaVersion": 1,
    "fields": {
        "AMOUNT": {
            "type": "numeric",
            "length": 12,
            "decimals": 2,
            "nullable": true,
            "caption": "Amount",
            "picture": "@E 999999999.99",
            "inputFormat": null,
            "nullPolicy": "reject",
            "roundingPolicy": "reject"
        }
    }
}
```

Validar schemaVersion, correspondência à projeção, definições obrigatórias e
membros desconhecidos. Tipos: `character`, `numeric`, `logical`, `date`;
`length` é inteiro positivo e `decimals` não negativo, zero nos não numéricos.
Verificar limites por tipo do SDK antes da alocação. `nullable` registra
intenção do chamador, sem autorizar substituição de NULL. `caption`/`picture`
são strings; pictures afetam exibição, não precisão armazenada. Versão 1 exige
`nullPolicy: "reject"` e `roundingPolicy: "reject"`. Defaults, indicadores de
NULL separados e modos de arredondamento exigem contrato futuro explícito.
Preservar NULL no dataset mesmo quando a tabela nativa não o representar;
rejeitar conversão irrepresentável de NULL, encoding, número/faixa exatos e data.

Todos os membros de campo mostrados são obrigatórios. `inputFormat` é null
para destinos não data; destino data exige `"YYYY-MM-DD"` para DATE nativo do
transporte ou `"YYYYMMDD"` explícito para data textual declarada pelo chamador,
como VARCHAR(8) do Protheus. Validar calendário e tipo de transporte da origem;
nunca inferir formatos por nomes de tabela/campo. Usar CAST explícito do
chamador quando houver intenção de arredondar; o adapter não arredonda sozinho.

O adapter nativo de esquema explícito decodifica campos textuais **uma vez**
na fronteira UI/tabela nativa Protheus, preservando cópias
UTF-8/parsing seguro para NUL. Não decodificar JSON serializado nem aplicar
OemToAnsi em UTF-8. Verificar capacidade/NUL nativos e rejeitar truncamento/
substituição. Strings numéricas exatas só convertem com esquema do chamador e
precisão/faixa comprovadas no SDK, sem arredondamento implícito.

O adapter possui sua FWTemporaryTable e o exemplo local de browse possui seus
recursos de UI. O adapter reserva seu alias uma vez e cria tabela física e
índices por campo no primeiro carregamento. Paginação limpa/preenche o mesmo
armazenamento, sem alterar alias ou área vinculados ao browse. Aceitar a página
após validação/população bem-sucedidas. Falha invalida/limpa a página;
Close/Destroy final exclui o armazenamento próprio. Releitura completa é
diagnóstico opcional do construtor (`lVerifyStorage`, padrão falso), não segunda
varredura incondicional em produção. Restaurar a área selecionada anterior e
nunca fechar clientes/datasets/áreas do chamador. Arrays ficam nas fronteiras
exigidas pelo SDK; metadados e registros por chave usam hashes/JSONObject. Veja
o [ciclo de apresentação nativa](native-presentation.pt-BR.md).

## Prova T02 e etapas de implementação

T01 não tem decisão de contrato pendente. Suporte nativo é etapa empírica T02:
probes reproduzíveis usam dependências gerenciadas, sem credenciais privadas ou
substituição de executável instalado. Registrar prepare/bind/execute/fetch/
close, identidade de fontes/patch/driver e capacidades delimitadas.

- Cobrir tipos permitidos, NULL tipado, colunas anuláveis declaradas, vazio/só
  NULL, acentos/caracteres suplementares UTF-8, NUL, limites exatos inteiros/
  decimais e rejeições explícitas. Expressões constantes não comprovam colunas.
- Testar quantidades/nomes nativos de marcadores, anônimos repetidos, aspas/
  comentários, descritores/faixas inválidos, erros e statements válidos seguintes.
- Manter buffers/statements vivos até concluir leitura; liberar recursos
  próprios e restaurar conexão/área sob mutex SQL.
- Comprovar bind independente página/contagem por um snapshot de descritores,
  metadados estáveis entre páginas/vazios, totais e ausência de saída parcial.
- T03 integra apenas mapeamentos comprovados ao caminho Query/serviço/TLPP
  compartilhado; T04 adiciona apresentação; T05 homologa TCP/HTTP reais, UI
  nativa, falhas e liberação, preservando Query antiga.

Sem comprovar semântica nativa mínima, informar não suportado e registrar a
lacuna. Nunca enfraquecer contrato ou anunciar bind SQLMIX por teste isolado de
wrapper. Reuso MEMIO é
[trabalho futuro separado](evolution.pt-BR.md#resultados-em-memoria-entre-requisicoes).
