# Marco 2 — primeira entrega: contrato e fluxo TCP

Esta entrega corrige a transferência existente e mantém as chamadas
`HBBridgeClient.New/CallService`. O construtor conserva os três primeiros
argumentos e acrescenta políticas opcionais de tamanho e buffer. Os serviços
usam o catálogo comum, incluindo
`ADDON.Execute` com `{module, params}` nos dois clientes. A homologação do Marco 1
permanece registrada separadamente em [acceptance.pt-BR.md](acceptance.pt-BR.md).

## Bytes e ciclo da chamada

Antes da compressão:

```text
HBBRIDGE/1|JSON|<bytes-do-JSON>\n<JSON>
```

`HBBRIDGE/1` é a única assinatura de requisição e resposta do adaptador Protheus.
O tamanho é decimal canônico, positivo, sem zeros à esquerda, e conta somente
os bytes do JSON. A quantidade de dígitos aceita deriva da capacidade de string
do runtime; não há teto fixo de oito dígitos nem cabeçalho fixo de 128 bytes.
O comprimento declarado é comparado à representação decimal do comprimento
real do corpo. O corpo deve ter exatamente esse comprimento; sufixos numéricos,
sinal, decimal, codec divergente, corpo truncado ou excedente são rejeitados.
O JSON é validado pelo adaptador após a validação do frame.

O frame inteiro forma uma unidade gzip. O cliente abre a conexão, envia a
requisição e o servidor envia a resposta e fecha a conexão. O servidor
reconhece o final do fluxo comprimido sem exigir que o cliente feche seu lado
de escrita. O cliente TLPP lê até o fechamento normal para descompactar a
resposta inteira. Não há persistência nem múltiplas chamadas nessa conexão.

O produto exige frame e gzip: assinaturas alternativas, JSON sem frame,
wrapper zlib e DEFLATE cru são rejeitados. O caminho Harbour continua usando
NETIO e serialização nativa. Os contratos anteriores ficam no histórico Git;
não há uma implementação paralela de MVP nem camada de retrocompatibilidade.

## Implementação

- [hbbridgeframing.prg](../src/hb/transports/protheus/hbbridgeframing.prg) preserva o estado
  de descompressão entre leituras, aplica as políticas configuradas e as
  capacidades do runtime e só despacha após o final válido. O prazo total
  de cada recepção/envio é configurável, com padrão de 30 segundos.
- [hbbridgedecoder.c](../src/c/hbbridgedecoder.c) chama `inflate` da zlib já
  vinculada pelo Harbour. O estado tem liberação explícita e finalizador GC;
  buffers de saída de 32 KiB respeitam a capacidade do runtime e, quando
  definido, o orçamento de expansão antes da criação das strings.
  CRC/trailer inválidos e bytes extras no mesmo bloco comprimido são rejeitados.
- [hbbridgecompressor.c](../src/c/hbbridgecompressor.c) usa a mesma zlib para
  gerar gzip incrementalmente, com estado por resposta, liberação explícita
  e finalizador GC. O servidor envia buffers comprimidos sem precisar
  materializar toda a saída gzip em uma única string.
- [hbbridgetime.c](../src/c/hbbridgetime.c) fornece
  `HBBridgeMonotonicMs()` para os prazos e o uptime do servidor. No Windows,
  usa `GetTickCount64`, sem contador compartilhado para estender wrap de 32
  bits. No POSIX, usa `clock_gettime(CLOCK_MONOTONIC)`. Falha se a fonte
  monotônica não estiver disponível, sem substituí-la pelo relógio civil.
- [Cliente TLPP](../src/tlpp/hbbridgeclient.tlpp) acumula bytes comprimidos,
  verifica `GzStrComp/GzStrDecomp`, exige frame exato e JSON válido, e retorna
  falhas com `success: false`, `error` e `code`. Envios positivos incompletos
  avançam somente pelos bytes enviados, sem repetir a chamada de aplicação.

