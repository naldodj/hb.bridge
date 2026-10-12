# Consumidores e exemplos Protheus

[English](README.md) · [Testes](../../tests/README.pt-BR.md) · [Dataset](../../docs/dataset.pt-BR.md)

Os exemplos continuam em `src/tlpp/tests/protheus/`, permitindo compilar
classes do produto e consumidores em uma única varredura TLPP. Cada grupo
tem seu diretório com nome pontuado; este guia não duplica os fontes.

| Entrada | Finalidade | Requisitos |
| --- | --- | --- |
| `U_HBBridgeConfigTest` | Configuração cliente AppServer. | INI ativo do AppServer. |
| `U_HBBridgeConnectionTest` | Relógio, Health, ADDON e Echo idêntico. | Endpoint TCP hbBridge e addon de teste. |
| `U_HBBridgeDataSetTest` | Metadados, totais, troca de perfil e navegação. | Somente mock; esperados 67 checks/31 chamadas, aceite de execução pendente. |
| `U_HBBridgeHelperTest` | Alias SQL, substituição e expressões de filtro. | Sem conexão/leitura ERP; esperados 12 checks, aceite de execução pendente. |
| `U_HBBridgeQueryTest`, `U_HBBridgeQueryTestSQLite`, `U_HBBridgeQueryTestTopInfo` | Fixture constante de query/páginas. | Perfil SQL remoto explícito; TopInfo resolve o alias no Protheus. |
| `U_HBBridgeHTTPTest`, `U_HBBridgeHTTPTestMSSQL`, `U_HBBridgeHTTPTestSQLite` | Serviços HTTP e SQL paginado. | Endpoint HTTP ativo, token cliente e perfil configurado. |
| `U_HBBridgeBrowseDataTestSRA`, `U_HBBridgeBrowseDataTestSX5` | Browse nativo, busca/filtro e visualização. | Interface Protheus, dicionário/contexto e tabelas/perfil dos exemplos. |

## Consumidor do dataset

```advpl
oDataSet := HBBridge.RDD.HBBridgeRPCDataSet():New(oClient)
oDataSet:SetAliasProfile(cProfile)
if oDataSet:OpenPage(cSQL, 1, 20, cOrderBy)
    while oDataSet:MoreToRead()
        xValue := oDataSet:FieldGet("NAME")
        oDataSet:Skip()
    enddo
    if !Empty(oDataSet:ErrorCode())
        // Tratar falha de página separadamente do EOF normal.
    endif
endif
oDataSet:Close()
```

O perfil é uma chave opaca e sensível a maiúsculas no servidor.
`SetAliasProfile()` configura explicitamente o perfil; `OpenSQL(cSQL[, jPage])`
e `OpenPage()` não o recebem mais no primeiro argumento. O chamador fornece
colunas projetadas e ordem determinística. Totais exigem outra contagem por
página e não são snapshot do banco. O guia dataset explica cópias e totais
desconhecidos.

## Browse interativo

Os fontes ficam em [hbbridge.browse.data.test](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.tlpp),
com parâmetros [SRA](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.sra.tlpp)
e [SX5](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.sx5.tlpp).
São exemplos ERP locais, não padrões do servidor genérico. Ajustar empresa/
filial, tabelas SQL físicas e ordenação no Protheus para a instalação.
`FWGetTopInfo()` escolhe um alias de exemplo; essa chave exata deve existir
no hbBridge.

`HBBridge.Client.HBBridgeBrowseData` resolve títulos/pictures/tipos SX3 no
Protheus e adapta uma página ao array exigido pelo FWBrowse. Copia os objetos
de linha para liberar a raiz JSON sem invalidar os registros exibidos. A ordem
segue as posições do header. Falha de consulta mantém linhas exibidas e
informa o erro; é necessário atualizar o dataset antes de continuar navegando.

O filtro atual aceita SQL do chamador com WHERE e sem ORDER BY/ponto e vírgula
finais. Acrescenta um predicado; não é parser SQL geral nem API de parâmetros
vinculados. `PrefixQryAlias()` preserva textos delimitados e comentários, mas
não resolve joins nem contexto ERP. Os helpers de apresentação não adicionam
regras de negócio ao servidor Harbour.

O teste query usa fixtures constantes por padrão. O quinto argumento opcional,
`lRunERPExamples := .T.`, habilita explicitamente exemplos SX5/SRA/SX3 locais
e a impressão de seus campos. Browses dependem de execução pelo operador;
não são executados pela regressão Harbour nem pelos mocks TLPP puros.

## Compilação e homologação

Usar [build-totvs.cmd](../../scripts/build-totvs.cmd) com includes do fornecedor.
Ele gera lista `.tlpp` recursiva explícita, evitando que o expansor AppServer
interprete diretórios pontuados como arquivos. O fluxo local exige terminal
administrativo e scripts TOTVS de parada/partida configurados, tentando
reinicializar mesmo após falha do compilador. O módulo temporário
`__rpo-legacy-cleanup` apenas substitui uma classe antiga no RPO; não é outra
implementação do produto.

Compilar não homologa interações de interface. Exercitar limites de página,
vazio/erro, buscas textuais/numéricas/datas, aspas nos filtros e abrir/fechar
repetidamente no AppServer real. A [homologação](../../docs/acceptance.pt-BR.md)
separa testes nativos, compilação e relatos do operador. Correções UTF-8/FLOAT
e credenciais cifradas continuam no [WIP](../../WIP.pt-BR.md).
