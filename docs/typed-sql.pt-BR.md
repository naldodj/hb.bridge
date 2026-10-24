# SQL tipado e apresentação nativa: rascunho do pacote 002

[English](typed-sql.md) · [WIP](../WIP.pt-BR.md) · [SQL atual](milestone3-sql.pt-BR.md)

Desenho T01 registrado em 2026-10-23 sobre a base `cbe4ccf` do projeto e Harbour
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, com o patch ODBC gerenciado.
Este rascunho está reservado para revisão; **T01 permanece inacabada**. O
trabalho de desempenho HTTP do hbBridge priorizado pelo usuário tem precedência.
Nomes de serviços e formatos propostos abaixo são insumos para revisão, sem
declarar nova API disponível ou conector homologado. T02 deve comprovar os
bindings nativos antes da exposição em T03. `RPCRDD.Query`, resultado versão 1
e chamadas atuais do dataset continuam preservados.

## Inventário e fronteira de implementação

| Componente | Implementação observada | Consequência |
| --- | --- | --- |
| [Serviço Query](../src/hb/services/hbbridge.query.hb) | `alias`, texto SQL, página opcional; área SQLMIX; tipo/comprimento/decimais do campo RDD; página e contagem separada | Não há contrato de bindings de valores nem metadados físicos completos. |
| [Leases SQL](../src/hb/services/hbbridge.sql.pool.hb) | Conexão nativa por chamada sob mutex SQL compartilhado; pooling físico ODBC opcional | Preservar posse/restauração; preparar statements não cria cursores persistentes nem cache de resultados. |
| SDDODBC | Execução direta; patch gerenciado cobre UTF-8, leitura, timeouts e pooling | Não há caminho atual de `SQLBindParameter`. Estender/comprovar a fronteira necessária. |
| SDDSQLITE3 | Prepara/executa SQL internamente, sem vincular parâmetros | Preparação isolada não comprova suporte a bind. |
| `hbodbc` | Expõe prepare/execute; nenhum wrapper de bind encontrado no contrib fixado | Não substitui diretamente a rota SDDODBC homologada. |
| `hbsqlit3` | Expõe APIs nativas de prepare/bind/step/column | Serve à prova/referência; não está integrado à query SQLMIX do produto. |
| [Dataset](../src/tlpp/hbbridge.rpc.dataset.tlpp) | Linhas nomeadas, cópias defensivas, totais e navegação | Reutilizar validação/navegação; ainda não existe método de parâmetros tipados. |
| [BrowseData](../src/tlpp/hbbridge.browse.data.tlpp) | Arrays da página atual no FWBrowse, navegação, filtros, títulos/máscaras do dicionário no Protheus e liberação | Reutilizar a apresentação; adapter FWTemporaryTable com esquema explícito é trabalho adicional. |

Fontes: [SDDODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddodbc/core.c),
[SDDSQLITE3](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddsqlt3/core.c),
[wrappers ODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c)
e [wrappers SQLite](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbsqlit3/core.c)
fixados. O [manifesto](../config/dependencies.json) e o
[patch](../config/patches/sddodbc.patch) identificam os insumos inspecionados.
Compilar um contrib não significa vinculá-lo/expor suas APIs no executável.

Duas lacunas afetam a compatibilidade. Query valida os valores necessários,
mas não rejeita todas as chaves superiores desconhecidas; um servidor antigo
poderia ignorar `bindings`. BrowseData ainda decodifica a linha serializada
com `DecodeUTF8(...:ToJSON())`/`FromJSON()`. T04 deve substituir essa fronteira
por conversão de campos com os helpers JSON seguros para NUL, preservando a
cópia do dataset. Este documento não declara essas lacunas corrigidas. O
fallback de esquema do filtro também usa comprimento RDD como decimais quando
não há SX3; T04 deve resolver decimais pelo esquema lógico explícito. O
SDDSQLITE3 atual não comprova fidelidade geral de NULL em colunas declaradas
nem leitura textual com NUL interno: campos mapeados podem substituir defaults
e a conversão textual depende de terminador. A regressão de expressão NULL
não comprova essas capacidades mais amplas.