A entrada Harbour com dois membros gzip na mesma leitura é inválida neste
contrato. Bytes enviados em leituras posteriores ao final reconhecido não são
processados: a conexão é encerrada após uma resposta. Não é um parser para
conexões persistentes; esse recurso exige o novo enquadramento externo.

## Políticas e capacidades dos runtimes

| Configuração do host | Padrão e significado |
| --- | --- |
| `protheusMaxPayloadBytes` / `-maxpayloadbytes` | `0`: sem teto adicional de aplicação para o JSON |
| `protheusMaxWireBytes` / `-maxwirebytes` | `0`: sem teto adicional de aplicação para a unidade gzip |
| `protheusReadChunkBytes` / `-readchunkbytes` | `65536` bytes por buffer de leitura/envio |
| `protheusTimeoutMs` / `-iotimeout` | `30000` ms por recepção/envio; `0` desativa o deadline Harbour |
| `netioTimeout` / `-netiotimeout` | `0`: usa `-1`, sem timeout na API NETIO nativa |
| `maxWorkers` / `-maxworkers` | `64` workers por listener, configurável |

Valores positivos de payload/wire definem uma política explícita da
instalação. O buffer de 65.536 bytes não limita o tamanho da mensagem.
`HBBridgeRuntimeLimits()` informa `stringBytesMax`, `socketChunkBytesMax`
(capacidade do argumento C `long`), `zlibChunkBytesMax` (C `uInt`) e
`netioTimeoutMsMax` (C `int`). O buffer deve caber no menor limite entre
socket e zlib, inclusive nas plataformas em que `long` tem 64 bits e
`uInt` tem 32 bits. Essas
capacidades técnicas continuam valendo com políticas de tamanho iguais a zero.
O cabeçalho é validado antes do corpo, com comprimento máximo derivado de sua
estrutura e dos dígitos necessários para a capacidade real de string.

O JSON ainda é remontado inteiro em memória. Strings, buffers, parsing e
cópias consomem memória simultaneamente; compressão incremental não equivale
a transferência lógica em blocos nem garante volume ilimitado.

A parada do listener Protheus drena os workers já admitidos, preservando a
conclusão das chamadas. Com `protheusTimeoutMs=0`, um cliente que não conclui
nem fecha a conexão pode manter a parada esperando indefinidamente.
Cancelamento forçado não está implementado nesta etapa. NETIO sinaliza e
fecha suas conexões para encerrar.

No Protheus, o construtor aceita
`New(cHost, nPort, nTimeout, nMaxPayloadBytes, nMaxWireBytes, nReadChunkBytes)`.
Os três argumentos adicionais usam `0`, `0` e `65536`; o timeout padrão
é `30000` ms e deve ser positivo. A semântica de timeout zero na API TLPP
ainda não foi homologada. `GzStrComp/GzStrDecomp` recebem strings inteiras;
o `MAXSTRINGSIZE` efetivo do AppServer e a memória disponível continuam
limitando cada mensagem. `GzStrDecomp` não recebe limite de saída. O cliente
verifica ISIZE antes da chamada e o comprimento real depois dela, aplicando
as políticas opcionais. ISIZE é um campo de 32 bits, módulo 2³², e pode ser
adulterado; não protege sozinho contra expansão excessiva. O uso atual de
gzip TLPP pressupõe um servidor confiável. Blocos independentes e modo
`none` continuam pendentes.

O timeout TLPP cobre conexão, leituras e verificações entre envios. `Send`
não oferece timeout como argumento, portanto uma chamada bloqueante pode
exceder esse prazo. O cliente passou a usar `TimeCounter()` por meio da classe
`hbbridge.client.HBBridgeTime`, com métodos estáticos em
[hbbridgetime.tlpp](../src/tlpp/hbbridgetime.tlpp), adaptados de
`dna.tech.StopWatch.__GetCurrentTimeStamp()`. Uma leitura por amostra substitui
`Date()`/`Seconds()`, e as diferenças usam milissegundos, sem um teto de um dia.
O adapter aplica Unix × 1000 para corrigir a diferença reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12):
milissegundos no Windows e segundos fracionários no Linux.
A descrição genérica da TDN omite essa diferença.
O teste Protheus compara a diferença
normalizada após `Sleep(1000)` antes de testar RPC, rejeitando unidade incorreta
ou contador que não avance durante a espera.
Ele também detecta eventual mudança de unidade em novos builds, para que
uma correção futura do AppServer não torne o contorno incompatível.

