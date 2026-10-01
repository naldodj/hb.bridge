# Documentacao

O hbBridge disponibiliza recursos de Harbour, C e Zig ao Protheus e a clientes
Harbour nativos. O [README principal](../README.md) distingue o MVP da
arquitetura pretendida e o [TODO](../TODO.md) registra as entregas e os aceites.

A analise [Harbour VF IO e TRPC](harbour-vfio-trpc.md) detalha o suporte
planejado a `hb_vf*` e o reaproveitamento seletivo de `contrib/xhb/trpc.prg`.

A análise [Transportes, sessões e segurança](transportes-sessoes-seguranca.md)
avalia as propostas locais de `brainstorming/brainstorming.md`: conexões
persistentes, contexto, TLS/JWT, limitações de `tGrpc` e AMQP opcional.
As decisões ainda dependem de implementação e homologação, conforme o TODO.

## Contrato implementado no MVP

O cliente `src/tlpp/thbbridgeclient.tlpp` envia requisicoes JSON com `service`
e `params`. O servidor escuta em `0.0.0.0:1512` (cliente local: `127.0.0.1`) e usa dispatcher
proprio. `Health` responde pela biblioteca Zig; `Echo` devolve os parametros
recebidos e `ADDON.` compila/carrega e executa modulos Harbour.

Antes da compressao, cada mensagem tem este formato:

```text
HBBRIDGE/1|JSON|<tamanho-em-bytes-do-JSON>\n<payload-json>
```

O servidor tambem aceita a assinatura legada `HBS1` e responde com a recebida.
O TLPP envia `HBBRIDGE/1` e aceita ambas nas respostas; atualize o servidor antes
dos clientes. A assinatura atual nao implica negociacao de capacidades.
Hoje cada chamada abre uma conexao e o servidor fecha apos a resposta.

O frame inteiro, incluindo o cabecalho, e comprimido para envio. A indicacao
`JSON` descreve a representacao dos dados; o comprimento interno descreve o
JSON descomprimido, nao o total de bytes transmitidos pelo socket.

| Direcao | Compressao | Descompressao |
| --- | --- | --- |
| Protheus para Harbour | `GzStrComp` no TLPP | `hb_ZUncompress` no Harbour |
| Harbour para Protheus | `hb_gzCompress` no Harbour | `GzStrDecomp` no TLPP |

Essa compressao e descompressao de strings ja esta implementada no MVP. O
cliente nao depende de arquivos temporarios nem das APIs de arquivos
`GzCompress`/`GzDecomp`.

O servidor valida um limite de 16 MiB para o tamanho do JSON declarado no
cabecalho, depois de descomprimir. Ainda e preciso limitar os tamanhos
comprimido e descomprimido durante a recepcao e consolidar o tratamento de
erros, timeouts e mensagens invalidas. A leitura atual tenta descomprimir
cada retorno de `Receive`/`hb_socketRecv` isoladamente. O servidor ja repete
envios parciais; o cliente TLPP ainda precisa desse tratamento. A robustez
contra fragmentacao TCP permanece no roadmap.

## Integracao nativa Harbour

O build ja referencia `hbnetio`, mas o servidor atual ainda nao inicializa
seu RPC. O frame `HBBRIDGE/1` do MVP (alias `HBS1`) e um contrato proprio e nao e compativel
diretamente com o protocolo de rede do `hbnetio`.

A integracao devera definir a adaptacao entre o contrato Protheus e as
funcoes expostas pelo Harbour, aproveitando o RPC do `hbnetio`, o runtime,
o carregamento de `.hrb` e os recursos existentes de acesso a dados. O
trabalho de SQL deve reutilizar RDDSQL/SQLMIX e as contribs de banco
existentes, conforme a disponibilidade no build escolhido.

`hb_Serialize()`/`hb_Deserialize()` e `HB_SERIALIZE_COMPRESS` sao recursos
nativos do Harbour. O servidor do MVP nao implementa um codec
`HB_SERIALIZED`: ele recebe JSON apos a descompressao. A serializacao
binaria Harbour nao e intercambiavel com JSON nem com o frame comprimido
do cliente TLPP; seu uso deve seguir o contrato nativo adotado na integracao.

## Syslog

O modulo `src/hb/telemetry/syslog.prg` implementa envio UDP para
`127.0.0.1:514` e esta incluido no build. O fluxo atual do servidor nao
chama `SyslogOpen`, `SyslogWrite` ou `SyslogClose`; portanto, nao ha emissao
Syslog integrada ao atendimento RPC. A conexao desse modulo ao ciclo de
vida do servidor e a validacao com o receptor ainda precisam ser feitas.

Os documentos de protocolo, arquitetura, seguranca, API de addons e
implantacao serao detalhados conforme a integracao nativa for estabilizada.
