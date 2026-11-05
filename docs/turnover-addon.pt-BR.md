# Exemplo de addon de turnover

[English](turnover-addon.md) · [Pacote de trabalho](../WIP.pt-BR.md)

Este addon experimental exemplifica uma regra de negócio específica executada
pelo serviço genérico `ADDON.Execute`. A aplicação chamadora fornece o perfil
SQL opaco, um SELECT confiável e parâmetros tipados; ela resolve empresa,
filial, nomes físicos, autorização e origem dos dados. Instalar apenas addons
confiáveis e conceder acesso SQL aos chamadores autorizados. A consulta usa
`RPCRDD.QueryTyped` com as permissões do chamador.

A primeira fixture fornece uma linha por funcionário, mês e lotação com as
colunas `PERIOD`, `COMPANY`, `BRANCH`, `COST_CENTER`, `JOB`, `EMPLOYEE`,
`ACTIVE`, `ADMISSION` e `DISMISSAL`. Período (`YYYYMM`), empresa e funcionário
são textos não vazios; filial, centro de custo e função podem ser vazios em
situações compartilhadas ou sem lotação. Os três últimos campos são inteiros
0 ou 1, sendo ACTIVE igual a 1. Uma repetição do funcionário na mesma
hierarquia completa é rejeitada. Dimensões ou indicadores NULL ou inválidos
falham sem substituição silenciosa.

Opcionalmente, `DETAILS_JSON` é uma coluna textual com um objeto contendo
`employeeName`, `admissionDate`, `dismissalDate` e `transfers`. As datas usam
`YYYY-MM-DD` ou `null`; `transfers` é `null` quando a origem não informa as
movimentações ou um objeto de eventos indexados. Cada evento contém `date`,
`direction` (`in` ou `out`), `fromBranch`, `toBranch`, `fromCostCenter` e
`toCostCenter`. Um objeto vazio declara que não há eventos na cobertura
fornecida. Dados inválidos são rejeitados, sem retorno parcial.

A grid exibe os valores de admissão e desligamento informados ao lado das datas.
As transferências são contadas pelo mês de cada evento e agregadas por nível;
se faltar o histórico de qualquer funcionário do grupo, os totais aparecem como
não informados. As transferências são apresentadas separadamente e **não entram
na fórmula experimental** abaixo. Datas, eventos e indicadores são dados da
origem; não há reconciliação automática nem inferência de regra do Protheus.
Para cada nó, `initial = active - admissions`; o turnover é
`round((admissions + dismissals) * 50 / initial, 2)` e o percentual de
desligamentos é `round(dismissals * 50 / initial, 2)`. Ambos são zero quando
initial é zero. O resultado é uma árvore JSON indexada por período, empresa,
filial, centro de custo, função e funcionário. Contagens entre períodos são de
funcionários-mês, não de funcionários distintos. A fórmula é um exemplo
limitado: transferências históricas, múltiplas lotações, elegibilidade,
interpretação dos períodos e equivalência exata com os relatórios existentes
no Protheus ainda precisam ser especificadas e validadas. Não é um relatório
homologado de RH ou folha.

A consulta e o resultado completo são materializados em memória; não há
streaming ou snapshot transacional entre chamadas. Erros não retornam totais
parciais. A página FWWebEx controlada inclui gráfico de barras, grid em cada nível e
detalhes de datas e movimentações na folha de funcionário. O cliente preserva
o UTF-8 recebido; a página converte o texto JSON antes da codificação do HTML
pelo FWWebEx. `U_HBBridgeTurnoverMarkupTest` verifica esse ciclo em AppServer
isolado.
A origem SQL ERP real, a saída em tabela temporária e a comparação de
desempenho ainda não foram implementadas. Essas atividades estão no WIP.

## Fixture controlada no AppServer

1. Compile o addon com `./scripts/build-hbbridge-addons.ps1`. O destino
   padrão é `addons/examples/hbbridgeaddons.hrb`. Se o servidor usar
   outro `AddonRoot`, informe em `-Output` o caminho correspondente a
   `examples/hbbridgeaddons.hrb` nessa raiz.
2. Compile o fonte TLPP mantido em `src/tlpp/tests/protheus/hbbridge.turnover.test`.
3. Execute `U_HBBridgeTurnoverTCP()` e `U_HBBridgeTurnoverHTTP()` em um ambiente
   Protheus cujo alias DBAccess corresponda a um perfil MSSQL do hbBridge. Cada
   entrada aceita um perfil explícito. São usadas apenas três constantes SQL,
   sem tabelas ERP; o resultado apresenta contagens e percentuais.

A fixture controlada passou no MSSQL por TCP e HTTP, tanto em chamadas diretas
quanto via TLPP em AppServer isolado. A
[evidência sanitizada](validation/turnover.fixture.windows.json) não inclui
dados reais do ERP. Duas capturas mostram as fixtures TCP e HTTP até o nível
de função com métricas, barras e botões de funcionários. Uma captura HTTP e a
confirmação do mesmo teste TCP registram o funcionário `001` selecionado, suas
métricas e o fim do drill-down. O retorno foi confirmado separadamente nas
duas entradas; o comportamento com dados reais permanece a validar. Para
execução CLI isolada, informe
`--profile=MSSQL/pData` e `--transport=TCP` ou `--transport=HTTP` em
`-run=U_HBBridgeTurnoverCLI`.

Confirmada a validação visual das novas grids e da navegação por período,
empresa, filial, centro de custo, função e funcionário, incluindo Back, nas
entradas TCP e HTTP. Essa validação usa a fixture controlada. As entradas são
U_HBBridgeTurnoverViewTCP() e
U_HBBridgeTurnoverViewHTTP(). Elas apresentam a mesma fixture MSSQL controlada;
FWWebEx deve estar instalado no RPO para usar essas entradas. Uma
verificação isolada do script da página está disponível com
`node tests/unit/hbbridge.turnover.page.test.js`; ela não substitui a homologação
visual no AppServer em outros ambientes.