## Entrada explícita e compatível

Reservar **`RPCRDD.QueryTyped`**, `requestVersion: 1` e `resultVersion: 2`
para o novo contrato. São nomes de desenho; nenhum serviço novo está
registrado. A entrada separada faz o servidor antigo retornar
`SERVICE_NOT_FOUND`, evitando executar SQL ignorando bindings. Discovery só
anuncia serviço/versão após integração; não promete tipos ainda não comprovados
para o perfil escolhido. Não há fallback para SQL com valores interpolados.

As duas entradas compartilham execução, paginação e liberação existentes,
sem criar outro motor de query. Estender a fronteira SDD/nativa apenas para
passar buffers tipados e preservar origem/NULL; T02 determina a extensão viável
por testes nativos reais. A interface atual de área/abertura recebe texto SQL
sem descritor de bind por chamada. Chamadas existentes de `RPCRDD.Query` sem
parâmetros mantêm o caminho homologado; uma chamada tipada proposta com
`bindings: {}` ainda exige as garantias da versão 2. Validar estritamente
envelope e versão antes do acesso ao banco. Auditar em T03
o comportamento de chaves ignoradas na Query antiga.

Requisição proposta, **não executável no serviço atual**:

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

`bindings` é objeto com chaves ordinais contíguas `"1"` até `"N"`; `{}`
representa ausência de bindings. Vincular por ordinal, sem depender da ordem
do hash. Usar marcadores posicionais anônimos `?`, com um descritor por
ocorrência. Marcadores SQLite nomeados/numerados, parâmetros de saída, lotes e
contratos de stored procedures ficam fora desta versão. Obter quantidade e
identidade dos marcadores no statement nativo preparado. Descritores tipados
vêm do chamador, complementados pelos metadados nativos disponíveis; SQLite
não fornece tipos declarados de parâmetros. Não contar interrogações no texto
SQL nem substituir conteúdo de literais/comentários.

Bindings fornecem **valores**, nunca nomes de tabelas/colunas, expressões ou
direção de ordenação. O chamador resolve/valida identificadores e predicados de
negócio. Preservar a validação de página/ordem. Vincular os mesmos valores de
base independentemente ao statement de página e à contagem, no mesmo lease.
Marcadores internos de paginação eventualmente adicionados exigem mapeamento
separado, sem deslocar ordinais do chamador. Bind continua sujeito às permissões
do banco; não equivale a autorização de tabelas ou parser SQL genérico.

Adições TLPP propostas: `OpenSQLTyped(sql, bindings[, page])` e
`OpenPageTyped(sql, bindings, number, size, orderBy)`, preservando assinaturas
atuais. Manter cópia defensiva de bindings para Next/PreviousPage, limpá-la em
close/reabertura e não reter JSON mutável do chamador. Serviço/versão/tipo não
suportado falha sem repetir por `OpenSQL` sem bindings.

## Tipos de valores, NULL e faixas

Todo descritor exige `type` e `isNull` lógico. NULL tem `isNull: true` e não
tem `value`; valor presente exige `isNull: false` e `value` do tipo previsto.
Rejeitar membros ausentes, contraditórios e desconhecidos. NULL, `""`, zero
e falso são distintos. NULL tipado ainda exige tipo SQL e informações de
precisão necessárias na fronteira nativa.

