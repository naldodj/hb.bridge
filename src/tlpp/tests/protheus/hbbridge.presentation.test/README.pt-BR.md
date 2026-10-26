# Testes de regressão da apresentação nativa

[English](README.md) · [Contrato SQL tipado](../../../../../docs/typed-sql.pt-BR.md)

T04 separa a conversão para apresentação da validação da tabela nativa e da
interface. Os testes deste diretório usam campos lógicos fornecidos pelo
chamador; não resolvem SX3, TOP_FIELD, empresa, filial ou tabelas físicas SQL.

A fixture determinística usa as implementações reais de `JSONObject`, dataset
e schema com o mock de cliente existente. As verificações cobrem validação do
schema, conversão UTF-8 exatamente uma vez, rejeição de NULL sem alterar o
dataset, formatos explícitos de data, largura/escala numérica sem
arredondamento e snapshots defensivos das entradas/saídas. Essas verificações
não exigem conexão SQL ou navegador.

Os testes da tabela nativa exigem ambiente Protheus preparado com DBAccess e
`FWTemporaryTable`. Validam o armazenamento real dos campos, página vazia com
metadados, posse dos recursos, restauração da área selecionada e liberação.
A apresentação consome um snapshot da página atual: não deve buscar a página
seguinte, substituir bindings ou fechar o dataset/cliente/áreas do chamador.
`HBBridgeNativeTable` escolhe FWBulk quando suportado e gravação por registro
nos demais casos; o teste percorre independentemente cada linha gravada e
compara os sete campos públicos. Checks separados de índice/pesquisa exercitam
o auxiliar privado de pesquisa lógica.
Releitura completa em produção é opcional pelo terceiro
argumento do construtor, `lVerifyStorage` (padrão `.F.`); a fixture pequena
também exercita `.T.`. O adapter reserva o alias uma vez e conserva a mesma
tabela física temporária, área e índices por campo durante preenchimento/
limpeza da página. Somente `Close()`/`Destroy()` final os exclui. Os testes
verificam identidade estável, pesquisa por índice após recarga e recuperação
sem substituir a fonte do browse. Consulte `WriteMode()` para identificar o
caminho efetivo; compilação ou perfil sem bulk não comprovam aceite desse
caminho. O guia informa os requisitos de LIB/DBAccess.

O fechamento da interface e o comportamento de `FWBrowse` exigem execução
visual separada. A aprovação da fixture de conversão não comprova o
armazenamento nativo, liberação no banco, suporte a codificações fora da página
de código local testada ou homologação da interface.

Execute `U_HBBridgePresentationTest()` para conversão e
`U_HBBridgePresentationTableTest([nRecords])` para armazenamento/posse nativos. A sonda
SDK é `U_HBBridgePresentationProbe()`. O
[guia de apresentação nativa](../../../../../docs/native-presentation.pt-BR.md)
documenta o runner isolado e a API pertencente ao chamador.

## Origem da fixture e quantidade de registros

Os dados são JSON tipado sintético, gerado por
[`HBBridgePresentationFixture:Row()`/`Result()`](hbbridge.presentation.fixture.tlpp).
O [teste de tabela nativa](hbbridge.presentation.table.test.tlpp) atribui o
número da linha a ID e sua forma de dez dígitos com zeros à esquerda a ID_CODE,
alterna Flag, Day (`2024-02-29`/`2000-02-29`) e Amount
com sinal (`123.25`/`-123.25`), define Float como linha / 4 e conserva `ação`
UTF-8 em Text. **Não há leitura de tabela ERP nem consulta SQL de rede pelo
hbBridge**. O mock fornece páginas ao dataset; DBAccess armazena somente o
destino temporário próprio, excluído na limpeza final.

A ordem pública da projeção é `ID_CODE` C(10), `ID` C(20), `AMOUNT`, `TEXT`,
`FLAG`, `DAY`, `FLOAT`. `ID_CODE` fornece ao índice caractere uma sequência
visual numérica (`0000000001`, `0000000002`, ..., `0000000010`). `ID` conserva
seu contrato de texto int64 exato, sem conversão para ponto flutuante na
ordenação. O código e o identificador de cada linha correspondem ao mesmo
número gerado.
Os critérios caractere da fixture permitem `contains` e `starts with` sobre
`ID_CODE`, assim como em `ID` e `TEXT`; a pesquisa pelo código com zeros não
fica restrita à igualdade exata.

A carga principal tem padrão de **1025 linhas**, ultrapassando o buffer de
1024 linhas do FWBulk. Os casos independentes de navegação permanecem fixos
em **2 + 1 linhas**; mudar a carga principal não redimensiona esses casos.
Execute uma carga principal maior diretamente:

```advpl
U_HBBridgePresentationTableTest(10000)
```

Para compilação/execução isoladas, use
`scripts/test-protheus-presentation.ps1 -NativeTables -NativeRows 10000` com os
argumentos de SDK/INI/RPO/includes documentados no guia. Sua entrada CLI é
`U_HBBridgePresentationTableCLI`, aceitando `--native-rows=10000`. É uma fixture
de correção/carga, não benchmark de tempo; escolha um tamanho compatível com
memória e prazo de execução do ambiente de teste.

## Verificações de browse interativas e sem interface

`U_HBBridgeNativeBrowseTest()` verifica metadados de colunas, blocos de valores
e tabela/navegação nativas sem criar componente `FWBrowse` em job CLI. Sua
aprovação não comprova aceite do diálogo interativo.

Após compilar no RPO de teste interativo, execute
`U_HBBridgeNativeBrowse([nRecords], [nPageSize])`. Os padrões são **1000 linhas
sintéticas e 13 linhas por página**, com armazenamento temporário real.
Aumente explicitamente as duas quantidades quando necessário:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

O gerador é `HBBridgePresentationBrowseClient():New(nRecords)`, no
[cliente da fixture](hbbridge.presentation.browse.client.tlpp). Sem critérios,
gera somente a página solicitada; com pesquisa/filtros, avalia toda a origem
configurada antes de paginar. O teste de navegação sem interface conserva o
cenário independente de 12 linhas/quatro por página e verifica separadamente
uma origem de 10.000 linhas com 100 linhas por página.

`BrowseNative()` é uma
função estática local [deste exemplo](hbbridge.presentation.browse.tlpp), não método de `HBBridgeBrowseData`;
uma API pública genérica de browse nativo permanece futura. Navegação entre
páginas, pesquisa e filtro ficam no mesmo browse aberto. Fechá-lo encerra o
exemplo sem perguntar se deve abrir outra página. Adapter e UI não fazem
pré-busca de páginas. `SetAlias()` vincula uma vez; callbacks preenchem a mesma
tabela nativa indexada e atualizam o componente. Oito botões oferecem First,
Previous, Next, Last, Refresh, Add filter, Clear filters e Close;
pesquisa e filtros tipados Field/Operator/Value são aplicados antes de selecionar
a página pelo [cliente da fixture](hbbridge.presentation.browse.client.tlpp),
com Clear filters para remover filtros e pesquisa. Não implementam
reescrita genérica de SQL. `FieldName()` mapeia valores; `SearchFieldName()` e
`IndexOrder()` mapeiam o campo/ordem nativa de pesquisa correspondente. Cada
projeção pública possui índice. Flag exibe `True`/`False` e conserva campo
nativo lógico; um auxiliar privado C(5) fornece seu índice de pesquisa, sem
ser coluna pública. Índices de data usam `DTOS(field)`. Verifique acentos,
datas, máscaras, alinhamento de Flag/Day/Float, sequência de ID_CODE, troca de
página, pesquisa, filtros, área selecionada e fechamento
normal/cancelamento. A fixture visual independe de serviço hbBridge ativo;
o aceite conjunto com backend permanece em T05.

## Validação registrada

A saída manual do AppServer fornecida em **2026-10-26** registrou **50/50
checks de browse nativo** e **56/56 de tabela nativa**, todos aprovados.
A execução de tabela selecionou `bulk` para **1025 linhas**, ultrapassou o
buffer de 1024 linhas e confirmou sete índices nativos de pesquisa, incluindo
o auxiliar lógico e a expressão de data. Os logs fornecidos não identificam
hashes de executável/RPO. O resultado de browse sem interface não ativa o
diálogo nem comprova aceite visual/backend. O
[manifesto de 2026-10-25](../../../../../docs/validation/native.presentation.windows.json)
é histórico: sua compilação de 64 fontes e checks 32/34/5 de conversão/tabela
nativa/SDK, além das regressões 77/67 de dataset, precedem a revisão de
browse/FWBulk.

A reexecução isolada posterior em **2026-10-26** compilou **66 fontes** sem
erros e passou em **59 checks do browse / 62 da tabela nativa / 32 de conversão /
5 SDK**, além de **77 do dataset tipado / 67 do comum**. A carga principal
gravou e verificou independentemente **10.000 linhas** por FWBulk. Os novos
checks comparam ID_CODE/ID, ordem indexada entre 9/10, pesquisa/filtro por
prefixo de Code e preservação do índice selecionado após recarga/falha/
recuperação. Veja o
[manifesto da revisão](../../../../../docs/validation/native.presentation.revision.windows.json)
para identidades e códigos de saída. A execução não ativa a UI.
