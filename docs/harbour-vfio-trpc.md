# Harbour VF IO e avaliação do TRPC

Esta análise orienta a implementação do hbBridge. O suporte descrito abaixo
entra no escopo e no roadmap; a fachada de arquivos e a adaptação do TRPC ainda
não estão implementadas no servidor.

Foram consultados os fontes Harbour da revisão local
`bee221e83e580d45076dfc9afa1ce43d9aba521b`, em 2026-09-29. O `trpc.prg`
coincidia com o upstream consultado, após normalização dos finais de linha.
As conclusões sobre seu comportamento são de leitura estática, sem execução
de testes TRPC nesta revisão.

## VF IO como base da camada de arquivos

`hb_vf*` é a interface PRG para a Harbour FILE IO API. Ela despacha operações
para os provedores registrados; o NETIO registra um desses provedores para
acesso remoto. A integração aproveitará essa abstração em vez de criar uma
implementação de arquivos para cada transporte. Fontes:
[vfile.c](https://github.com/harbour/core/blob/master/src/rtl/vfile.c),
[interface C](https://github.com/harbour/core/blob/master/include/hbapifs.h) e
[provedor NETIO](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).

| Grupo | APIs Harbour a integrar |
| --- | --- |
| Ciclo de vida | `hb_vfOpen`, `hb_vfClose`, `hb_vfTempFile`. |
| Transferência | `hb_vfRead`, `hb_vfReadLen`, `hb_vfWrite`, `hb_vfReadAt`, `hb_vfWriteAt`. |
| Posição e tamanho | `hb_vfSeek`, `hb_vfSize`, `hb_vfEof`, `hb_vfTrunc`. |
| Persistência e bloqueios | `hb_vfFlush`, `hb_vfCommit`, `hb_vfLock`, `hb_vfUnlock`, `hb_vfLockTest`. |
| Nomes e metadados | `hb_vfExists`, `hb_vfDirectory`, `hb_vfRename`, `hb_vfCopyFile`, `hb_vfErase`, atributos e datas. |
| Provedor | `hb_vfIsLocal` e opções de `hb_vfConfig` suportadas pelo backend. |

Disponibilidade e semântica precisam ser homologadas por provedor: seek,
truncamento, bloqueio, flush e commit não serão anunciados indiscriminadamente.
`hb_vfLoad`/`hb_vfSave` operam conteúdo em memória; transferência grande usará
leitura/escrita em blocos. Os retornos e `FError()` precisam ser capturados
conforme a operação; não há um retorno de sucesso uniforme para toda a família.

### Integração dos clientes

- **Harbour:** usar `hb_vf*` diretamente para arquivos locais e `net:` após a
  configuração/registro do NETIO. O handle permanece no processo do cliente.
- **Protheus:** expor uma família `Files.*` no registro de serviços. `Open`,
  `Read`, `Write`, `Seek`, `Stat` e `Close` são nomes propostos, ainda sujeitos
  ao versionamento do contrato. O servidor guarda o handle VF e entrega um
  identificador opaco ligado à sessão.
- **C/Zig:** consumir buffers com tamanho explícito ou a interface `hb_file*`
  através da ponte C, respeitando propriedade, threads e fechamento. A ABI
  não deverá transformar ponteiros internos em identificadores de rede.

O contexto da sessão resolve perfis de armazenamento e caminhos permitidos.
Handles não serão serializados nem expostos como descritores do sistema
operacional por `hb_vfHandle`. O mesmo vale para opções de `hb_vfConfig` que
revelem handles internos: somente opções aprovadas entram na fachada remota.

As operações de leitura e escrita retornarão contagem efetiva, EOF e erro
distintos. O contrato deverá tratar operações parciais, offsets sem perda de
precisão e fechamento em desconexão/expiração. Cada bloco respeitará a
negociação de memória, compressão e `MAXSTRINGSIZE`.

O aceite incluirá round-trip binário em armazenamento local e NETIO, ambos os
clientes, offsets, erros, permissões e liberação de recursos. Outros provedores
serão adicionados por homologação. VF IO cuida da entrada/saída; operações DBF
continuam usando os RDDs para semântica de registros, índices e bloqueios.

## O que aproveitar de contrib/xhb/trpc.prg

O arquivo contém `TRPCFunction`, `TRPCServeCon` e `TRPCService`; o cliente está
em `trpccli.prg`. Há registro e descrição de funções, nível de autorização,
execução em thread, loop/foreach e callbacks de progresso/cancelamento.
A recomendação é adaptar essas ideias ao núcleo de serviços e jobs do hbBridge.
[Fonte do servidor](https://github.com/harbour/core/blob/master/contrib/xhb/trpc.prg).

| Elemento | Destino proposto no hbBridge |
| --- | --- |
| Descrição de função, parâmetros e versão | Registro em `core/`, com tipos e nomes do contrato hbBridge. |
| Associação entre função e executor | Handlers de `services/`, com estado da chamada separado do catálogo. |
| Callbacks de execução | Eventos de progresso, resultado, erro e cancelamento dos jobs. |
| Loop/foreach | Referência para lotes com resultados por item e controle de recursos. |
| Descoberta do cliente | Referência para consulta de capacidades, mantendo os canais escolhidos. |

O `TRPCClient` implementa um protocolo próprio `XHBR`, com descoberta UDP e
chamadas TCP. Compartilhar serialização Harbour não o torna compatível com
NETIO ou `HBS1`. Seus mecanismos de conexão/recepção não serão acrescentados
como um terceiro transporte obrigatório.
[Fonte do cliente](https://github.com/harbour/core/blob/master/contrib/xhb/trpccli.prg).

### Pontos que exigem adaptação

No servidor analisado:

- `RecvFunction` rejeita comprimento original maior que **65.000 bytes** e
  aloca `Space(nComp)` a partir do tamanho comprimido recebido.
- `SendResult`/`SendProgress` usam compressão acima de **512 bytes**.
- A gramática de nomes não aceita ponto, como em `RPCRDD.Query`.
- `CheckTypes` compara `ValType`; `Run` modifica o array de chamada da instância.
- Metadados inválidos podem executar `Alert`/`QUIT`; `Authorize` retorna nível
  1 quando não há callback configurado.

Esses trechos exigem ajuste de limites, concorrência, validação e autorização
antes de qualquer extração de código.
[Implementação avaliada](https://github.com/harbour/core/blob/master/contrib/xhb/trpc.prg).

Há também um indício a reproduzir: o servidor envia `XHBR34` no cancelamento,
enquanto o cliente interpreta esse código como progresso acompanhado de dados.
É necessária validação do par cliente/servidor antes de reutilizar esse fluxo.
[Recepção no cliente](https://github.com/harbour/core/blob/master/contrib/xhb/trpccli.prg).

A contrib inclui camadas de compatibilidade: `StartThread` encaminha para
`hb_threadStart`; `hb_DeserialNext` é traduzida para `hb_Deserialize`.
O aproveitamento deve preferir as APIs Harbour nativas já usadas no produto.
Fontes: [xhbmt.prg](https://github.com/harbour/core/blob/master/contrib/xhb/xhbmt.prg)
e [xhbfunc.c](https://github.com/harbour/core/blob/master/contrib/xhb/xhbfunc.c).

## Decisão e próxima implementação

**VF IO será a base de arquivos; TRPC será uma referência de reaproveitamento
seletivo.** NETIO continua incorporado ao executável como transporte nativo,
e o adaptador Protheus mantém seu contrato próprio.

A primeira extração candidata do TRPC é o modelo de descrição e associação
entre serviço e executor. Ela deverá ser independente de sockets, ter argumentos
por chamada e aceitar nomes/tipos do hbBridge. Só haverá incorporação de código
depois de testes de contrato, erro e concorrência. Progresso e lotes serão
adaptados quando a frente de jobs avançar.

As entregas e os critérios de aceite estão no [TODO](../TODO.md); a arquitetura
geral permanece no [README](../README.md).