A documentação de `TimeCounter()` apresenta medição por diferenças entre
chamadas e exemplo com `Sleep`, mas não garante monotonicidade nem define wrap.
O prazo compara cada amostra à anterior e ao início: uma regressão expira o
orçamento, em vez de aumentar a espera. A precisão e o comportamento real do
contador continuam sujeitos à homologação por build/plataforma. A função
`__ConvertToTimeStamp()` do StopWatch não foi incorporada: converter data/hora
para epoch é uma operação diferente da medição por contador.
O prazo não limita o tempo de processamento interno de gzip/JSON.

Esse risco também existia no servidor: `hb_MilliSeconds()` chama
`hb_dateMilliSeconds()`, que usa hora civil UTC no Harbour inspecionado,
independentemente de não reiniciar à meia-noite. O hbBridge passou a usar a
fonte monotônica própria nos prazos e no uptime. Ela fornece contagens de
milissegundos para diferenças locais, não timestamps para persistir ou
comparar entre cliente e servidor. A resolução de `GetTickCount64` depende do
timer do Windows, normalmente de 10 a 16 ms; unidade de milissegundos não
significa resolução de 1 ms. O caminho POSIX foi compilado, mas não homologado
em execução nesta entrega.

## Validação

O runner [test-hbbridge.ps1](../scripts/test-hbbridge.ps1) compila os mesmos
componentes do produto e executa [hbbridgeframingtest.prg](../tests/integration/harbour/hbbridgeframingtest.prg)
junto às regressões do Marco 1. Os testes conferem conteúdo integral com
dados variados cujo gzip supera 65.535 bytes; fragmentam inclusive o header
e o trailer; verificam políticas de expansão, CRC inválido, bytes excedentes,
truncamento, parse estrito e continuidade do servidor após falhas. O teste
de cliente lento usa um prazo positivo explícito e verifica que um novo
fragmento não reinicia o orçamento de recepção.

Na etapa anterior de 2026-10-03, antes da remoção dos tetos fixos e da inclusão
do compressor incremental, passaram **196 verificações, zero falhas, sem skips**, com
Harbour `3.2.1dev (r2608271822)` e Zig `0.16.0`, Windows x64. Resultado em
`tmp/tests-74286b4b21314ae5af43f36267e9e69f/results.log`. O build do produto
isolado e sua opção `--help` também passaram. Os testes de transferência
grande verificam integridade e leituras múltiplas; não forçam por si só um
retorno parcial positivo de cada implementação de `Send`. Esse resultado é
histórico e não valida as alterações posteriores.

Na execução atual de 2026-10-03, passaram **305 verificações, zero
falhas, sem skips**, incluindo Echo com **24.000.000 bytes exatos** e JSON/gzip
acima de 16 MiB nos dois sentidos, compressão incremental, políticas zero
e tetos positivos explícitos, timeout positivo e sem deadline Harbour.
Um comprimento de nove dígitos foi validado sem alocar um corpo de 100 MB.
Resultado em `tmp/tests-1156a4ae33964edc925ff65e09748ddb/results.log`.
As verificações de orçamento da resposta comprimida e limite por chamada
zlib também passaram. O build isolado do candidato final e sua opção `--help`
passaram com as últimas guardas de capacidade.
As 29 verificações adicionais de [hbbridgetimetest.prg](../tests/unit/hbbridgetimetest.prg)
conferem inteiro não negativo, leituras sem regressão, avanço durante espera e
oito threads usando o mesmo relógio. Esses testes não alteram a hora do sistema.

