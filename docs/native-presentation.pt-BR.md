# Apresentação nativa pertencente ao chamador

[English](native-presentation.md) · [Contrato tipado](typed-sql.pt-BR.md) · [WIP](../WIP.pt-BR.md)

T04 implementa uma fronteira explícita de apresentação Protheus sobre o dataset
tipado existente. Protheus fornece o esquema lógico completo; o adapter não lê
SX3/TOP_FIELD, infere empresa/filial nem reescreve SQL. Exemplos existentes de
`HBBridgeBrowseData():Browse()` preservam a interface.

`HBBridge.Client.HBBridgePresentationSchema():Validate(header, schema, @code,
@message)` verifica correspondência da projeção, posições e definições do
chamador. `ConvertRow(header, schema, row, @converted, @code, @message)` publica
valores C/N/L/D somente após validar todos os campos. A entrada permanece UTF-8.

- Conversão de caracteres decodifica cada campo uma vez e exige roundtrip de
  encoding e capacidade em bytes. Nunca decodifica JSON serializado.
- NULL permanece na consulta/dataset. Este destino nativo o rejeita pela
  política `nullPolicy: "reject"`, mesmo com `nullable` verdadeiro. NUL também falha.
- Decimal/int64 exatos convertem para N somente se a formatação com tamanho/
  escala recuperar o mesmo valor exato, sem arredondamento ou escape DEC_CREATE.
  Destino character explícito pode conservar esses dígitos em texto.
- Lógicos exigem valores lógicos. Datas exigem formato ISO ou YYYYMMDD explícito
  e calendário válido, sem inferência por nome de campo.

