# Reorganização dos fontes e validação

[English](reorganization.md)

Em 2026-10-01, a estrutura prevista foi aplicada à implementação existente.
A referência anterior é o commit `b45595b24edf3002d80df69f9a412672173b5af0`.
O objetivo desta etapa é organizar responsabilidades e preservar o comportamento,
preparando os próximos marcos do [TODO](../TODO.pt-BR.md).

## Mapa de responsabilidades

| Origem | Destino | Responsabilidade |
| --- | --- | --- |
| `src/hb/server/server.prg` — `Main` | [host/hbbridgemain.hb](../src/hb/host/hbbridgemain.hb) | Entrada, opções e ciclo de vida do console. |
| `src/hb/server/server.prg` — recepção/envio | [transports/protheus/hbbridgeframing.hb](../src/hb/transports/protheus/hbbridgeframing.hb) | Enquadramento e compressão atuais. |
| `src/hb/server/mt_server.prg` | [transports/protheus/hbbridgeserver.hb](../src/hb/transports/protheus/hbbridgeserver.hb) | Listener, workers e encerramento. |
| `src/hb/dispatcher/dispatcher.prg` | [core/hbbridgedispatcher.hb](../src/hb/core/hbbridgedispatcher.hb) | Registro/despacho/validação; valores nativos desde o Marco 1. |
| Respostas dos serviços no dispatcher | [services/hbbridgeservices.hb](../src/hb/services/hbbridgeservices.hb) | Hoje reúne Health/Echo/ADDON.Execute e descoberta. |
| Bloco C do loader | [c/hbbridgezig.c](../src/c/hbbridgezig.c) | Mesma API Harbour e chamada à função Zig. |
| `tests/harbour/` | [integration/harbour](../tests/integration/harbour/hbbridgeservertest.hb) | Suíte MT e fixtures. |
| `tests/protheus/` | [src/tlpp/tests/protheus](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp) | Teste TLPP, reunido à árvore compilável Protheus. |

Loader, telemetria, cliente TLPP, biblioteca Zig, addon de exemplo e esboços de
configuração permanecem em suas áreas. As pastas anteriores de servidor,
dispatcher e testes foram substituídas; não há duas implementações ativas.

[hbbridge.hbm](../hbbridge.hbm) centraliza fontes/flags dos componentes.
[hbbridge.hbp](../hbbridge.hbp) acrescenta a entrada do produto;
[hbbridgeservertest.hbp](../tests/integration/harbour/hbbridgeservertest.hbp) acrescenta a entrada
de teste. [examples/mvp](../examples/mvp/README.pt-BR.md) executa o mesmo binário do
produto e referencia seus clientes/addons.

## Verificações executadas

Ambiente: Windows, Harbour `3.2.1dev (r2608271822)` do perfil Zig de `hb_compile`,
Zig `0.16.0`. A cópia anterior foi compilada em pasta temporária a partir do Git,
independentemente dos fontes reorganizados.

| Execução | Resultado | Interpretação |
| --- | --- | --- |
| Suíte original sem ajustes | 44 verificações, 35 falhas; fixtures ausentes informaram skips. | O helper tentava conectar a `0.0.0.0`, inadequado como destino neste ambiente. |
| Produto anterior, teste com destino `127.0.0.1` e chamadas `.hrb` corrigidas, fixtures preparadas | 72 verificações, zero falhas, sem skips. | Referência funcional normalizada, sem alterar os fontes do produto anterior. |
| Componentes reorganizados e suite ampliada | 74 verificações, zero falhas, sem skips. | Mantém as 72 verificações e acrescenta `Health` pela ponte C extraída e compilação do addon PRG compartilhado. |
| Executável de produto reorganizado | Build aprovado, `--help` retorna 0 e opção inválida retorna 1. | Valida o novo ponto de entrada e sua composição. |

A suíte cobre as duas assinaturas, chamadas concorrentes, erros de requisição,
HRB com falha, isolamento entre HRBs concorrentes, limite de workers e
parada controlada. O [runner de testes](../scripts/test-hbbridge.ps1) prepara
fixtures e grava resultados em `tmp/tests-*/results.log`, sem substituir o
executável canônico. Na validação da reorganização, o fonte TLPP foi apenas
movido; A homologação no AppServer está OK,
conforme a [matriz](acceptance.pt-BR.md). Não foi feito teste interativo de depuração.
O teste atual distingue isolamento FORCELOCAL simultâneo da reciclagem
nativa de STATICs em recargas sequenciais; veja a
[semântica dos addons](milestone1.pt-BR.md#estado-hrb-e-propriedade-do-addon).

## Organização atual de nomes e build

Arquivos próprios usam nomes ingleses em minúsculas, com prefixo `hbbridge`
nos componentes do produto. Os pares classe/arquivo TLPP são:
`HBBridgeClient`/`hbbridgeclient.tlpp`, `HBBridgeConfig`/`hbbridgeconfig.tlpp`,
`HBBridgeTime`/`hbbridgetime.tlpp` e
`HBBridgeRPCDataSet`/`hbbridgerpcdataset.tlpp`. Funções, procedures, métodos,
namespaces e classes usam PascalCase por decisão explícita do responsável.
APIs nativas conservam sua grafia exigida. Veja [padrões](standards.pt-BR.md).

O Harbour segue a mesma convenção de nomes-base; a extensão identifica a
linguagem: Harbour próprio usa `.hb`, Protheus usa `.tlpp`, e addons compilados
usam `.hrb`. Builds comuns `.hbp` mantêm seu fluxo; `ADDON.Execute` também
aceita fontes `.prg` por compatibilidade. Os utilitários de commit ficam em
`.hbcommit/`. O bootstrap compila Harbour/hbrun do próprio projeto, sem
`bin/harbour` nem checkout
externo fixo; veja [dependências](dependencies.pt-BR.md). Documentos em
inglês têm correspondente `.pt-BR`.

## Limites desta entrega

Na entrega estrutural, bind, assinaturas, contrato JSON, compressão, porta e
retornos foram preservados; NETIO estava apenas vinculado, e `unit/` e
`contract/` reservavam as futuras suítes. O [Marco 1](milestone1.pt-BR.md) acrescentou
registro/valores nativos, listeners NETIO/admin, configuração e testes dedicados.
O [Marco 2](milestone2-framing.pt-BR.md) corrigiu o fluxo gzip/TCP e substituiu
os tetos de prova de conceito por políticas opcionais. O
[Marco 3](milestone3-sql.pt-BR.md) acrescentou SQL/paginação. A
[frente HTTP](http.pt-BR.md) usa hbhttpd e o mesmo registro. Fachada VF IO TLPP,
serviço de sistema, negociação e depuração continuam pendentes. Contagens
históricas não certificam renomes ou componentes posteriores, que exigem
build e regressões próprios.
