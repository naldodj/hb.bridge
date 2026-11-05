# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

## Pacote 003: addon de aplicação e drill-down de turnover

Os exemplos são compilados em um [pacote único de addons](docs/addon-bundle.pt-BR.md);
addons independentes permanecem compatíveis. O pacote usa um registro por
chamada de símbolos locais aprovados e `hb_ExecFromArray()` para execução.

- [x] Validar fixture mensal SQLite controlada e agregação no addon com SQL
  tipado, permissões herdadas e tratamento de falhas: integração nativa passou
  826 checks, incluindo 29 verificações de turnover. O pacote também passou
  94 checks do addon de benchmark.
- [x] Validar a fixture controlada MSSQL por TCP/HTTP diretos e pelos clientes
  Protheus em AppServer isolado: três linhas constantes passaram nos dois
  transportes. Ver [evidência sanitizada](docs/validation/turnover.fixture.windows.json).
- [x] Validar visualmente as novas grids e a navegação por período, empresa,
  filial, centro de custo, função e funcionário, incluindo Back, em TCP e HTTP.
  A origem passou em chamadas diretas MSSQL e no teste UTF-8 em AppServer isolado.
  Ver [evidência sanitizada](docs/validation/turnover.fixture.windows.json).
- [ ] Definir e reconciliar as regras históricas de turnover com a implementação
  existente no Protheus antes de afirmar equivalência.
- [x] Observar as páginas FWWebEx TCP e HTTP da fixture até o nível de função:
  as capturas mostram métricas, barras e dois botões de funcionário. Ver
  [evidência sanitizada](docs/validation/turnover.fixture.windows.json).
- [x] Validar a seleção do funcionário `001` nas duas entradas: captura HTTP e
  confirmação do mesmo teste TCP, com métricas e fim do drill-down.
- [x] Validar o retorno nas duas entradas visuais, conforme confirmação separada.
  A fixture controlada não comprova aceitação com dados reais.
  Não expor informações pessoais na evidência.
- [x] Validar a entrada CLI de JOIN em ambiente Protheus preparado: 24 checks
  passaram por TCP e 24 por HTTP, com 60 linhas e duas páginas em cada JOIN.
  O `RPCSetEnv` no ambiente isolado havia falhado antes dessa validação.
  Ver [evidência sanitizada](docs/validation/join.cli.windows.json).
- [ ] Avaliar saída em tabela temporária do chamador por `RPCRDD.Execute`,
  comparar as opções e registrar limites e evidências de validação.

O addon pode conter regras de negócio; o núcleo permanece genérico. O contrato
inicial, a fórmula e as limitações estão no [exemplo](docs/turnover-addon.pt-BR.md).

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
e os escopos estão no [manifesto sanitizado](docs/validation/join.presentation.windows.json);
o [histórico do pacote 002](docs/validation/package-002.pt-BR.md) preserva
as decisões e evidências anteriores. A [homologação](docs/acceptance.pt-BR.md#validação-dos-browses-join-em-2026-11-03)
e o [ChangeLog](ChangeLog.pt-BR.txt) registram o encerramento.