O perfil nativo versão 1 usa C até 254 bytes, N até 32 posições e 16 casas,
D de tamanho 8 e L de tamanho 1. O formato numérico também precisa comportar
parte inteira, separador e sinal. São restrições do destino SDK, sem limitar
linhas/payload SQL nem precisão da origem. Tamanho declarado não comprova
fidelidade numérica: todo valor passa pela conversão; a releitura completa do
armazenamento é diagnóstico opcional.
Veja [DBCreate](https://tdn.totvs.com/display/tec/DBCreate) e
[modelo numérico do SDK](https://tdn.totvs.com/display/framework/SDK%2BMicrosiga%2BProtheus).

## Tabela e browse da página atual

```advpl
oNative := HBBridge.Client.HBBridgeNativeTable():New(oDataSet, jLogicalSchema)
if oNative:LoadCurrentPage()
    cAlias := oNative:Alias()
    // Consume the current-page alias in the caller's presentation.
else
    cCode := oNative:ErrorCode()
    cMessage := oNative:ErrorMessage()
endif
if oNative:Destroy()
    FreeObj(@oNative)
endif
```

`New(oDataSet, jLogicalSchema[, lVerifyStorage])` copia o esquema e reserva
um alias para a vida útil do adapter. O primeiro `LoadCurrentPage()` válido
cria sua `FWTemporaryTable` e um índice nativo de pesquisa por campo mapeado.
Os carregamentos seguintes reutilizam a **mesma tabela física, área, alias
e índices**, limpando as linhas por `FWTemporaryTable:Zap()` antes de preencher
a página atual do dataset. Navegação não exclui/reabre o alias nem substitui
a fonte de dados do browse.

`LoadCurrentPage()` não consulta nem move o cursor do dataset. Valida todas as
conversões e definições nativas dos campos antes de aceitar a página. Somente
então `Alias()` e `IsOpen()` expõem o resultado aceito. O alias reservado não
é exposto antes do primeiro carregamento bem-sucedido nem com página inválida.
`RowCount()` conta a página. `FieldName(projection)` mapeia nomes nativos gerados
com até dez caracteres; aliases SQL nunca são truncados ou avaliados.
`ProjectionName(position)` e `FieldCount()` preservam a ordem da projeção.
`Schema()` devolve cópia defensiva.

A pesquisa tem mapeamento separado: `SearchFieldName(projection)` devolve o
campo nativo indexado e `IndexOrder(projection)` devolve o número da ordem.
Projeções caractere, numérica e data usam seus campos de valores. Uma projeção
lógica conserva seu campo L, mas usa um auxiliar privado C(5) `True`/`False`
no índice, pois `FWTemporaryTable` não cria índice sobre L. Esse auxiliar não
integra a contagem pública de campos nem o esquema; use `FieldName()` para ler
o valor lógico real. Expressões de índices de data usam `DTOS(field)`. A ordem
de pesquisa usa o mapeamento explícito, não a posição física do campo, e é
preservada no preenchimento de outra página.

Para página não vazia, `FWBulk():CanBulk()` escolhe a estratégia de gravação
uma vez. Perfis DBAccess compatíveis usam `FWBulk` com o destino
`GetTableNameForTCFunctions()` da temporária e a estrutura de campos validada.
Linhas são enviadas na ordem dessa estrutura, com flush e fechamento antes de
`TCRefresh`. Falha em `AddData`, `Flush` ou `Close` invalida a página; o adapter
limpa explicitamente um preenchimento malsucedido ou exclui uma primeira
criação malsucedida. Não repete explicitamente o buffer bulk nem usa inserts
individuais após operação bulk parcial. É limpeza de destino próprio, sem
afirmar cancelamento do trabalho no servidor. Perfis sem suporte, incluindo
SQLite, mantêm gravação por registro, escolhida antes da inserção. Páginas
vazias conservam o esquema sem
abrir gravador bulk. `WriteMode()` informa `bulk`, `record` ou string vazia
quando não houve gravação concluída; fechamento/falha limpa esse diagnóstico.
Informa o caminho escolhido, sem representar medição de desempenho.

O caminho bulk usa `SetOption(1)`, documentado para LIB 20250630 ou posterior
e DBAccess 24.1.0.1 ou posterior. Veja [FWBulk](https://tdn.totvs.com/display/public/framework/FWBulk)
para contratos de capacidade e retornos. Arrays ficam nas definições nativas
de campos e na entrada FWBulk por linha; esquema e registros da página
permanecem objetos JSON. Ambos aplicam as mesmas regras de conversão de
esquema/valores.

`lVerifyStorage` tem padrão `.F.`. Passar `.T.` como terceiro argumento do
construtor ativa releitura nativa completa após gravação e comparação exata
antes de aceitar a página. Esse diagnóstico acrescenta outra varredura
completa; a navegação de produção não a executa por padrão. Os testes de
integração nativa inspecionam independentemente cada valor gravado, inclusive
com a opção padrão, sem depender de ativar varredura na implementação de
produção. Comparações de caracteres consideram os espaços da largura fixa nativa.

Para trocar de página, chame `NextPage()`/`PreviousPage()` do dataset
explicitamente e então `LoadCurrentPage()`. O carregamento invalida e limpa a
página anterior, preservando identidade da tabela/índices, inclusive em falha;
linhas antigas não são apresentadas como novo resultado. `ClearPage()` executa
essa invalidação/limpeza explicitamente, sem liberar armazenamento ou índices
já vinculados à interface. `Alias()` fica vazio e `IsOpen()` falso até um novo
carregamento válido. Não implica materialização completa, pré-busca ou snapshot
entre chamadas.

`Close()` exclui definitivamente a tabela nativa e seus índices, conservando
esquema e alias reservado para carregamento explícito posterior. Não é API
de navegação entre páginas.
`Destroy()` também libera configuração e referência emprestada ao dataset.
São explícitos/idempotentes; não fecham nem liberam dataset/cliente. Falha na
exclusão retém posse para nova tentativa e informa `PRESENTATION_CLOSE_FAILED`;
não libere o objeto após Destroy malsucedido. A área selecionada é restaurada.

`BrowseNative()` é uma função estática local do
[exemplo interativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.tlpp),
não um método público de `HBBridgeBrowseData`. O exemplo possui sua UI e recebe
dataset e adapter nativo emprestados. Uma API genérica reutilizável de browse
nativo permanece futura; o método `Browse()` existente é preservado. O
[contrato FWTemporaryTable](https://tdn.totvs.com/display/framework/FWTemporaryTable)
mantém a posse na thread Protheus que criou a tabela.

O exemplo interativo mantém um diálogo aberto com `FWBrowse` nativo.
`SetAlias()` é executado uma vez na construção da UI; callbacks de página
preenchem a mesma tabela indexada e atualizam o componente existente. Cada
coluna de pesquisa mapeada possui índice nativo correspondente, preservado
entre os carregamentos.
First, Previous, Next, Last e Refresh recarregam a página nativa nesse diálogo.
Close apenas encerra o diálogo, sem solicitar outra página. A pesquisa, o
filtro tipado Field/Operator/Value e a ação Clear filters usam o mesmo fluxo de páginas.
`U_HBBridgeNativeBrowse([nRecords], [nPageSize])` tem padrão de **1000 registros
sintéticos e 13 registros por página**. Para uma carga visual maior:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

O [cliente da fixture](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.client.tlpp)
recebe a quantidade em `HBBridgePresentationBrowseClient():New(nRecords)`.
Sem pesquisa/filtros, gera somente a página solicitada. Com critérios, avalia
todas as linhas configuradas da origem **antes** de selecionar a página;
correspondências e totais descrevem a fixture filtrada, não só as linhas visíveis. Esse
comportamento pertence ao exemplo, sem implementar filtro SQL genérico nem
cache cliente de todo o resultado. Chamadores reais devem fornecer suas
regras equivalentes de consulta/filtro explicitamente.

São sete projeções públicas, nesta ordem: `ID_CODE`, `ID`, `AMOUNT`, `TEXT`,
`FLAG`, `DAY`, `FLOAT`. `ID_CODE` é um código C(10) preenchido com zeros à
esquerda, para que a ordenação pelo índice caractere acompanhe a sequência
numérica visual dentro dessa largura. É gerado a partir do mesmo identificador
da linha usado em `ID`. `ID` continua string int64 exata no transporte e C(20)
na apresentação; o código adicional de exibição/ordenação não o converte para
ponto flutuante nem altera o contrato tipado.
A fixture permite critérios `contains` e `starts with` em `ID_CODE`, `ID` e
`TEXT`, além dos operadores de comparação tipados.
As colunas usam posições nativas independentes para cada campo da projeção.
Flag exibe `True`/`False` e conserva armazenamento lógico nativo; Day e Float
possuem seus próprios vínculos de data/número. Verifique essas colunas,
máscaras e acentos ao homologar a interface revista.

## Reproduzir validação

Use SDK/INI AppServer licenciado externo, RPOs, includes e perfil DBAccess
acessível para os testes opcionais de armazenamento nativo:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<sdk-ini>' -RpoDirectory '<vendor-rpos>' `
    -IncludeDirectory @('<totvs-includes>', '<project>/includes') `
    -NativeTables -NativeRows 10000
```

O runner cria suas próprias pastas descartáveis SDK/RPO/INI e não interrompe
serviços existentes. Compila fontes atuais e executa regressões de apresentação
e dos datasets tipado/comum. `-NativeTables` também executa a sonda SDK, testes
de tabela temporária real no DBAccess configurado e a fixture de colunas/
navegação sem interface. `-NativeRows` controla a carga sintética principal;
o padrão é 1025 linhas para ultrapassar o buffer bulk de 1024 linhas. Os casos
pequenos de paginação continuam com duas linhas seguidas de uma linha.
Logs brutos ficam locais;
credenciais/conteúdo INI não são evidência publicável. Fechamento interativo
do browse nativo e execução conjunta hbBridge/backend exigem aceite separado em T05.
Mock ou compilação isoladamente não comprovam UI.

Os registros são gerados em
[`HBBridgePresentationFixture:Row()`/`Result()`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.fixture.tlpp);
o [teste de armazenamento nativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.table.test.tlpp)
atribui valores alternados de Flag, Day e Amount com sinal, além de Float =
linha / 4. Chegam à tabela temporária DBAccess real e privada por dataset
tipado com mock; **não há leitura de tabela ERP nem consulta SQL de rede pelo
hbBridge**. A tabela é excluída no Close/Destroy final; os dados da fixture não
ficam disponíveis para inspeção após o teste. Para alterar a carga principal
diretamente, chame `U_HBBridgePresentationTableTest(10000)` ou use a entrada
CLI AppServer isolada `-run=U_HBBridgePresentationTableCLI --native-rows=10000`
com o ambiente preparado pelo runner.

`U_HBBridgeNativeBrowseTest()` verifica tabela/navegação nativas reais,
metadados de colunas e blocos vinculados aos valores sem criar componente
`FWBrowse` em thread de job. Essa fixture sem interface não ativa nem homologa
o diálogo; use `U_HBBridgeNativeBrowse()` em sessão interativa para aceite visual.
O cenário pequeno de navegação conserva 12 registros com páginas de quatro,
independentemente dos padrões interativos; asserções separadas exercitam uma
origem de 10.000 registros com páginas de 100.

Validação manual no AppServer registrada em **2026-10-26**, a partir da saída
de console fornecida: aprovados **50/50** checks de browse nativo e **56/56**
de tabela nativa. A execução de tabela usou **1025 linhas**, selecionou `bulk`
e ultrapassou o buffer de 1024 linhas. A saída também confirmou sete índices
nativos de pesquisa, incluindo o auxiliar lógico e a expressão de data, além
da identidade estável de alias/área/índices após recarga. Esses logs fornecidos
não identificam os hashes do executável ou dos RPOs. O teste de browse valida
dados nativos, vínculos das colunas e navegação sem ativar o diálogo; os
resultados não comprovam aceite visual nem aceite conjunto hbBridge/backend.

A reexecução isolada posterior em **2026-10-26** compilou **66 fontes** sem
erros e passou em **59 checks do browse / 62 da tabela nativa / 32 de conversão /
5 SDK**, além de **77 do dataset tipado / 67 do comum**, sem falhas de asserção.
A carga principal gravou e conferiu independentemente **10.000 linhas** por
FWBulk. As novas asserções cobrem códigos correspondentes, sequência indexada
9-para10, pesquisa/filtro por prefixo de Code e preservação do índice
selecionado após recarga/falha/recuperação. Veja o
[manifesto da revisão](validation/native.presentation.revision.windows.json)
para identidades dos fontes/RPOs e códigos de saída. Continua sendo aceite de
fixture sem interface, separado da integração SQL AppServer-hbBridge real.

Antes da revisão posterior de browse/FWBulk, a validação em 2026-10-25 aprovou
compilação de 64 fontes sem erros, 32 checks de
conversão, 34 de tabela nativa real, cinco asserções SDK e regressões dos
datasets tipado/comum 77/67, todos aprovados. O
[manifesto sanitizado](validation/native.presentation.windows.json) identifica
fontes, executável, RPOs e escopo. Campos caractere de largura fixa recebem
espaços à direita; o adapter confere o valor nativo com essa largura explícita.
Observações do formatador numérico ficam separadas da igualdade do valor nativo
e não comprovam armazenamento decimal exato para todo campo declarado.

Para homologação visual, compile o
[exemplo interativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.pt-BR.md)
e execute `U_HBBridgeNativeBrowse()`. Usa tabelas nativas reais sobre páginas
tipadas com mock. A navegação ocorre dentro do browse aberto; fechá-lo encerra
o exemplo sem confirmação da próxima página. Homologue a UI revista
separadamente dos checks CLI históricos, incluindo posição de Flag, Day e Float.
