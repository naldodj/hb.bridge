# Pacote 003 do hbBridge: escopo entregue e pendências adiadas

Este pacote está arquivado no escopo entregue. A validação visual do relatório mensal isolado e a reconciliação histórica permanecem abertas e foram adiadas no roadmap. Transferências reais da SRE não estavam disponíveis. Veja o [pacote ativo](../../WIP.pt-BR.md).

[English](package-003.md) · [Roadmap](../../TODO.pt-BR.md) · [Homologação](../../docs/acceptance.pt-BR.md)

## Pacote 003: addon de aplicação e drill-down de turnover

Os exemplos são compilados em um [pacote único de addons](../../docs/addon-bundle.pt-BR.md);
addons independentes permanecem compatíveis. O pacote usa um registro por
chamada de símbolos locais aprovados e `hb_ExecFromArray()` para execução.

- [x] Validar fixture mensal SQLite controlada e agregação no addon com SQL
  tipado, permissões herdadas e tratamento de falhas: integração nativa passou
  826 checks, incluindo 29 verificações de turnover. O pacote também passou
  94 checks do addon de benchmark.
- [x] Validar a fixture controlada MSSQL por TCP/HTTP diretos e pelos clientes
  Protheus em AppServer isolado: três linhas constantes passaram nos dois
  transportes. Ver [evidência sanitizada](../../docs/validation/turnover.fixture.windows.json).
- [x] Validar visualmente as novas grids e a navegação por período, empresa,
  filial, centro de custo, função e funcionário, incluindo Back, em TCP e HTTP.
  A origem passou em chamadas diretas MSSQL e no teste UTF-8 em AppServer isolado.
  Ver [evidência sanitizada](../../docs/validation/turnover.fixture.windows.json).
- [x] Validar visualmente a simulação atualizada do dashboard com três meses,
  drill-down e Back em TCP e HTTP. Validação confirmada para os períodos
  202609, 202610 e 202611; veja a [evidência sanitizada](../../docs/validation/turnover.fixture.windows.json).
- [ ] Criar um novo exemplo de turnover usando as consultas fornecidas como
  fontes de dados, adaptando a execução e o retorno ao hbBridge. Definir e
  validar suas medidas e navegação sem exigir uma implementação idêntica à
  anterior. A [análise das fontes](../../docs/turnover-reconciliation.pt-BR.md)
  registra SQL cadastrado, mapeamentos JSON e dashboard como referências.
  Em 2026-11-05, a integração nativa passou 834 checks, incluindo oito novas
  verificações da fixture isolada de datas.
- [x] Adicionar a ação opcional `turnoverReport` para resultados já agregados
  por empresa e mês. A integração nativa passou 843 checks. Um teste isolado
  Windows/MSSQL executou a query de empresa cadastrada em uma tabela temporária
  global própria, comparou todos os indicadores dos dez meses retornados pelo
  addon com a origem e confirmou a liberação da tabela. O intervalo histórico
  de 202301 a 202310 também passou na mesma comparação. Ver o
  [exemplo](../../examples/turnover/README.pt-BR.md).
- [ ] Validar visualmente o relatório mensal separado fornecido pelo chamador,
  em TCP e HTTP, com uma tabela temporária preenchida e pertencente ao Protheus.
  Quando somente o SELECT mensal é fornecido, não há detalhes por filial;
  os demais níveis exigem a entrada GEP pronta. O fonte TLPP atualizado compilou
  em AppServer isolado;
  os testes de markup e JavaScript passaram, inclusive a preservação de decimais.
- [x] Observar o exemplo GEP pronto de empresa em uma sessão Protheus preparada,
  em TCP e HTTP. Ele obtém por padrão o último período da SRD, resolve a query
  cadastrada na ZZ/ZX e é dono da tabela temporária de resultado. A preparação
  SQL passou dez verificações controladas e outra verificação em AppServer com
  o SQL cadastrado. O último período não excluído da SRD de desenvolvimento foi
  202310. Uma tentativa isolada de `RPCSetEnv` não conseguiu preparar a empresa;
  relatórios em sessão preparada exibiram medidas mensais de 202302 por TCP e
  de 202303 por HTTP. Essas observações não validam o drill-down nem a
  reconciliação dos indicadores de negócio.
