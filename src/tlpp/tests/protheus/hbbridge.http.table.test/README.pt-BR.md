# Tabela HTTP FWWebEx: validação confirmada

[English](README.md) · [Catálogo de consumidores](../../../../../examples/protheus/README.pt-BR.md) · [Homologação](../../../../../docs/acceptance.pt-BR.md)

Confirmada a validação do exemplo em **2026-10-13**, com as seis capturas
abaixo como evidências. FWWebEx apresenta tabela e filtros; Protheus prepara o SQL
e chama `HBBridgeHTTPClient`/`HBBridgeRPCDataSet` por HTTP.

A fixture contém **12 linhas**. A SX5 mostra **11.764 registros**, páginas
de 5/10 linhas, pesquisa por `TIPOS DE IMPOSTOS` e filtro por igualdade em
Description; ambas as telas filtradas mostram **1 registro de 11.764**.
A pesquisa por `Harbour` na fixture mostra **1 registro de 12**. A tela sem
filtro exibe `O'Brien`, `100%_done` e `<b>literal text</b>` como texto.

## Executar os consumidores

Compile toda a árvore `src/tlpp/`. As entradas interativas exigem FWWebEx,
seus componentes DataTable e `FWWebEx.Tools.FWExampleTools` no RPO, além da
interface Protheus e configuração HTTP/SQL do hbBridge operacionais.

- `U_HBBridgeHTTPTable()` usa a fixture constante e `[hbBridge] SQLProfile`.
- `U_HBBridgeHTTPTableSX5()` seleciona o perfil por `FWGetTopInfo()` no Protheus;
  Protheus resolve `RetSQLName("SX5")`, `xFilial("SX5")` e predicados de exclusão.
- Para configuração explícita, chame
  `HBBridge.Examples.HBBridgeHTTPTableExample():Show(lUseSX5, cProfile, cURL, cToken, nTimeoutSeconds)`.
  Configurações HTTP omitidas usam `[hbBridge]` do AppServer ativo.

O perfil precisa existir no hbBridge. Credenciais HTTP ficam no AppServer;
o navegador envia paginação, nomes de campos mapeados e valores dos filtros.

Esta validação visual abrange as telas interativas demonstradas.
Confirmada a execução do mock separado `U_HBBridgeHTTPTableTest()` em **2026-10-13
às 17:46:56 São Paulo**, thread **27708**: **71 checks, todos PASS, zero falhas**.
As 19 respostas enfileiradas foram consumidas sem chamadas inesperadas, incluindo
rejeição/preservação de NUL, recuperação após falha e tratamento de totais ausentes.
Veja o [registro da regressão](../../../../../docs/acceptance.pt-BR.md#validação-da-regressão-da-tabela-http-em-2026-10-13).
`U_HBBridgeDataSetTest()` e `U_HBBridgeHelperTest()` têm validação própria
confirmada às 17:56:23/17:56:45 na mesma data: 67 checks/31 chamadas e 12 checks,
ambos OK. D02 do WIP concluída; D03 acompanha integridade UTF-8/FLOAT mais ampla.
Veja o [pacote ativo](../../../../../WIP.pt-BR.md).

## Evidências SX5

Página de cinco linhas e total sem filtro:

<img width="1350" height="646" alt="SX5 five-row page" src="https://github.com/user-attachments/assets/bcd459ee-7d93-42ec-9d18-26fddf9ee5e1" />

Pesquisa textual global:

<img width="1353" height="643" alt="image" src="https://github.com/user-attachments/assets/6f646f52-16fe-474e-845d-bf38d68f5bcf" />

Página de dez linhas antes de aplicar o filtro preenchido:

<img width="1359" height="647" alt="image" src="https://github.com/user-attachments/assets/0554c5d3-f83a-41d8-af2e-b18667f68c80" />

Filtro por igualdade em Description:

<img width="1356" height="647" alt="image" src="https://github.com/user-attachments/assets/7f3b939e-49f0-440b-bf31-3a1dabff34fe" />

## Evidências da fixture constante

Dez linhas exibidas da fixture de 12, incluindo marcação literal:

<img width="1350" height="642" alt="image" src="https://github.com/user-attachments/assets/4144767d-2048-4eff-870f-00c792c25b47" />

Pesquisa global por Harbour:

<img width="1349" height="631" alt="image" src="https://github.com/user-attachments/assets/6935fb76-6201-4edb-89a9-566a9f7cf2a5" />
