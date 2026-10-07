# Documentacao

[English](README.md)

[Arquitetura](architecture.pt-BR.md) fixa a divisão: Protheus resolve regras,
tenant, empresa, filial/xFilial e nomes físicos; hbBridge executa parâmetros
explícitos. Perfis são aliases opacos por chamada, sem banco demo fixo.

O hbBridge disponibiliza recursos de Harbour, C e Zig ao Protheus e a clientes
Harbour nativos. O [README principal](../README.pt-BR.md) distingue a implementação
do produto da arquitetura pretendida e o [TODO](../TODO.pt-BR.md) registra as entregas e os aceites.

A analise [Harbour VF IO e TRPC](harbour-vfio-trpc.pt-BR.md) detalha o suporte
planejado a `hb_vf*` e o reaproveitamento seletivo de `contrib/xhb/trpc.prg`.

A análise [Transportes, sessões e segurança](transports-sessions-security.pt-BR.md)
avalia as propostas locais de `brainstorming/brainstorming.md`: conexões
persistentes, contexto, TLS/JWT, limitações de `tGrpc` e AMQP opcional.
As decisões ainda dependem de implementação e homologação, conforme o TODO.

O [registro da reorganização](reorganization.pt-BR.md) descreve a estrutura aplicada,
o mapa de fontes e as verificações antes/depois da extração dos componentes.

[HTTP e administração web](http.pt-BR.md) descreve hbhttpd incorporado,
rotas HTTP/JSON para o registro comum, painel de status autenticado,
dependências e HTTPS opcional. Os [padrões](standards.pt-BR.md) usam arquivos
em minúsculas e funções, procedures, métodos, namespaces e classes em
PascalCase. [Dependências](dependencies.pt-BR.md) explica o bootstrap do
Harbour/hb_compile/Zig do próprio projeto, sem caminhos pessoais fixos.

O [exemplo HTTP TLPP](../examples/http/README.pt-BR.md) apresenta cliente
FWRest, configuração AppServer, bearer, RPC genérico e dataset SQL paginado,
com 13 checks homologados pelo operador em 2026-10-07.

A [análise de evolução](evolution.pt-BR.md) trata `THREAD STATIC`, HTTP Zig
opcional, resolução externa pelo hb_compile e tabelas para apresentação
Protheus, separando comportamento verificado de implementações futuras.

O [Marco 1](milestone1.pt-BR.md) documenta a implementação do registro nativo,
NETIO incorporado, configuração e administração. A [matriz de homologação](acceptance.pt-BR.md)
identifica o ambiente Protheus informado e o toolchain do servidor.

A [proposta de licenciamento](licensing.pt-BR.md) distingue a licença do
código autoral das dependências Harbour/Zig/zlib e registra a procedência
que precisa ser esclarecida antes da formalização. A escolha permanece pendente.

O [Marco 2 — fluxo TCP do produto](milestone2-framing.pt-BR.md) registra a primeira entrega:
gzip incremental no Harbour, leitura completa no TLPP, validação estrita e
contrato único `HBBRIDGE/1`, JSON e gzip. A rodada manual AppServer de 2026-10-03
confirmou Health, ADDON.Execute e dois Echo de 200.000 bytes idênticos,
incluindo gzip de requisição de 152.964 bytes. Handshake, blocos e compressão
negociada virão depois; homologação de timeout/falhas TLPP permanece pendente.
Na nova rodada manual registrada na sessão de 2026-10-04, o operador
confirmou novamente esse fluxo e o relógio Windows normalizado após
`Sleep(1000)`, com `result=OK`.

## Contrato implementado no produto

O [Marco 3 — SQL e paginação](milestone3-sql.pt-BR.md) descreve `RPCRDD.Query` sobre
SQLMIX, perfis SQLite/MSSQL, resultados por chave e páginas calculadas no SGBD
com `ROW_NUMBER`/`BETWEEN`. O cliente `HBBridgeRPCDataSet` e `U_HBBridgeQueryTest`
passaram no AppServer com SQLite em 2026-10-04: 29 checks verdadeiros,
incluindo páginas. MSSQL real e a ampliação de tipos/volume continuam pendentes.

[Configuração](configuration.pt-BR.md) descreve INI/JSON, arquivo padrão ao lado do
executável, precedência CLI, seções/perfis e metadados sem credenciais.
Também descreve `[hbBridge]` no INI do AppServer para os padrões do cliente
Protheus. O operador aceitou a nova leitura TLPP na sessão de 2026-10-04,
com todos os 13 checks de configuração verdadeiros, incluindo
`activeAppServerIni`, junto de Health, ADDON, Echo e Query `sqlite_demo`.
O relato não informa argumentos das chamadas nem log de compilação; destinos
diferentes dos padrões continuam pendentes, conforme a matriz de homologação.

O cliente `src/tlpp/hbbridgeclient.tlpp` envia requisicoes JSON com `service`
e `params`. O servidor escuta em `0.0.0.0:1512` (cliente local: `127.0.0.1`) e usa dispatcher
compartilhado com NETIO. `Health` responde pela biblioteca Zig; `Echo` devolve
os parametros recebidos e `ADDON.Execute` compila/carrega e executa modulos
Harbour, com `module` e `params` no objeto de parâmetros.

Antes da compressao, cada mensagem tem este formato:

```text
HBBRIDGE/1|JSON|<tamanho-em-bytes-do-JSON>\n<payload-json>
```