- [x] Consultar o REST original do Protheus com os modelos reais de empresa e
  funcionários: sete verificações sanitizadas passaram, incluindo paginação e
  campos de funcionários. O teste valida o serviço original, não a integração
  hbBridge. Ver [diagnóstico](../../docs/turnover-addon.pt-BR.md#diagnóstico-do-rest-original-do-protheus).
- [x] Observar as páginas FWWebEx TCP e HTTP da fixture até o nível de função:
  as capturas mostram métricas, barras e dois botões de funcionário. Ver
  [evidência sanitizada](../../docs/validation/turnover.fixture.windows.json).
- [x] Validar a seleção do funcionário `001` nas duas entradas: captura HTTP e
  confirmação do mesmo teste TCP, com métricas e fim do drill-down.
- [x] Validar o retorno nas duas entradas visuais, conforme confirmação separada.
  A fixture controlada não comprova aceitação com dados reais.
  Não expor informações pessoais na evidência.
- [x] Validar a entrada CLI de JOIN em ambiente Protheus preparado: 24 checks
  passaram por TCP e 24 por HTTP, com 60 linhas e duas páginas em cada JOIN.
  O `RPCSetEnv` no ambiente isolado havia falhado antes dessa validação.
  Ver [evidência sanitizada](../../docs/validation/join.cli.windows.json).
- [x] Avaliar saída em tabela temporária do chamador por `RPCRDD.Execute`,
  comparar as opções e registrar limites e evidências na
  [análise de reconciliação](../../docs/turnover-reconciliation.pt-BR.md#opções-de-entrega-do-resultado).
  Escrita do turnover pelo addon e comparação de desempenho seguem futuras.

O addon pode conter regras de negócio; o núcleo permanece genérico. O contrato
inicial, a fórmula e as limitações estão no [exemplo](../../docs/turnover-addon.pt-BR.md).

- [x] Validar visualmente o detalhamento real por filial em TCP e HTTP na
  sessão Protheus preparada. Neste ambiente, `FWAllFilial()` retornou as
  filiais; passar `cEmpAnt` retornou um array vazio. Os
  lotes cadastrados de empresa e filial preenchem tabelas distintas do
  chamador; o escopo é a empresa atual, resolvida pelo framework Protheus. Um
  diagnóstico MSSQL isolado comparou todos os indicadores de dez meses e vinte
  linhas de duas filiais com suas
  respectivas origens.
- [x] Validar visualmente o detalhamento real por centro de custo em TCP e HTTP
  na sessão Protheus preparada.
  A requisição usa o período e a filial selecionados, executa sob demanda o
  lote cadastrado e libera a tabela temporária do Protheus. Um diagnóstico MSSQL
  isolado comparou 53 linhas com a origem. O teste da página verifica navegação,
  isolamento das seleções e ausência de repetição automática.
- [x] Validar visualmente o detalhamento real por função e o Back em TCP e
  HTTP na sessão Protheus preparada. O modelo
  cadastrado é executado sob demanda com período, filial e centro de custo
  selecionados. Um diagnóstico MSSQL isolado comparou quatro linhas com a origem;
  a página rejeita respostas de outro centro de custo.
- [x] Validar visualmente o detalhamento real por funcionário e o Back em TCP e
  HTTP na sessão Protheus preparada. O modelo cadastrado é executado para
  período, filial, centro de custo
  e função selecionados. Um diagnóstico MSSQL isolado comparou uma linha e
  seus atributos atuais da SRA com a origem, sem imprimir dados pessoais.
- [x] Validar a apresentação das evidências da SRE em TCP e HTTP com os dados
  de desenvolvimento. A SRE990 disponível estava vazia; a validação não
  demonstra a apresentação de uma transferência real.
A validação visual de transferências reais da SRE foi adiada para o
[roadmap](../../TODO.pt-BR.md#apresentação-nativa-e-resultados-compartilhados); não é
critério de conclusão deste pacote. Uma fixture MSSQL passou nos dois sentidos,
no isolamento por identidade e período e com collations diferentes. A SRE990
de desenvolvimento estava vazia; a apresentação de eventos reais não foi
validada. A consulta preserva campos P/D e pode omitir eventos históricos; as
contagens seguem o modelo cadastrado. A conciliação das regras e a completude
das evidências seguem futuras.

## Pacote 002 concluído em 2026-11-03

SQL tipado, apresentação nativa pertencente ao chamador, campos selecionados e
exemplos explícitos SRA/SRB e SRA/CTT passaram no escopo Windows/MSSQL registrado.
Integração nativa: **789 checks, zero falhas**. AppServer isolado: **83 fontes
TLPP**, **767 checks**, mais a sonda SDK. O dataset comum retornou -4 após 67
checks aprovados, conforme política do runner. O diagnóstico real dos JOINs
passou **24 checks por transporte**; browse, pesquisa e Views foram informados
como OK em TCP e HTTP.

As páginas ERP examinadas não apresentaram linha sem correspondência. Um LEFT
JOIN MSSQL sintético separado preservou NULL sem correspondência via TCP.
Outras combinações de compartilhamento, linhas ERP sem correspondência e outras
plataformas permanecem fora da homologação registrada. As identidades dos fontes
e os escopos estão no [manifesto sanitizado](../../docs/validation/join.presentation.windows.json);
o [histórico do pacote 002](../../docs/validation/package-002.pt-BR.md) preserva
as decisões e evidências anteriores. A [homologação](../../docs/acceptance.pt-BR.md#validação-dos-browses-join-em-2026-11-03)
e o [ChangeLog](../../ChangeLog.pt-BR.txt) registram o encerramento.
