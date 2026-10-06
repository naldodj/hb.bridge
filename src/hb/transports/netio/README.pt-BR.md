# Transporte NETIO

[English](README.md)

[hbbridgenetio.prg](hbbridgenetio.prg) incorpora as APIs nativas `netio_Listen/Accept/Server`
ao mesmo executável. Threads e conexões pertencem ao host, que coordena parada,
reinício e rollback. Dados usam `0.0.0.0:2941`; administração usa
`127.0.0.1:2940` com credencial própria e raiz de arquivos desabilitada.

O filtro RPC expõe `HBBridge.Call`; o admin também expõe
`HBBridge.Admin.Status`. Serviços recebem valores Harbour pela serialização
nativa NETIO e compartilham o registro com o adaptador Protheus.
VF IO remoto binário é exercitado pela suíte de integração.
Configuração, exemplos e limites de escopo estão no [Marco 1](../../../../docs/milestone1.pt-BR.md).

`netioTimeout` é uma política operacional do host: o padrão `0` é convertido
para o timeout nativo `-1`, sem prazo. Valores positivos usam milissegundos
e devem caber no `int` da API nativa. `maxWorkers` tem padrão `64` e é
configurável; esse valor não é uma capacidade fixa do protocolo NETIO.

Os limites técnicos dos fontes Harbour examinados são:

| Recurso | Capacidade técnica |
| --- | --- |
| Credencial NETIO | Até 64 bytes (`NETIO_PASSWD_MAX`); o host rejeita valores maiores para evitar truncamento. |
| Arquivos abertos | Até 8.192 por conexão (`NETIO_FILES_MAX`). |
| Determinadas unidades RPC/streams | Campos de comprimento `uint32`, conforme cada operação. |
| Timeout nativo | Faixa do `int`; `HBBridgeRuntimeLimits()["netioTimeoutMsMax"]` informa a capacidade do build. |

Os comprimentos nativos de RPC/streams não são o campo decimal do frame
Protheus `HBBRIDGE/1` nem o volume lógico total de um arquivo. Serialização,
buffers, arquitetura e memória disponível também precisam ser considerados.
O host não acrescenta um teto geral de 16 MiB ao NETIO; as políticas de
payload/rede do adaptador Protheus são independentes.

Referências: [constantes e unidades NETIO](https://github.com/harbour/core/blob/master/contrib/hbnetio/netio.h),
[servidor nativo](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiosrv.c)
e [cliente nativo](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).