O cliente e o servidor usam somente `HBBRIDGE/1`, JSON enquadrado e gzip.
As constantes ficam em [includes/hbbridge.h](../includes/hbbridge.h),
compartilhadas pelos componentes e seus testes. A assinatura atual não implica
negociação de capacidades. Cada chamada abre uma conexão e o servidor fecha
após a resposta.

O frame inteiro, incluindo o cabecalho, e comprimido para envio. A indicacao
`JSON` descreve a representacao dos dados; o comprimento interno descreve o
JSON descomprimido, nao o total de bytes transmitidos pelo socket.

| Direcao | Compressao | Descompressao |
| --- | --- | --- |
| Protheus para Harbour | `GzStrComp` no TLPP | zlib incremental pela API C Harbour |
| Harbour para Protheus | Compressor gzip incremental pela API C Harbour | `GzStrDecomp` no TLPP |

Essa compressao e descompressao de strings está implementada no produto. O
cliente nao depende de arquivos temporarios nem das APIs de arquivos
`GzCompress`/`GzDecomp`.

O contrato não impõe tetos fixos de 16 MiB, oito dígitos de tamanho ou cabeçalho
de 128 bytes. O comprimento decimal canônico é comparado ao corpo efetivo;
a capacidade do cabeçalho deriva da estrutura e dos dígitos do runtime.
`protheusMaxPayloadBytes` e `protheusMaxWireBytes` usam `0` por padrão, sem
acrescentar um teto do aplicativo. O buffer de leitura padrão é 65.536 bytes
e o prazo operacional por fase é 30 segundos; o prazo `0` desativa o deadline
do servidor Harbour. `HBBridgeRuntimeLimits()` informa as capacidades reais
de strings, chunks de socket/zlib e timeout NETIO do build. O buffer cabe no
menor limite entre socket e codec; não limita o total da mensagem.
Os prazos e o uptime do servidor usam `HBBridgeMonotonicMs()`, sem relógio civil.
O TLPP passou a usar `TimeCounter()` pelos métodos estáticos da classe
`HBBridge.Client.HBBridgeTime`, em [hbbridgetime.tlpp](../src/tlpp/hbbridgetime.tlpp),
com regressão expirando o orçamento e teste de escala/espera no AppServer.
A normalização Unix × 1000 corrige a diferença de unidades reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12).
O operador confirmou o adapter no Windows alvo na sessão de 2026-10-04:
`Unix=false`, delta `1097.692700` e `1097.773500 ms` normalizados após
`Sleep(1000)`, com resultado `OK`. Outras plataformas permanecem pendentes.

O Harbour comprime/descomprime incrementalmente pela API C, respeitando
capacidades do runtime e políticas positivas configuradas. O TLPP acumula
gzip até o fechamento, confere retornos e frame exato; `GzStrComp`/`GzStrDecomp`
continuam sujeitos ao `MAXSTRINGSIZE` real do AppServer e à memória disponível.
A API TOTVS não limita a expansão durante a descompressão. Os dois lados
tratam envios positivos incompletos. O fluxo normal do cliente atualizado foi
confirmado manualmente no AppServer; timeout/falhas ainda precisam ser exercitados.
O corpo JSON ainda é materializado inteiro;
blocos lógicos e negociação permanecem no roadmap.

## Integracao nativa Harbour

O servidor hospeda RPC/arquivos nativos pela biblioteca `hbnetio`, no mesmo
processo do adaptador Protheus. O frame `HBBRIDGE/1` segue no
endpoint Protheus; clientes Harbour usam o protocolo NETIO no endpoint próprio.

O núcleo usa valores Harbour, registro versionado, tipos e permissões por
canal. `HBBridge.Call` permite chamar os serviços pelo NETIO; a descoberta
`Service.List` compartilha metadados com o adaptador JSON. O
serviço SQL reutiliza RDDSQL/SQLMIX e as contribs `sddsqlt3`/`sddodbc`,
vinculadas ao build do produto.

`hb_Serialize()`/`hb_Deserialize()` e `HB_SERIALIZE_COMPRESS` sao recursos
nativos do Harbour. O adaptador Protheus recebe JSON enquadrado em
`HBBRIDGE/1` após a descompressão gzip. A serialização binária Harbour usa o
transporte NETIO e tem teste de roundtrip explícito.
Datas, timestamps e bytes binários são preservados nos testes nativos.

O timeout NETIO padrão do host é `0`, convertido para `-1` nativo, sem prazo;
valores positivos configuram milissegundos. Os fontes examinados estabelecem
senha de até 64 bytes, 8.192 arquivos abertos por conexão e comprimentos
`uint32` em determinadas unidades RPC/streams. Essas capacidades pertencem ao
NETIO, independentemente do comprimento decimal do frame Protheus. Detalhes
e referências no [transporte incorporado](../src/hb/transports/netio/README.pt-BR.md).

## Syslog

O modulo `src/hb/telemetry/hbbridgesyslog.prg` implementa envio UDP para
`127.0.0.1:514` e esta incluido no build. O fluxo atual do servidor nao
chama `SyslogOpen`, `SyslogWrite` ou `SyslogClose`; portanto, nao ha emissao
Syslog integrada ao atendimento RPC. A conexao desse modulo ao ciclo de
vida do servidor e a validacao com o receptor ainda precisam ser feitas.

Os documentos de protocolo, arquitetura, seguranca, API de addons e
implantacao serao detalhados conforme a integracao nativa for estabilizada.