O [teste Protheus](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp)
preserva Health/ADDON/Echo, compara os 200.000 caracteres integralmente e
acrescenta um Echo de dados ASCII variados. Antes da chamada, exige que o
gzip de teste exceda 65.535 bytes; os logs registram tamanhos e resultado
sem despejar todo o payload. O quarto argumento opcional
`nLargePayloadBytes` de `U_HBBridgeConnectionTest` permite escolher um Echo
adicional para medir o limite efetivo do AppServer; o padrão zero não o executa.
O teste também verifica a escala de `TimeCounter`, avanço durante espera e
aritmética do orçamento, incluindo expiração, frações, regressão e prazo maior
que 24 horas. Compile o novo `hbbridgetime.tlpp` junto dos demais fontes TLPP.

**Confirmado pelo operador em 2026-10-03:** Health, ADDON.Execute e os dois
Echo passaram no Protheus, com 200.000 bytes idênticos e gzip de requisição
de 152.964 bytes no caso variado. O registro completo está em
[acceptance.pt-BR.md](acceptance.pt-BR.md). Aquele trecho não informa os valores
do relógio nem o hash do binário usado.

Na confirmação manual recebida em 2026-10-04, o operador repetiu Health,
ADDON e os dois Echo com sucesso, junto ao teste de configuração INI com
13 checks e ao SQL SQLite com 29. O relógio também passou: `Unix=false`,
delta `1097.692700`, normalizado `1097.773500` ms após `Sleep(1000)`.
Isso aceita escala/avanço no Windows nessa rodada; não determina resolução,
wrap real ou comportamento no Linux. Hora/thread, argumentos e hash dos
artefatos dessa confirmação não foram informados.

A documentação de `Receive` descreve bytes positivos
e erro negativo, mas não distingue expressamente FIN de timeout. O cliente
trata retorno zero sem erro como fechamento normal e qualquer retorno
negativo como falha. O fechamento normal foi aceito nesta execução;
timeout/falhas e envio parcial positivo forçado ainda exigem testes no ambiente.

Na rodada anterior, o agente compilou um binário isolado em `tmp/marco2-product/hbbridge.exe`;
`out/hbbridge.exe` não foi substituído pelo agente. A sessão
do agente não tem permissão para parar esse processo elevado nem o AppServer.
Para atualizar a instalação, encerrar o hbBridge ativo, compilar o produto,
reiniciá-lo e usar [build-totvs.cmd](../scripts/build-totvs.cmd) no contexto
administrativo já usado na homologação anterior. Depois executar
[U_HBBridgeConnectionTest](https://localhost:4321/webapp/?p=U_HBBridgeConnectionTest&e=PROTHEUS).

## Continuação do Marco 2

Handshake pequeno sem compressão, comprimentos externo transmitido/expandido,
blocos independentes, codecs/compressão negociados, tipos e recursos por
sessão permanecem no [TODO](../TODO.pt-BR.md). Persistência/pool virão depois do
enquadramento incremental do protocolo. Gzip continuará obrigatório até a
negociação de compressão ser implementada nos dois lados. Remover um teto
adicional de aplicação não substitui transferência em blocos.

Referências: [TSocketClient:Receive](https://tdn.totvs.com/display/tec/TSocketClient%3AReceive),
[TSocketClient:Send](https://tdn.totvs.com/display/tec/TSocketClient%3ASend),
[TSocketClient:GetError](https://tdn.totvs.com/display/tec/TSocketClient%3AGetError),
[GzStrComp](https://tdn.totvs.com/display/tec/GzStrComp),
[GzStrDecomp](https://tdn.totvs.com/display/tec/GzStrDecomp),
[JSONObject:FromJSON](https://tdn.totvs.com/display/tec/JSONObject%3AFromJSON),
[API zlib](https://zlib.net/manual.html).
Referências de tempo: [Harbour — hb_MilliSeconds](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/rtl/seconds.c#L61),
[Harbour — relógio civil e timers](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/common/hbdate.c#L143),
[Microsoft — GetTickCount64](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-gettickcount64).
[TOTVS — TimeCounter](https://tdn.totvs.com/display/tec/TimeCounter) descreve a
fonte de tempo utilizada no adapter TLPP.