| Tipo proposto | Valor no transporte e validação | Prova nativa necessária |
| --- | --- | --- |
| `text` | String UTF-8 com comprimento explícito em bytes; preservar vazio/NUL interno | Bind/leitura Unicode MSSQL; texto SQLite com comprimento explícito. Não depender apenas de terminador. |
| `integer` | Número JSON integral em `[-(2^53-1), 2^53-1]`; consumidor preserva exatamente o inteiro recebido | Representação inteira no bind, com redução de faixa verificada. Produtor Protheus também respeita sua precisão numérica. |
| `int64` | String decimal canônica com sinal dentro da faixa de inteiro de 64 bits | Conversão/bind int64 verificados, sem double intermediário. |
| `number` | Número JSON finito, com semântica aproximada | Bind de ponto flutuante; sem formatação por SETs globais. Rejeitar NaN/infinito. |
| `decimal` | String decimal simples e `precision`/`scale` integrais, com `precision >= 1` e `0 <= scale <= precision`; representação exata, sem arredondamento implícito | Bind decimal exato e limites declarados do driver. SQLite não garante armazenamento decimal fixo nativo; rejeitar sem mapeamento exato explícito comprovado. |
| `boolean` | true/false JSON | BIT declarado no MSSQL e 0/1 no SQLite; sem conversão por valor verdadeiro implícito. |
| `date` | Data válida `YYYY-MM-DD`, sem fuso | Data SQL nativa no MSSQL; convenção explícita de texto ISO no SQLite. Texto vazio não é data nem NULL. |

Strings inteiras usam `-?(0|[1-9][0-9]*)`; zero inteiro não tem sinal
negativo. Strings decimais usam `-?(0|[1-9][0-9]*)([.][0-9]+)?`, sem
espaços, sinal positivo ou expoente; frações negativas como `-0.5` são válidas.
Os dígitos fracionários devem caber em `scale`; os inteiros, em
`precision - scale`, sem contar o zero antes de valor fracionário. Validar
os limites do driver sem arredondar.

Não anunciar toda a tabela como suporte implementado. T02 registra resultado
por conector/tipo, NULL tipado, rejeições e recuperação. Timestamp/fuso,
binários/LOB e arrays de parâmetros permanecem adiados. Limites dos drivers e
política de memória continuam aplicáveis, sem recuperar teto arbitrário do MVP.
String decimal exata não pode virar double apenas para reutilizar campo RDD.
CAST explícito permanece disponível; não recupera dígitos ausentes na origem
aproximada.

## Metadados e representação do resultado

Preservar versão 1. Versão 2 mantém `header`/`rows` por chave, posições
explícitas, rowCount e significados atuais de página/totais, separando:

| Grupo | Contrato |
| --- | --- |
| `rdd` | `type`, `length`, `decimals` observados no Harbour quando houver campo RDD; não renomeá-los como definições SQL/SX3. |
| `source` | Tipo/nome SQL nativo, precisão, escala, comprimentos em caracteres/bytes e nulabilidade quando disponíveis. Desconhecido é null explícito, sem inventar zero/falso. Tabela/coluna/collation de origem ficam desconhecidas em expressões ou descritores que não as informam. |
| `wire` | Representação (`text`, `number`, `integer`, `int64`, `decimal`, `boolean`, `date`) e UTF-8 para texto. int64/decimal exatos usam strings quando a leitura nativa preserva os dígitos. |
| `logicalSchema` do chamador | Tipo, comprimento, precisão, escala, política de NULL, título e picture por chave de projeção, resolvidos no Protheus e fornecidos à apresentação; sem inferência no servidor. |

Nomes/tipos exatos dos membros JSON do resultado ainda exigem revisão T01.
As decisões pendentes incluem representação estável entre linhas/páginas
(colunas int64 exatas permanecem textuais mesmo com valores pequenos), formato
de data da versão 2, tratamento de resultados time/timestamp nativos e política
de desconhecido/não suportado para expressões SQLite vazias, só NULL ou de
tipos mistos. Datas da versão 1 são serializadas como `YYYYMMDD`; a entrada ISO
acima não altera essa saída. Um exemplo concreto do envelope de resultado
continua sendo pré-requisito para concluir T01.

