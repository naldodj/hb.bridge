# Exemplo de turnover específico de aplicação

[English](README.md) · [Contrato do addon](../../docs/turnover-addon.pt-BR.md) · [Pacote de trabalho](../../WIP.pt-BR.md)

Este exemplo opcional mostra como um addon confiável de aplicação pode processar
dados de turnover. Ele não é um serviço de negócio genérico do hbBridge. O
Protheus é responsável por empresa, filial, autorização e resolução dos nomes
físicos das tabelas; outra aplicação pode fornecer outra consulta e contexto.

A ação `turnoverReport` do pacote chama `RPCRDD.QueryTyped` com `profile`,
`sql` e `bindings` fornecidos pelo chamador confiável. O SELECT deve retornar
uma linha por mês com as colunas abaixo:

| Origem SQL | Propriedade no resultado |
| --- | --- |
| `PERIODO` | chave do período e `period` (`YYYYMM`) |
| `TTRFSAI`, `TTRFENT` | `transferOut`, `transferIn` |
| `TFUNIMES`, `TFUNADMMES`, `TFUNMES` | `initial`, `admissions`, `active` |
| `TFUNDEMMES`, `TFUNFMES` | `dismissals`, `final` |
| `TURNOVER`, `TURNMOVF` | `turnoverPercent`, `dismissalPercent` |

A ação preserva os indicadores da origem, inclusive strings decimais exatas.
Ela não soma níveis, recalcula percentuais nem interpreta eventos da SRE.
Valores inválidos, campos ausentes e períodos duplicados falham sem dados
parciais. A ação `turnover` existente permanece como fixture separada por
funcionário-mês. Somente chamadores autorizados devem fornecer SQL; vincular
valores e resolver e validar identificadores no código confiável da aplicação.

Opcionalmente, `branchSql` e `branchBindings` fornecem os mesmos indicadores e
`RA_FILIAL`, com uma linha por período e filial. A resposta inclui `branches`,
indexado por período e filial, e `branchRowCount`. Chaves duplicadas ou um
período de filial ausente da empresa invalidam toda a resposta.

## Apresentação no FWWebEx

Após compilar `src/tlpp/tests/protheus/hbbridge.turnover.test`, o chamador pode
executar o exemplo pronto para Protheus/GEP sem criar outro programa:

```advpl
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealTCP")
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealHTTP")
```

Executar cada entrada com empresa e filial preparadas no Protheus. O exemplo
resolve os modelos ativos de turnover por empresa e filial na `ZZ_`, lê os lotes
cadastrados na `ZX_`, resolve os nomes físicos no Protheus e verifica se DBAccess
e hbBridge usam o mesmo servidor e banco MSSQL. Ele cria duas `FWTemporaryTable`
próprias, executa os lotes por `RPCRDD.Execute`, exibe o resultado do addon e
exclui ambas após o fechamento da janela. Após selecionar um mês, selecione
a empresa atual para exibir as filiais. O Protheus resolve as filiais da empresa
com `FWAllFilial` e `FWxFilial`; as duas consultas usam as chaves físicas assim
obtidas. Ao selecionar uma filial, a página consulta sob demanda o modelo
cadastrado de centro de custo para o período e a filial. A página informa o
carregamento e não repete automaticamente uma execução de resultado incerto.
Ao selecionar um centro de custo, consulta o modelo cadastrado de função para
período, filial e centro de custo selecionados. Ao selecionar uma função,
carrega os funcionários; o selecionado apresenta os indicadores da origem e o
nome e as datas de admissão e demissão atuais da SRA. Registros correspondentes
da SRE são apresentados separadamente, preservando campos P/D e indicadores de
correspondência. O recorte considera o período e a lotação selecionados e pode
omitir eventos históricos. As contagens vêm do modelo cadastrado e não são
recalculadas pela grade. A conciliação histórica e a validação visual com eventos
reais correspondentes permanecem pendentes. Recompile o pacote de addons instalado
antes de executar. Os lotes devem ter os formatos conhecidos; outros formatos são
rejeitados sem repetição automática. Empresa, filial e perfil SQL vêm do
contexto e da configuração atuais.

Sem informar períodos, o exemplo busca o último `RD_PERIODO` não excluído da
SRD resolvida e usa de janeiro até esse mês no mesmo ano. Se a SRD não tiver um
período válido, informe o intervalo explicitamente. Os argumentos opcionais são
perfil, período inicial e período final, por exemplo:

```advpl
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealTCP", "MSSQL/pData", "202301", "202310")
```

O período encontrado na SRD é um valor inicial, não uma garantia de movimentos
em todas as filiais e meses. O banco atual precisa conter os modelos GEP e o SQL
cadastrado; essa é uma dependência do exemplo de aplicação, não do núcleo do
hbBridge. O exemplo não grava registros de funcionários nos logs do projeto.

