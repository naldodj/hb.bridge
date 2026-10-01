# Avaliação do brainstorming: transportes, sessões e segurança

Análise de 2026-09-30 das notas locais `brainstorming/brainstorming.md`,
dos fontes do hbBridge e das referências oficiais abaixo. A pasta de brainstorming
está ignorada pelo Git; esta análise em `docs/` registra as decisões publicáveis.
O original permanece
como registro de ideias; este documento registra as conclusões. Viabilidade
documental e inspeção estática não equivalem a homologação em Protheus.
Entregas e critérios de aceite estão no [TODO](../TODO.md).

## Decisões e prioridade

| Tema | Conclusão | Dependência/entrega |
| --- | --- | --- |
| Harbour/C/Zig, NETIO incorporado e catálogo comum | Preservar a base já acordada. | Marcos 0–1; uma implementação e um executável. |
| TCP persistente | Viável; começar sequencial, depois pool limitado. | Marco 2, após enquadramento incremental. |
| Multiplexação no mesmo socket | Viável, mas requer protocolo e coordenação próprios. | Etapa posterior, condicionada a necessidade e testes. |
| Execução isolada | Adotar contexto por chamada e recursos explícitos por sessão. | Marcos 1–3; limpeza e propriedade verificadas. |
| TLS | Priorizar `TSSLClient` e `hbssl`/OpenSSL no adaptador Protheus. | Prova antecipada no marco 2; homologação no marco 5. |
| JWT | Viável como credencial opcional, sobre canal protegido. | Contexto comum e autorização; marco 5. |
| gRPC por `tGrpc` | Condicionado ao contrato Smartlink documentado. | Investigação independente, sem bloquear SQL/VF IO. |
| AMQP | Viável como adaptador opcional de jobs/eventos. | Marco 6, com broker e garantias de entrega definidas. |
| Zig para buffers/transporte | Manter como frente de extensão com ABI C e medição. | Marco 4 e protótipos; sem reescrever stacks por antecipação. |

## Estado observado e persistência

O servidor atual faz bind em `0.0.0.0`, com porta padrão `1512` definida pelo
ponto de entrada. O destino local do cliente é `127.0.0.1`. A assinatura atual
é `HBBRIDGE/1`, com alias de compatibilidade `HBS1`. O brainstorming descreve a
versão anterior nesses pontos. Consulte [server.prg](../src/hb/server/server.prg)
e [mt_server.prg](../src/hb/server/mt_server.prg).

O [cliente TLPP](../src/tlpp/thbbridgeclient.tlpp) cria e fecha o socket dentro de
`CallService`; o worker atende uma requisição e encerra a conexão. A existência
de uma classe de socket não implementa reutilização automaticamente. Antes de
mantê-la aberta, ambos precisam enquadrar mensagens no fluxo TCP, tratar leituras
e escritas parciais e preservar bytes da mensagem seguinte.

A primeira entrega terá uma chamada ativa por conexão. O pool posterior terá
limite, aquisição exclusiva, prazo de espera, expurgo e separação por endpoint,
perfil de segurança e sessão. Compartilhamento entre jobs/threads do AppServer
depende de validação das regras de vida dos objetos TLPP. Conexões persistentes
reduzem custo de abertura e uso de portas efêmeras, mas continuam consumindo
sockets, buffers e, no modelo atual, workers.

