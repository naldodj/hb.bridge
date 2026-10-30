# Documentação do hbBridge

[English](README.md) · [Projeto](../README.pt-BR.md) · [Trabalho atual](../WIP.pt-BR.md)

Escolha o guia pela tarefa. Estes arquivos em inglês/português são a
documentação técnica mantida, versionada junto ao código. A Wiki apresenta
este índice como [portal de navegação](https://github.com/naldodj/hb.bridge/wiki/Home.pt-BR),
sem manter outra cópia de cada guia.

## Começar e configurar

| Guia | Utilize para |
| --- | --- |
| [Dependências e bootstrap](dependencies.pt-BR.md) | Resolver hb_compile, Harbour, Zig, drivers externos e requisitos de plataforma. |
| [Scripts de build, execução e validação](../scripts/README.pt-BR.md) | Compilar host/TLPP, iniciar exemplos e reproduzir checks isolados. |
| [Configuração do servidor e AppServer](configuration.pt-BR.md) | Definir INI/JSON/CLI, listeners, timeouts, políticas de recursos e padrões dos clientes. |
| [Credenciais](credentials.pt-BR.md) | Entender armazenamento atual, entradas da instalação e proteção portátil planejada. |
| [Exemplos Protheus](../examples/protheus/README.pt-BR.md) | Localizar entradas de cliente, dataset, query, browse e benchmark. |
| [Exemplo HTTP](../examples/http/README.pt-BR.md) | Consumir serviços por TLPP/FWRest com as credenciais HTTP configuradas. |

## SQL, datasets e apresentação

| Guia | Utilize para |
| --- | --- |
| [Serviço SQL e paginação](milestone3-sql.pt-BR.md) | Configurar perfis MSSQL/SQLite e páginas no SGBD. |
| [Dataset](dataset.pt-BR.md) | Ler headers/campos/linhas e percorrer páginas com posse explícita. |
| [Contrato SQL tipado](typed-sql.pt-BR.md) | Informar parâmetros tipados e distinguir tipos de origem, transporte e lógicos, NULL e valores exatos. |
| [Capacidades dos conectores](typed-sql-connectors.pt-BR.md) | Conferir bindings nativos e metadados dos resultados suportados. |
| [Apresentação nativa Protheus](native-presentation.pt-BR.md) | Converter páginas atuais em tabelas nativas próprias e exibi-las no browse. |
| [Metadados SX3 e campos selecionados](sx3-metadata.pt-BR.md) | Resolver definições do dicionário, exemplos SRA, aliases e nomes originais no Protheus. |
| [Relacionamentos SX9](sx9-relationships.pt-BR.md) | Analisar candidatos SRA/SRB e CTT/SRA para futuros exemplos de JOIN explícito. |
| [Posse de conexões SQL e pooling](sql-connections.pt-BR.md) | Entender posse por chamada, reutilização física e avaliações futuras. |

## Arquitetura e transportes

| Guia | Utilize para |
| --- | --- |
| [Arquitetura](architecture.pt-BR.md) | Entender executor genérico, regras do chamador, host único e adaptadores separados. |
| [Núcleo de serviços e NETIO incorporado](milestone1.pt-BR.md) | Acompanhar registro, ciclo do host, administração e gateway Harbour nativo. |
| [Enquadramento TCP Protheus](milestone2-framing.pt-BR.md) | Entender HBBRIDGE/1, JSON/gzip, capacidades do runtime e evolução da transferência. |
| [HTTP/REST e administração web](http.pt-BR.md) | Configurar hbhttpd, rotas, gzip, orçamento de envio e TLS opcional. |
| [Transporte NETIO nativo](../src/hb/transports/netio/README.pt-BR.md) | Utilizar RPC/arquivos Harbour nativos e conferir limites do upstream. |
| [Harbour VF IO e reutilização seletiva de TRPC](harbour-vfio-trpc.pt-BR.md) | Distinguir recursos nativos de arquivos das fachadas TLPP planejadas. |
| [Transportes, sessões e segurança](transports-sessions-security.pt-BR.md) | Analisar persistência/contexto, TLS/JWT e adaptadores opcionais futuros. |

## Desenvolver, depurar e medir

| Guia | Utilize para |
| --- | --- |
| [Padrões dos fontes e crivos de commit](standards.pt-BR.md) | Aplicar nomes, indentação, mapas, posse e os três checks obrigatórios. |
| [Mapa de responsabilidades dos fontes](reorganization.pt-BR.md) | Localizar host, serviços, transportes, clientes, addons e testes reutilizáveis. |
| [Depuração](debugging.pt-BR.md) | Planejar aceite do hbdebug nativo e futura integração HBDAP/editor opcional. |
| [Benchmark](benchmarking.pt-BR.md) | Executar medições e comparar o escopo das rotas cliente e servidor. |
| [Evolução do benchmark](benchmark-evolution.pt-BR.md) | Analisar processadores nativos C/Zig e extensões de ambiente propostos. |
| [Benchmark visual](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md) | Selecionar rotas, visualizar gráficos e exportar resultados. |
| [Testes reutilizáveis](../tests/README.pt-BR.md) | Localizar suítes nativas, de contrato e integração. |
| [Validação reproduzível](validation/README.pt-BR.md) | Localizar manifests sanitizados e recriar rodadas a partir dos fontes mantidos. |

## Decisões, andamento e contribuição

| Guia | Utilize para |
| --- | --- |
| [Pacote de trabalho ativo](../WIP.pt-BR.md) | Retomar a próxima tarefa delimitada e seus critérios de conclusão. |
| [Roadmap](../TODO.pt-BR.md) | Conferir entregas futuras, pré-requisitos e critérios de aceite. |
| [Histórico de homologação](acceptance.pt-BR.md) | Consultar resultados datados, identidades, plataformas e limitações. |
| [Análise de evolução](evolution.pt-BR.md) | Analisar estado de workers, motores HTTP opcionais, apresentação e resultados em memória futuros. |
| [Análise de extensões](extensions-review.pt-BR.md) | Avaliar ideias opcionais de SQLRDD, Duktape e CCHarbour. |
| [Revisão dos utilitários FWWebEx](fwwebex-tools-review.pt-BR.md) | Analisar candidatos de clone JSON, merge, flatten e medição antes de reutilizar. |
| [Licenciamento e proveniência](licensing.pt-BR.md) | Consultar decisão global pendente e termos dos fontes/dependências existentes. |
| [Apoio ao projeto e suporte corporativo](support.pt-BR.md) | Contribuir com feedback ou contatar a DNA Tech para serviços especializados. |

## Manter este portal

Edite estes índices versionados e o guia pertinente nos dois idiomas. Gere a
navegação Wiki com `pwsh ./scripts/prepare-wiki.ps1`; veja o
[fluxo de publicação](../scripts/README.pt-BR.md#portal-wiki).
As páginas geradas ficam em `out/` descartável; os guias-fonte permanecem aqui.
