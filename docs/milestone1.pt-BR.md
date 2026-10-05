# Marco 1: núcleo comum e NETIO incorporado

O host de console hospeda o adaptador Protheus e a biblioteca `hbnetio` no
mesmo processo. Ambos usam o registro de serviços de
[hbbridgedispatcher.prg](../src/hb/core/hbbridgedispatcher.prg). O host cria o catálogo antes
dos listeners; `HBBridgeRegistrySeal()` encerra o registro pela API pública.
O catálogo não contém parâmetros ou resultados mutáveis de uma chamada.

## Configuração e execução

Compile o produto e execute a partir da raiz:

```powershell
.\scripts\build-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
.\out\hbbridge.exe "-config=config/examples/hbbridge.ini"
```

Os exemplos [INI](../config/examples/hbbridge.ini) e
[JSON](../config/examples/hbbridge.json) mantêm os padrões NETIO
`0.0.0.0:2941`, administração `127.0.0.1:2940` e Protheus `0.0.0.0:1512`.
Administração só inicia quando `adminPassword` contém uma credencial.
`netioRoot` é criado pelo host, se necessário. `addonRoot` localiza os módulos;
a ausência de um módulo produz erro na chamada. Os diretórios de execução e
os arquivos de credenciais pertencem à instalação, não ao código do produto.

Precedência: **padrões < um arquivo INI/JSON < argumentos CLI**, independentemente
da posição de `-config`. Caminhos do arquivo são relativos à pasta desse arquivo;
caminhos dos argumentos e padrões são relativos ao diretório de trabalho,
normalizados antes da abertura dos listeners. Use caminhos absolutos na
instalação supervisionada. As chaves JSON e opções CLI distinguem maiúsculas;
seções/chaves INI não. Sem `-config`, o executável procura `hbbridge.ini` na
sua pasta. `--config-info` valida metadados sem iniciar listeners. O guia
de [configuração](configuration.pt-BR.md) também descreve `[hbBridge]` no AppServer
para os padrões do cliente TLPP, cujo teste passou manualmente com 13 checks
em 2026-10-04, seguido de relógio/RPC e SQLite paginado.

A tabela acompanha a configuração atual do produto. O resultado homologado
do Marco 1 está registrado separadamente ao final; os ajustes posteriores
de transferência pertencem ao [Marco 2](milestone2-framing.pt-BR.md).

| JSON | Argumento CLI | Padrão |
| --- | --- | --- |
| `protheusHost` / `protheusPort` | `-host` / `-port` | `0.0.0.0` / `1512` |
| `protheusMaxPayloadBytes` | `-maxpayloadbytes` | `0`: sem teto adicional de aplicação para JSON |
| `protheusMaxWireBytes` | `-maxwirebytes` | `0`: sem teto adicional de aplicação para gzip |
| `protheusReadChunkBytes` | `-readchunkbytes` | `65536` bytes por buffer |
| `protheusTimeoutMs` | `-iotimeout` | `30000` ms por recepção/envio; `0` sem deadline Harbour |
| `netioHost` / `netioPort` | `-netiohost` / `-netioport` | `0.0.0.0` / `2941` |
| `adminHost` / `adminPort` | `-adminhost` / `-adminport` | `127.0.0.1` / `2940` |
| `netioRoot` / `addonRoot` | `-netioroot` / `-addonroot` | `data` / `addons` |
| `maxWorkers` | `-maxworkers` | `64` por listener |
| `netioTimeout` | `-netiotimeout` | `0`: convertido em `-1`, sem timeout NETIO/admin nativo |
| `netioPassword` / `adminPassword` | Somente INI/JSON | Vazio |

Endereços de bind são IPv4; clientes usam IP ou DNS do servidor. NETIO/admin
exigem portas de 1 a 65535. O listener Protheus também aceita 0 para testes
com porta atribuída pelo sistema. Configuração inválida e conflitos entre
binds sobrepostos são rejeitados. Se algum listener não inicia, o host encerra
os que já abriu. `--help` lista os parâmetros sem abrir listeners.