Harbour expõe `hb_socketSetKeepAlive` e `hb_socketSetNoDelay` na
[API de sockets](https://github.com/harbour/core/blob/master/src/rtl/hbsockhb.c).
Não é necessário criar wrappers C apenas para habilitar essas opções.
Temporizadores de keepalive variam por sistema; detecção de aplicação parada
exige prazos e, se necessário, heartbeat. `TCP_NODELAY` será avaliado com carga.
Reconexão terá backoff/jitter e prazo total; reenvio de escrita exige idempotência
ou consulta do resultado anterior, pois perda da resposta não prova não execução.

Multiplexação requer IDs, leitor único e demultiplexação, escrita coordenada,
cancelamento e controle de produção/consumo. HTTP/2 não elimina bloqueio de
streams causado por perda no TCP, conforme a
[RFC 9113](https://www.rfc-editor.org/rfc/rfc9113.html#section-1).

## Contexto, sessões e durabilidade

O contrato deve garantir **isolamento por chamada**, sem prometer que toda
operação seja stateless. Cada requisição identifica correlação, prazo e contexto
autorizado. Empresa/filial informadas pelo cliente são conferidas contra sua
identidade; elas não constituem autorização por si mesmas.

Áreas de trabalho, opções SET, transações, buffers e estado de módulos precisam
de propriedade e limpeza garantidas. Uma nova thread não comprova isolamento
de STATICs, memória de extensões C/Zig ou conexões de drivers compartilhados.

Cursores, transações e arquivos VF são recursos vivos, registrados por sessão,
usuário/tenant, nó proprietário e expiração. O identificador remoto não os torna
duráveis. Por padrão, desconexão libera recursos transitórios; retomada exige
capacidade explícita, autenticação e revalidação, sem depender da identidade do
socket anterior. Operações sobre recursos vivos devem alcançar seu proprietário.
Balanceamento sem afinidade só se aplica onde não exista tal dependência ou
onde um mecanismo específico a resolva. Jobs duráveis precisam de armazenamento
e recuperação próprios; transações/handles não sobrevivem por guardar seu ID.

## TLS e JWT

A TOTVS documenta [TSSLClient](https://tdn.totvs.com/display/tec/Classe+TSSLClient)
como cliente de socket TLS genérico, disponível desde AppServer 19.3.1.0,
configurado pela seção `SSLConfigure`. É o candidato direto para o TLPP chamar
o hbBridge. O Harbour dispõe de [hbssl](https://github.com/harbour/core/tree/master/contrib/hbssl),
com bindings OpenSSL; isso fornece uma base, ainda não integrada ao listener.

A prova deve verificar versões TLS, cadeia de confiança e nome do servidor,
certificado inválido/expirado, renovação, prazos e encerramento. mTLS depende do
perfil escolhido e das APIs efetivamente disponíveis. Não haverá fallback
silencioso para TCP aberto quando a conexão protegida falhar. NETIO e administração
terão avaliação própria de proteção: TLS em um listener não protege os demais.

[tSktSslSrv](https://tdn.totvs.com/display/tec/tSktSslSrv) recebe conexões;
[tSktSslConn](https://tdn.totvs.com/display/tec/tSktSslConn) representa a conexão
aceita pelo servidor. São candidatos para callbacks recebidos pelo Protheus,
caso surja esse requisito. Seus exemplos históricos não definem a política TLS
do hbBridge e não devem motivar habilitação de SSL obsoleto.

[tJWT](https://tdn.totvs.com/display/tec/tJWT) documenta criação e verificação de
tokens, com abrangência a partir de 17.3.0.19. A interpretação do brainstorming
precisa de correção: **assinatura não é criptografia do conteúdo**. Um JWT
assinado não torna HTTP ou TCP sem proteção confidencial, nem impede o uso de
um bearer token capturado. TLS protege o canal; JWT representa identidade/claims;
o núcleo decide quais serviços e tenants essa identidade pode acessar.

O perfil proposto exige algoritmo permitido, assinatura, emissor, audiência,
expiração e `nbf`, além de chaves confiáveis e rotação. `kid` seleciona chaves
previamente confiáveis; não autoriza buscar qualquer origem enviada pelo cliente.
Decodificar claims não autentica. A implementação reutilizará biblioteca existente
com validação completa; bindings criptográficos, sozinhos, não compõem um validador
JWT. Emissão, renovação e revalidação em conexões persistentes terão contrato
próprio. Referência: [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html).

## gRPC: a restrição relevante é o contrato do cliente

A [documentação de tGrpc](https://tdn.totvs.com/display/tec/tGrpc), consultada em
2026-09-30, declara AppServer 20.3.1.0+ e modelo Smartlink predefinido pela TOTVS
no construtor. Passar `smartlink.proto` não comprova suporte a qualquer serviço
Protobuf. Há também divergência entre `sendMessages` na lista e `sendMessage`
nos exemplos; o método real precisa ser verificado no build alvo.

Por isso, `HB_Grpc` permanece uma proposta condicionada. A prova exige obter o
contrato efetivamente distribuído e suas condições de uso, implementar um
servidor compatível e testar chamada, erros, TLS, autenticação, metadados, prazos
e streaming que o cliente realmente exponha. Disponibilidade do protocolo gRPC
não implica disponibilidade de todas essas operações na classe TOTVS.

No hbBridge, avaliar biblioteca gRPC existente com ABI C, ou wrapper C sobre a
biblioteca escolhida, acessível por Harbour/C/Zig. Serviços e mensagens precisam
coincidir nas duas pontas, conforme o [modelo gRPC](https://grpc.io/docs/what-is-grpc/core-concepts/).
Não é necessário escrever HTTP/2, HPACK e Protobuf próprios. Zig permanece parte
do toolchain e das extensões em `src/zig/`; alegações de zero-copy ou melhoria de
latência dependerão de medição e regras de propriedade dos buffers.

## AMQP: jobs/eventos com dependência opcional

[tAMQP](https://tdn.totvs.com/display/tec/tAMQP) documenta AMQP 0.9.1 com RabbitMQ,
abrangência 17.3.0.x e parâmetro vhost desde 24.3.0.6. Há APIs de publicação,
consumo, ack e QoS, além de correlação/ReplyTo. Isso sustenta uma prova para
jobs/eventos, sem confirmar publisher confirms, nack/requeue ou TLS em todo build.
Esses pontos devem ser verificados antes de definir garantias ao usuário.

O adaptador converterá mensagens no mesmo contrato de serviços. RabbitMQ será
dependência externa somente quando habilitado; o hbBridge continua hospedando
NETIO e o adaptador Protheus em um executável. A integração consumidora poderá
reutilizar biblioteca C, acessível pela ponte C/Zig, após avaliar build e licença.

Fila durável, mensagem persistente, confirmação de publicação e ack do consumidor
têm papéis distintos. A proposta é confirmar consumo após persistir o resultado,
aceitar reentrega e impedir efeito duplicado por idempotência/deduplicação,
coordenada com a alteração de dados. Queda entre efeito e ack é um caso de teste.
Não se promete exactly-once. Referência: [confiabilidade RabbitMQ](https://www.rabbitmq.com/docs/reliability).

Definir TTL, retries limitados, fila de falhas, prefetch, autorização de ReplyTo
e correlação. Resultados grandes usarão páginas/streams ou referências, respeitando
os limites do broker e do AppServer. Se a API TLPP não expuser uma garantia
necessária, registrar a limitação e avaliar submissão ao `Jobs.*` do hbBridge,
com publicação feita por adaptador homologado no servidor.
