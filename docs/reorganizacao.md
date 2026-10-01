# Reorganização dos fontes e validação

Em 2026-10-01, a estrutura prevista foi aplicada à implementação existente.
A referência anterior é o commit `b45595b24edf3002d80df69f9a412672173b5af0`.
O objetivo desta etapa é organizar responsabilidades e preservar o comportamento,
preparando os próximos marcos do [TODO](../TODO.md).

## Mapa de responsabilidades

| Origem | Destino | Responsabilidade |
| --- | --- | --- |
| `src/hb/server/server.prg` — `Main` | [host/main.prg](../src/hb/host/main.prg) | Entrada, opções e ciclo de vida do console. |
| `src/hb/server/server.prg` — recepção/envio | [transports/protheus/framing.prg](../src/hb/transports/protheus/framing.prg) | Enquadramento e compressão atuais. |
| `src/hb/server/mt_server.prg` | [transports/protheus/tcp_server.prg](../src/hb/transports/protheus/tcp_server.prg) | Listener, workers e encerramento. |
| `src/hb/dispatcher/dispatcher.prg` | [core/dispatcher.prg](../src/hb/core/dispatcher.prg) | Despacho/validação atuais, ainda com JSON. |
| Respostas dos serviços no dispatcher | [services/builtin.prg](../src/hb/services/builtin.prg) | Handlers `Health`, `Echo` e `ADDON.`. |
| Bloco C do loader | [c/zig_bridge.c](../src/c/zig_bridge.c) | Mesma API Harbour e chamada à função Zig. |
| `tests/harbour/` | [integration/harbour](../tests/integration/harbour/server_mt.prg) | Suíte MT e fixtures. |
| `tests/protheus/` | [integration/protheus](../tests/integration/protheus/hbbridgeconnectiontest.tlpp) | Teste TLPP existente. |

Loader, telemetria, cliente TLPP, biblioteca Zig, addon de exemplo e esboços de
configuração permanecem em suas áreas. As pastas anteriores de servidor,
dispatcher e testes foram substituídas; não há duas implementações ativas.

[hbbridge.hbm](../hbbridge.hbm) centraliza fontes/flags dos componentes.
[hbbridge.hbp](../hbbridge.hbp) acrescenta a entrada do produto;
[server_mt.hbp](../tests/integration/harbour/server_mt.hbp) acrescenta a entrada
de teste. [examples/mvp](../examples/mvp/README.md) executa o mesmo binário do
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
HRB com falha, isolamento dos estáticos por carga de HRB, limite de workers e
parada controlada. O [runner de testes](../scripts/test-hbbridge.ps1) prepara
fixtures e grava resultados em `tmp/tests-*/results.log`, sem substituir o
executável canônico. A execução TLPP no AppServer permanece pendente; o fonte
de teste foi apenas movido. Não foi feito teste interativo de depuração.

## Limites desta entrega

O bind, as assinaturas, o contrato JSON, a compressão, a porta padrão e os
retornos existentes foram preservados. NETIO continua apenas vinculado;
`transports/netio/` documenta a integração pendente. `tests/unit/` e
`tests/contract/` registram o espaço das futuras suítes, sem testes fictícios.
Registro de serviços, tipos nativos, streaming, SQL, VF IO, serviço e depuração
continuam dependentes dos marcos funcionais. As limitações de fragmentação TCP
do MVP também permanecem no roadmap.