Alternativamente, uma aplicação que já possua uma tabela de origem preenchida
pode passar um SELECT confiável a `HBBridge.Examples.U_HBBridgeTurnoverReportTCP()`
ou `HBBridge.Examples.U_HBBridgeTurnoverReportHTTP()`. Os argumentos são, nessa
ordem, o SELECT, um perfil configurado, um `JSONObject` de parâmetros tipados,
um SELECT de filiais e o código da empresa. Os dois últimos são opcionais;
a empresa usa por padrão o contexto Protheus preparado. O SELECT opcional de
filiais deve conter seus próprios valores e retornar as colunas indicadas acima. O chamador mantém sua tabela de origem, conexão e contexto
de aplicação ativos enquanto a janela modal estiver aberta. Os parâmetros são
copiados; a apresentação não é dona do objeto ou da tabela temporária.

Por exemplo, depois de criar e preencher `oTemporary` com as colunas mensais
indicadas, a aplicação pode montar o SELECT usando o nome real desse objeto e
chamar uma das entradas. Os identificadores e o SQL devem ser controlados pela
aplicação, não fornecidos pelo navegador. A página apresenta os indicadores e as
barras mensais diretamente do addon. A seleção de um período não inventa
detalhes de funcionários, filiais ou centros de custo: esses níveis exigem
consultas adicionais e ainda não foram implementados. Um SELECT ausente é
rejeitado, sem exibir silenciosamente a fixture fictícia.

```advpl
cSQL := "SELECT PERIODO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES," + ;
    "TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM " + oTemporary:GetRealName()
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverReportTCP", cSQL, cProfile, NIL)
// Call oTemporary:Delete() after the modal page returns.
```

O perfil SQL deve apontar para o mesmo servidor e banco da tabela criada. O
chamador continua responsável por preenchê-la e excluí-la, inclusive em caso
de erro; usar a entrada HTTP para exercitar o outro transporte.

## Diagnóstico MSSQL local

O teste opcional para Windows e desenvolvimento usa o formato específico da
query de empresa cadastrada e examinada na aplicação GEP. Não é um parser SQL
genérico. O chamador fornece configuração e registro confiáveis, nomes físicos
de tabelas resolvidos, empresa, filial e intervalo com pelo menos duas linhas.
O perfil deve usar DSN MSSQL com autenticação SQL e HTTP habilitado. O teste
inicia um hbBridge isolado, adapta esse lote conhecido para preencher uma tabela
temporária global pertencente ao teste, chama `RPCRDD.Execute`, chama o addon
de exemplo, compara cada indicador mensal com a tabela e verifica a liberação
da temporária. Não imprime registros de funcionários nem credenciais. A query
executa com as permissões SQL configuradas e cria tabelas temporárias; usar
somente uma query confiável e ambiente de desenvolvimento autorizado.

Compile o executável gerenciado e um pacote de addons isolado antes de executar:

```powershell
pwsh ./scripts/build-hbbridge.ps1 -OutputDirectory ./tmp/turnover-server
pwsh ./scripts/build-hbbridge-addons.ps1 -Output ./tmp/turnover-addon/hbbridgeaddons.hrb

& ./examples/turnover/test-mssql-report.ps1 `
    -Config '<hbBridge.ini privado>' -Profile '<perfil MSSQL configurado>' `
    -Executable './tmp/turnover-server/hbbridge.exe' `
    -AddonRoot './tmp/turnover-addon' -QueryTable '<tabela ZX resolvida>' -QueryCode '<código da query de empresa>' `
    -BranchQueryCode '<codigo da query de filial>' -CostQueryCode '<codigo da query de centro de custo>' `
    -JobQueryCode '<codigo da query de funcao>' -EmployeeQueryCode '<codigo da query de funcionario>' `
    -Company '<empresa>' -Branch '<filial>' -Branches @('<filial 1>', '<filial 2>') -StartPeriod 202501 -EndPeriod 202510 `
    -TableMappings @{ SRA990='<SRA resolvida>'; SRE990='<SRE resolvida>'; SRJ990='<SRJ resolvida>'; CTT990='<CTT resolvida>'; SR7990='<SR7 resolvida>' }
```

As chaves do mapeamento identificam marcadores da query examinada, não nomes
fixos de tabelas no hbBridge. Elas são substituídas por identificadores
informados explicitamente. O diagnóstico não executa macros armazenadas do
Protheus nem valida todas as filiais, níveis de drill-down ou regras de negócio.
Permanecem pendentes a validação visual da apresentação com a origem fornecida
pelo chamador e a implementação dos níveis mais detalhados.

O parâmetro opcional `-BranchQueryCode` também compara as linhas de filial e
verifica a liberação das duas tabelas temporárias pertencentes ao teste.

O parâmetro opcional `-Branches` fornece as chaves de filial da empresa para
o diagnóstico. Sem ele, o diagnóstico usa somente `-Branch`.

O parâmetro opcional `-CostQueryCode` também executa o modelo de centro de
custo para o período inicial e `-Branch`, comparando as dimensões e indicadores
com a tabela temporária do teste. Não são gravados dados de funcionários.

O parâmetro opcional `-JobQueryCode` usa o primeiro centro de custo retornado
para consultar funções e comparar dimensões e indicadores, sem imprimir o código.

O parâmetro opcional `-EmployeeQueryCode` filtra pela primeira função e compara
os indicadores e atributos atuais da SRA sem imprimir dados pessoais.

O diagnóstico de funcionário também testa registros correspondentes da SRE e
uma fixture controlada com os dois sentidos, registros não relacionados e
collations diferentes. Retornos reais vazios não validam eventos reais.