O NETIO usa o mecanismo nativo de senha e a configuração padrão de compressão
da biblioteca: com senha, stream znet; sem senha, sem compressão de stream.
Isso não implementa TLS ou autenticação de usuário/tenant. O adaptador
Protheus usa exclusivamente `HBBRIDGE/1` dentro de gzip, com políticas
configuráveis. Payload/wire zero retiram o teto adicional da aplicação;
memória, capacidade de string e tipos das APIs continuam limitando a execução.
`HBBridgeRuntimeLimits()` expõe `stringBytesMax`, `socketChunkBytesMax`,
`zlibChunkBytesMax` e `netioTimeoutMsMax`; o buffer deve caber no menor limite
entre socket e zlib e não é o tamanho máximo de mensagem.
Compressão e descompressão são incrementais
no servidor C/Harbour; o corpo JSON ainda é mantido inteiro em memória.
O cliente TLPP usa strings inteiras e depende do `MAXSTRINGSIZE` efetivo.
Referência: [API oficial hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

## Serviços e contrato interno

`HBBridgeDispatch(hRegistry, cService, xParams, hContext, nVersion)` recebe
e retorna valores Harbour. A versão padrão é 1; serviço/versão desconhecido,
assinatura inadequada e falha de handler retornam um hash com `success: false`,
`error` textual e `code`. O adaptador Protheus converte esse hash para JSON,
preservando os campos usados pelos clientes existentes.

| Serviço versão 1 | Parâmetros | Resultado | Canal |
| --- | --- | --- | --- |
| `Health` | Qualquer valor permitido | `success`, `message` pela ponte C/Zig | Dados |
| `Echo` | Qualquer valor permitido | `success`, `service`, `params` | Dados |
| `ADDON.Execute` | Hash com `module` e `params` | Hash devolvido pelo addon | Dados |
| `Core.Upper` | String | `success`, `result` | Dados |
| `Core.Version` | Qualquer valor permitido | `success`, `result` | Dados |
| `Service.List` | Qualquer valor permitido | Metadados e tipos do perfil | Dados/admin |
| `Admin.Status` | Qualquer valor permitido | Estado e contadores dos endpoints | Admin |

O registro descreve nome, versão, tipo de parâmetro/resultado (`ValType` ou
`any`), permissão, dependências e modalidade `immediate`. O handler é um
codeblock de dois argumentos: valor de entrada e contexto da chamada.
`HBBridgeRegister()` registra extensões antes de selar o catálogo; novos
serviços devem entrar na composição do host e declarar suas dependências.
Descoberta retorna cópias dos metadados permitidos, sem handlers, mutexes,
handles, credenciais ou estado interno. Não há carga dinâmica de contribs
nem resolução automática de dependências neste marco.

Os tipos nativos aceitos são `U`, `C`, `L`, `N`, `D`, `T`, `A` e `H`; hashes
usam chaves string. Strings podem conter bytes binários. Ciclos, objetos,
codeblocks, símbolos e ponteiros vivos são recusados. NETIO preserva datas e
timestamps; a conversão JSON segue o adaptador Protheus.
Codepages e compatibilidade entre revisões diferentes requerem homologação.
Identificadores remotos de cursores/streams pertencem aos próximos marcos.

O contexto é criado pelo servidor com transporte, diretório de addons,
estado do host e permissões do canal. Campos de usuário/empresa recebidos nos
parâmetros não concedem permissões. A separação dados/admin é implementada;
autenticação e autorização por usuário/tenant continuam no roadmap.

## Cliente Harbour

```harbour
LOCAL pConnection, hResult

pConnection := netio_GetConnection( "127.0.0.1", 2941, 5000 )
IF ! Empty( pConnection )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Echo", ;
        { "today" => Date(), "bytes" => Chr( 0 ) + Chr( 255 ) }, 1 )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Core.Upper", "harbour", 1 )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Service.List" )
ENDIF
pConnection := NIL
```

Quando houver senha, passe-a no quarto argumento de `netio_GetConnection`.
Os `5000` ms do exemplo são uma política explícita do cliente, independente
do padrão do servidor.
NETIO já serializa argumentos/resultados; `hb_Serialize`/`hb_Deserialize`
podem ser usados explicitamente para transportar um bloco binário como
string. Nenhum cabeçalho Protheus é acrescentado ao protocolo NETIO.

A biblioteca NETIO nativa admite senha de até 64 bytes e até 8192 arquivos
abertos por conexão. Alguns campos de unidades RPC/stream usam comprimentos
unsigned de 32 bits; não são o tamanho decimal do frame `HBBRIDGE/1` nem o
volume lógico total de arquivos. Ver [notas do transporte NETIO](../src/hb/transports/netio/README.pt-BR.md).

Para VF IO, `netio_Connect()` registra o provedor e define a conexão padrão;
nomes `net:<arquivo>` podem ser usados por `hb_vfOpen`, `hb_vfRead`,
`hb_vfWrite`, `hb_vfSeek` e `hb_vfClose`. Balanceie cada `netio_Connect()`
com `netio_Disconnect()`, e feche os arquivos antes da desconexão. O teste
nativo compara bytes binários escritos/lidos sob `netioRoot`. O acesso DBF
por RDD e a fachada VF IO para TLPP ainda precisam de seus testes e serviços.

## Administração e encerramento

O filtro RPC de dados expõe apenas **`HBBridge.Call`**. O admin expõe esse
gateway com permissões administrativas e **`HBBridge.Admin.Status`**.
Os nomes RPC distinguem maiúsculas; `HB_EXTERN` vincula funções do runtime,
mas não libera invocação arbitrária de símbolos remotos.

O admin usa raiz inválida `*?:*?:`, seguindo o utilitário upstream, para
impedir operações de arquivo nesse canal. Ele oferece consulta de estado;
parada remota, gestão de usuários e instalação como serviço ficam para o
marco operacional. Addons são código executado no processo do host; suas
permissões do sistema são as da conta do hbBridge.

`HBBridgeHostStop()` sinaliza os listeners e aguarda suas threads. O servidor
Protheus drena os workers admitidos; NETIO sinaliza suas conexões, incluindo
clientes ociosos. Handles NETIO são liberados pelo mecanismo de GC Harbour.
Com `protheusTimeoutMs=0`, um cliente Protheus que não conclui nem fecha sua
conexão pode manter a parada esperando indefinidamente. A conclusão das
chamadas admitidas é preservada; não há cancelamento forçado nesta etapa.
Uma função/addon em execução precisa retornar para a thread poder encerrar;
cancelamento cooperativo e prazos de execução pertencem ao contrato futuro.

O host usa `netio_Listen`, `netio_Accept`, `netio_RPCFilter` e `netio_Server`,
guardando as threads para poder aguardar seu encerramento. O wrapper
`netio_MTServer` upstream destaca suas threads, por isso não atende sozinho
esse contrato de parada. A implementação reutiliza a biblioteca nativa e
mantém um único executável.

## Validação e trabalho restante

O runner [test-hbbridge.ps1](../scripts/test-hbbridge.ps1) compartilha a
composição do produto e prepara fixtures isoladas. Além das 74 regressões
originais, executa configuração, registro/contrato, NETIO nativo, VF IO,
administração, falhas de addon e parada/reinício/rollback.
Na homologação histórica do Marco 1 em 2026-10-03, a execução completou
**159 verificações, zero falhas e sem skips**,
incluindo 12 chamadas nativas concorrentes e recusa de credencial admin incorreta.
Build isolado do executável e CLI `--help`/configuração inválida também passaram.
No AppServer, os três fontes TLPP foram compilados sem erros e executou
Health/ADDON/Echo pelo WebApp. Os logs confirmam sucesso e preservação integral
dos 200.000 caracteres do Echo, conforme a [matriz](acceptance.pt-BR.md).

O modelo descrição/handler avaliado em `TRPCFunction` foi aproveitado como
referência de desenho: nomes com namespaces, argumentos por chamada e
metadados independentes do executor. Não foi copiado o protocolo `XHBR` nem
o executor mutável de `trpc.prg`. Lotes/progresso/cancelamento seguem no marco 6.

O [TODO](../TODO.pt-BR.md) distingue implementação de homologação. Serviço do
sistema, hbdebug/HBDAP, SQL, fachada de arquivos TLPP e transferência
negociada permanecem nas frentes próprias. A [matriz de homologação](acceptance.pt-BR.md)
registra o AppServer e o build Harbour/Zig validado.

Este documento registra a entrega e a homologação do Marco 1. No Marco 2,
o produto passa a exigir `HBBRIDGE/1` e `ADDON.Execute`, eliminando os aliases
do protocolo/serviço anterior. Os ajustes atuais retiram tetos arbitrários,
adicionam políticas opcionais e compressão incremental C. Uma rodada posterior
passou em 276 verificações Harbour, incluindo orçamento de resposta
comprimida e limite por chamada zlib. A configuração TLPP e o fluxo normal
foram aceitos em rodada manual posterior de 2026-10-04; cenários de falha e
timeout permanecem pendentes. Consultar o
[contrato atual](milestone2-framing.pt-BR.md).