Determinar NULL SQL pelo indicador/tipo nativo **antes** de substituição por
defaults do RDD. `rows[ordinal][column] = null` significa NULL SQL; toda coluna
projetada deve existir em cada linha. Chave ausente é resultado malformado.
Getter de campo ausente/EOF que retorna Nil isoladamente não distingue esses
estados; usar existência do campo, posição atual e representação versionada
de NULL. Na versão 1, manter o comportamento observado sem prometer fidelidade
universal em colunas anuláveis. Versão 2 depende da prova desse caminho nativo.

FLOAT SQL permanece aproximado, sem escala decimal de negócio. Comprimento
de exibição não é precisão SQL. Não consultar SX3 automaticamente, reduzir
comprimentos físicos a campo RDD de 16 bits ou inferir escala pelos valores.
Não truncar texto, reduzir números ou substituir NULL silenciosamente.
Rejeitar mapeamentos não suportados. Manter a rejeição JSON de binários até
homologar representação binária própria.

## Posse e conversão na apresentação

Reutilizar UI paginada BrowseData/dataset e adicionar caminho com esquema
explícito, sem duplicar o browse. Adapter opcional FWTemporaryTable/FWMBrowse
possui objeto, alias, linhas e recursos de UI que criou. Clientes/datasets
fornecidos continuam pertencendo ao chamador. Construir em recursos privados
e publicar somente após validar esquema/popular com sucesso. Fechar/excluir
todos os recursos próprios em falha, encerramento normal e fechamento da UI;
não fechar a área salva do chamador. Restaurar a seleção anterior.

Texto JSON permanece UTF-8 nos dois sentidos. Decodificar valores textuais uma
vez na fronteira de exibição/tabela nativa do Protheus, preservando o snapshot
do dataset. Não decodificar documento JSON inteiro nem aplicar `OemToAnsi()`
a UTF-8. Preservar parsing/cópias seguros para NUL. Datas, lógicos e strings
numéricas exatas só convertem segundo esquema explícito e faixa nativa testada.

Uma tabela nativa pode não representar NULL SQL no tipo escolhido. O padrão
é erro explícito de mapeamento não suportado; o chamador pode optar por default
mais indicador separado de NULL. Nunca substituir silenciosamente. Arredondar
exige política explícita; sem ela, rejeitar conversão inexata. Pictures afetam
apresentação, sem definir precisão do valor armazenado. Arrays ficam nas
fronteiras de definição de campos/browse exigidas pelo SDK.

## Prova T02 e homologação seguinte

Criar probes nativos reproduzíveis com os fontes gerenciados, sem substituir
executável instalado nem incluir credenciais privadas nos fixtures. Comprovar
prepare/bind/execute/fetch/close reais MSSQL/SQLite, sem interpolação SQL.
Registrar versões de fontes/patch/driver e matriz explícita de tipos aceitos.

- Verificar acentos/caracteres suplementares UTF-8, NUL, vazio/NULL, faixas
  inteiras, aproximados, int64/decimal exatos, lógicos e datas. Cobrir colunas
  anuláveis declaradas além de expressões constantes.
- Testar aspas/interrogações/comentários, marcadores repetidos, bindings
  ausentes/excedentes, tipo/faixa/versão inválidos e erros do driver; recuperar
  com chamada válida.
- Verificar valores iguais em página/contagem, totais/vazios, cópias defensivas
  e compatibilidade Query antiga. Paginação continua com statements novos,
  sem prometer snapshot do banco.
- Garantir vida útil de statements/buffers até concluir execute/fetch e
  liberação em falhas; preservar restauração de conexão/área e mutex SQL.
- Após T03/T04, compilar TLPP alterado e homologar TCP/HTTP e apresentação
  nativa, falhas de NULL/tipo/encoding e liberação em T05.

A primeira decisão T02 é a menor extensão comprovada que preserve um motor
de query. Sem comprovar semântica exata/nativa, registrar capacidade não
suportada e a lacuna antes da integração. Reuso MEMIO é
[trabalho futuro separado](evolution.pt-BR.md#resultados-em-memoria-entre-requisicoes).
