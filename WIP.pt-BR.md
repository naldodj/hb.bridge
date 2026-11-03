# Pacote de trabalho ativo do hbBridge

[English](WIP.md) · [Roadmap](TODO.pt-BR.md) · [Homologação](docs/acceptance.pt-BR.md)

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

## Próximo pacote

O próximo pacote ainda não foi selecionado. Definir um objetivo delimitado e
seus critérios de conclusão a partir do [roadmap](TODO.pt-BR.md) antes de iniciar
nova implementação. Um snapshot somente de leitura dos relacionamentos da SX9
é candidato para discussão, não um recurso implementado nem um gerador SQL
automático; veja a [análise SX9](docs/sx9-relationships.pt-BR.md).
