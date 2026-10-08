# hbBridge

[English](README.md)

O [pacote ativo](WIP.pt-BR.md) define próximas tarefas, decisões registradas e
critérios de conclusão. O pacote 001 cobre homologação MSSQL real;
[TODO](TODO.pt-BR.md) mantém o roadmap completo. WIP é renovado após encerrar o pacote.

## Alinhamento atual: executor, perfis e compilação

hbBridge é um executor genérico. Protheus resolve regras de negócio, tenantID,
empresa, filial, xFilial, dicionário e nomes físicos de tabelas; envia consultas
e parâmetros já preparados. Addons específicos também recebem seus dados por
parâmetros. Autorização genérica pode validar contexto explícito, sem inferir
regras ERP. Veja [arquitetura](docs/architecture.pt-BR.md).

SQLProfile é opcional e agora tem padrão vazio na biblioteca e no template.
sqlite_demo pertence apenas ao exemplo SQLite. Cada `OpenSQL`/`OpenPage` escolhe
um alias, como mssql/pData; barra e maiúsculas são preservadas sem dedução de
driver, empresa ou filial. O teste sem alias/SQLProfile retorna PROFILE_REQUIRED
antes da rede. Drivers atuais: sqlite e mssql; Oracle exige conector e aceite
próprios. A configuração revisada e as classes renomeadas foram homologadas
pelo operador em 2026-10-07: os 16 checks passaram após recompilação informada
na migração para `.hb`.

O build usa dependências fixadas próprias em .deps/, resolvidas por
scripts/bootstrap.ps1. O runtime compilado fornece hbrun/hbmk2; .hbcommit/
guarda os três validadores, sem runtime bin/harbour. Build não encerra processos;
use OutputDirectory para candidatos. O SDK TOTVS é configurável por argumentos
ou variáveis HBBRIDGE_TOTVS_*, sem instalação fixa. Guias de
[dependências](docs/dependencies.pt-BR.md), [padrões](docs/standards.pt-BR.md) e
[credenciais portáveis](docs/credentials.pt-BR.md) detalham o fluxo. Senha cifrada
no INI com chave externa e CLI local permanece proposta, sem implementação.

Ponte extensível que disponibiliza os recursos de Harbour, C e Zig ao ERP
TOTVS Protheus (AdvPL/TLPP) e a clientes Harbour nativos. O objetivo é ampliar
as capacidades dessas aplicações com RPC, acesso a dados e arquivos, execução
de módulos e processamento nativo, aproveitando o ecossistema Harbour.

Este documento distingue a implementação atual do desenho pretendido. O
[Marco 1](docs/milestone1.pt-BR.md) incorpora NETIO e um núcleo de serviços compartilhado.
Serviço do sistema, negociação, streams e demais extensões seguem no
[TODO.md](TODO.pt-BR.md), com implementação e homologação registradas separadamente.

## Por que Harbour, C e Zig?

A escolha dessas três linguagens é um fundamento do hbBridge: aproximar o
desenvolvimento da experiência de quem programa em Protheus e permitir a
extensão dessa base com código nativo.

### Harbour: a familiaridade do padrão xBase

Harbour e AdvPL/TLPP compartilham a origem e a familiaridade sintática do
padrão xBase. Isso facilita a leitura, a escrita e a manutenção de rotinas
Harbour por quem já desenvolve para Protheus, aproveitando o conhecimento
de funções, comandos, estruturas de controle e acesso a dados desse universo.
A facilidade de programação é a razão central da escolha do Harbour.

Essa proximidade orienta o desenvolvimento dos serviços e addons da ponte.
O runtime, o `hbnetio`, os RDDs nativos e as contribs ampliam as capacidades
disponíveis nessa mesma base. A semelhança sintática facilita a adaptação de
rotinas; APIs específicas do Protheus continuam exigindo adaptação explícita.

### C: interoperabilidade nativa

C é a ligação nativa entre o runtime Harbour e as extensões. A API C do
Harbour permite expor funções ao código xBase, converter parâmetros e
devolver resultados. A ABI C, o contrato binário de chamada entre os
componentes, também permite integrar funções exportadas por Zig.

Essa ligação está em [hbbridgezig.c](src/c/hbbridgezig.c), extraída do loader:
o adaptador C usa `HB_FUNC`, `hb_parc` e `hb_retc` para chamar a função
`HBBridgeZigDispatch` exportada pela [biblioteca Zig](src/zig/runtime/hbbridgeruntime.zig).
O caminho interno é **Harbour ↔ C ↔ Zig**, dentro do servidor.

### Zig: interoperabilidade com C e modernização

Zig foi escolhido pela interoperabilidade com C e pelos recursos modernos
que oferece para desenvolver componentes nativos: tratamento explícito de
erros, tipos opcionais, controle explícito de alocação e liberação de recursos,
e avaliação em tempo de compilação (`comptime`). Esses recursos permitem
evoluir as extensões mantendo a integração com Harbour pela ABI C.
Veja a [visão geral oficial do Zig](https://ziglang.org/learn/overview/).

No projeto, Zig tem dois papéis complementares: o toolchain usado no build
Harbour/C (`hbmk2 -comp=zig`) e a implementação de extensões nativas. O produto
já vincula `hbbridge_zig` e exercita essa integração no serviço `Health`.
Hoje essa função devolve uma resposta demonstrativa; as capacidades da
biblioteca serão ampliadas de forma incremental.

## Direção do projeto

A base é a integração nativa com Harbour, reaproveitando suas bibliotecas e
ferramentas. O código próprio concentra-se no contrato entre clientes e serviços,
na conversão de tipos, na configuração e na operação da ponte. Harbour, C e Zig
participam dessa evolução com os papéis definidos acima.

- Atender clientes Harbour pelo protocolo NETIO nativo e Protheus por um
  adaptador de contrato, compartilhando os mesmos serviços.
- Usar `hbnetio` para RPC e entrada/saída remota, aproveitando seu servidor
  multithread, sua serialização e os recursos de administração.
- Incorporar `hbhttpd` para HTTP/REST e administração web de hbBridge/NETIO,
  reutilizando o núcleo comum de serviços e suas permissões.
- Disponibilizar funções do core vinculadas ao executável com `HB_EXTERN`.
- Reutilizar a execução de `.hrb` e a compilação de `.prg`/`.hb` do Harbour.
- Incorporar a depuração ao ciclo de desenvolvimento: inicialmente com o
  `hbdebug` nativo do Harbour e, futuramente, com integração opcional ao HBDAP.
- Priorizar `RPCRDD.Query` com MSSQL via ODBC e/ou SQLite, reutilizando
  `rddsql`/`SQLMIX` e os conectores existentes do Harbour.
- Integrar o acesso a DBF pelos RDDs nativos do Harbour através do NETIO.
- Usar a Harbour VF IO API (`hb_vf*`) como base de acesso a arquivos locais
  e remotos, com uma fachada de serviços para o Protheus.
- Ampliar posteriormente a homologação para PostgreSQL e MySQL/MariaDB,
  conforme as dependências disponíveis no build.
- Evoluir o contrato do produto para transferência em blocos e compressão
  negociada, respeitando a capacidade de cada cliente.
- Permitir instalação como serviço, com endereços, portas, diretórios,
  concorrência e políticas de recursos configuráveis.
- Evoluir as extensões Zig pela ABI C conforme a base Harbour for consolidada.

O AppServer continua responsável pelo ambiente Protheus. O hbBridge amplia
suas capacidades por uma interface RPC e oferece acesso nativo a aplicações
Harbour, preservando a programação xBase na camada de serviços.

## Estado atual

| Recurso | Situação no código atual |
| --- | --- |
| Servidor TCP | Multithread, bind/porta configuráveis, padrão `0.0.0.0:1512`; cliente local usa `127.0.0.1`. |
| Cliente Protheus | `HBBridgeClient`, contrato único `HBBRIDGE/1` com JSON e gzip em memória nos dois sentidos; uma conexão por chamada. Configuração em `[hbBridge]` do INI AppServer, com argumentos explícitos prioritários; 16 checks revisados homologados pelo operador em 2026-10-07, incluindo perfil explícito/vazio/inválido. |
| Serviços | Registro versionado comum: `Health`, `Echo`, `ADDON.Execute`, `Core.Upper`, `Core.Version`, `Service.List`, `Admin.Status` e `RPCRDD.Query` quando há perfis SQL. |
| Teste Protheus | Health, ADDON.Execute e dois Echo homologados manualmente em 2026-10-03 e repetidos com sucesso em 2026-10-04 e 2026-10-07; 200.000 bytes idênticos e gzip de 152.964 bytes. Teste de relógio Windows também passou. |
| Módulos Harbour | Compilação em memória de `.prg`/`.hb` e carregamento de `.hrb` pelo serviço `ADDON.Execute`, com `module` e `params`. |
| hbnetio | Listener nativo incorporado em `0.0.0.0:2941`, RPC filtrado e serialização Harbour. `HB_EXTERN` habilitado; gateway usa somente serviços registrados. |
| HTTP/REST | `hbhttpd` incorporado, opcional e desativado por padrão. Chamadas JSON e status web autenticado usam o núcleo comum; credenciais de serviço/administração separadas. HTTPS direto exige build com OpenSSL e homologação própria. |
| Cliente HTTP Protheus | `HBBridgeHTTPClient` usa FWRest nativo, bearer e contrato JSON compartilhado. Operador homologou 13 checks em 2026-10-07, incluindo paginação SQL; última rodada: thread 25456, um segundo. Backend SQL HTTP não identificado. |
| Dados SQL | `RPCRDD.Query` usa SQLMIX com SQLite e MSSQL/ODBC; suporta páginas no SGBD e resultados por chave. Teste SQLite Protheus homologado em 2026-10-04 com 29 checks e reconfirmado em 2026-10-07 com `profile=sqlite_demo`; MSSQL real pendente. |
| Dados DBF | Acesso por RDDs nativos via NETIO previsto; ainda não integrado ao hbBridge. |
| VF IO | Cliente Harbour usa `hb_vf*` com provedor NETIO; leitura/escrita binária testadas. Fachada de arquivos para TLPP permanece pendente. |
| C e Zig | Ponte pela API C do Harbour e ABI C do Zig integrada ao `Health`; biblioteca Zig e toolchain exigidos pelo build atual. |
| Limites atuais | Sem teto de payload/rede imposto pelo aplicativo por padrão; políticas opcionais, buffer de leitura e prazo configuráveis. Permanecem os limites reais do runtime, das APIs, do AppServer e da memória disponível. Negociação e blocos pendentes. |
| Operação | Console com host coordenado, arquivos INI/JSON e CLI. `hbbridge.ini` ao lado do executável é carregado sem `-config`; `--config-info` valida sem iniciar o host. Administração em `127.0.0.1:2940`; serviço do sistema pendente. |
| Syslog | Módulo UDP disponível no projeto, ainda sem chamadas no fluxo do servidor. |
| Depuração | `hbdebug` disponível no Harbour; falta preparar e validar o perfil de depuração do hbBridge e dos addons. HBDAP ainda não integrado. |

Com `Health`, `Echo` e a execução de addons homologados antes do Marco 1, o
teste SQLite de `RPCRDD.Query` no AppServer passou em 2026-10-04, incluindo
paginação. A conexão MSSQL real é o próximo aceite SQL. O NETIO já tem
testes nativos; a rodada Protheus do Marco 1 foi confirmada em 2026-10-03:
três fontes compilados sem erros e Health/Echo/ADDON executados com sucesso.
A [matriz de homologação](docs/acceptance.pt-BR.md) registra AppServer `24.3.1.5`,
LIB `20260706`, RPO/dicionário `12.1.2510` e o build Harbour/Zig usado.
A nova confirmação manual recebida em 2026-10-04 passou nos três testes
Protheus: configuração com 13 checks, relógio/RPC e SQLite com 29 checks,
incluindo paginação. A leitura do INI ativo foi aceita pelo teste de
configuração; destino diferente dos padrões ainda precisa de rodada própria.

Em 2026-10-07, após recompilação informada pelo operador na migração para `.hb`,
passaram as classes TLPP renomeadas, os 16 checks de configuração revisados,
relógio/RPC, 29 checks SQLite e 13 checks HTTP. Os horários/threads identificam
essa regressão Windows; não foram fornecidos log de compilação, argumentos,
destino efetivo nem hashes dos artefatos. O backend SQL HTTP não foi identificado.
MSSQL real, destino alternativo e Linux continuam exigindo homologação própria.

O [Marco 2 começou pela correção do fluxo TCP do produto](docs/milestone2-framing.pt-BR.md):
o Harbour descompacta incrementalmente e o TLPP acumula uma unidade gzip completa.
O contrato ativo usa somente `HBBRIDGE/1`, JSON e gzip, com serviços chamados
pelo nome registrado. As regressões exercitam os componentes reais do produto;
a rodada manual Protheus de 2026-10-03 confirmou Health, ADDON.Execute e
os dois Echo com conteúdo integral idêntico. O gzip da requisição de dados
ASCII variados teve **152.964 bytes**, acima do buffer padrão de 65.536 bytes.
Handshake, blocos e compressão negociada continuam no TODO.
O produto não mantém os tetos arbitrários de tamanho das provas de conceito.
A suíte Harbour completa de 2026-10-06 passou em **487 verificações, zero falhas,
sem skips**, incluindo HTTP, concorrência de addons,
INI/JSON, SQLite real, consultas paginadas e resultados iguais por NETIO/TCP, além de Echo
de **24.000.000 bytes exatos** e JSON/gzip acima de 16 MiB nos dois sentidos.

A [análise de evolução](docs/evolution.pt-BR.md) registra as propostas de
2026-10-07: `THREAD STATIC` para estado do worker com inicialização explícita
por requisição, Zig como adaptador HTTP opcional, dependências externas sob
responsabilidade do hb_compile e tabelas SQL genéricas para apresentação
Protheus. A prova thread-static passou em 31 asserções separadas. HTTP Zig,
resolução automática OpenSSL e materialização SQL continuam pendentes.

## Arquitetura pretendida

```text
Protheus / AdvPL / TLPP    Clientes Harbour    Clientes HTTP / navegador
          |                     |                      |
      HBBRIDGE/1            NETIO nativo        HTTP / REST / admin web
          |                     |                      |
 adaptador Protheus       adaptador hbnetio       adaptador hbhttpd
          |                     |                      |
          +----------------- hbBridge ------------------+
                        |
          registro de servicos e capacidades
          tipos / erros / contexto / autorizacao
                        |
       +----------------+------------------+
       |                |                  |
  Harbour/core     dados e arquivos     API C Harbour
  contribs/addons  SQL / DBF / VF IO        |
                                       ABI C <-> Zig

Administracao separada: 127.0.0.1:2940 (quando habilitada)
Hospedagem: console ou servico, com o mesmo nucleo
Build: toolchain Zig para Harbour/C + biblioteca escrita em Zig
```

O host hospeda NETIO, Protheus e HTTP opcional no hbBridge, com um
núcleo comum de serviços. Cada adaptador traduz seu transporte para esse
núcleo; módulos, consultas e extensões não precisam conhecer o protocolo do
cliente. Os listeners compartilham catálogo e configuração; cada chamada
mantém contexto, áreas de trabalho, conexões e módulos com propriedade definida.

### Um executável, módulos internos

A implantação de referência terá **um executável hbBridge**, em console ou
como serviço, incorporando a biblioteca `hbnetio` e chamando suas APIs no mesmo
processo. A vinculação atual é estática, com `-lhbnetio`. O host integra
inicialização, RPC, administração e encerramento usando `netio_Listen`,
`netio_Accept`, `netio_RPCFilter` e `netio_Server`, guardando as threads para
aguardar seu encerramento. O wrapper `netio_MTServer` destaca suas threads.
Referência: [APIs do hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

O ponto de entrada é único e coordena os listeners e os recursos ativos.
O código do utilitário upstream serve de referência para adaptar
configuração e serviço, preservando o uso da biblioteca nativa.

Uma DLL poderá ser adotada para extensões com atualização independente, quando
isso justificar uma ABI e um ciclo de carregamento próprios. Um processo
separado poderá ser útil para isolar alguma carga específica. Essas opções
não são necessárias à integração inicial do NETIO. Drivers ODBC e bibliotecas
de conectores continuam como dependências conforme o build escolhido.

O frame `HBBRIDGE/1` é o contrato do endpoint Protheus. Clientes Harbour usam
o protocolo NETIO nativo em seu próprio endpoint.
O endpoint Protheus deve ter endereço e porta próprios configuráveis. Hoje o
servidor escuta em `0.0.0.0:1512`; `127.0.0.1:1512` é o destino do cliente local. Simplesmente alterar a porta
do cliente TLPP para 2941 não o torna um cliente NETIO. Compartilhamento de
porta só poderá ser adotado após um mecanismo explícito de multiplexação e
testes de interoperabilidade; ele não é necessário ao desenho inicial.

### Rede e execução como serviço

Os padrões implementados acompanham o utilitário servidor hbnetio:

| Canal | Endereço de escuta padrão | Porta | Finalidade |
| --- | --- | --- | --- |
| Dados/RPC NETIO | `0.0.0.0` | `2941` | Clientes Harbour, RPC e arquivos remotos. |
| Administração | `127.0.0.1` | `2940` | Gestão separada do tráfego de aplicações. |
| Adaptador Protheus | `0.0.0.0` | `1512` | Contrato interoperável `HBBRIDGE/1`, JSON e gzip. |
| HTTP/REST + admin web | `127.0.0.1` | `8080` | `hbhttpd` opcional, desativado até ser configurado explicitamente. |

Esses valores correspondem a `_NETIOSRV_IPV4_DEF`, `_NETIOSRV_PORT_DEF`,
`_NETIOMGM_IPV4_DEF` e `_NETIOMGM_PORT_DEF`. `0.0.0.0` é o bind do servidor;
clientes usam seu IP ou DNS real. No utilitário upstream, a administração
depende de senha configurada. A integração deve preservar essa separação e
reaproveitar configuração de interfaces, portas, diretório raiz e acesso.
Essa configuração está em [config/examples/hbbridge.json](config/examples/hbbridge.json)
e [hbbridge.ini](config/examples/hbbridge.ini). INI e JSON compartilham o
mesmo esquema/validação, com precedência de padrões, um arquivo e CLI.
Sem `-config`, o produto procura `hbbridge.ini` ao lado do executável.
Seções, caminhos, perfis SQL e `--config-info` estão em
[Configuração](docs/configuration.pt-BR.md).
Padrões são sobrepostos pelo INI/JSON e depois pela CLI; diretórios do arquivo são
relativos ao arquivo. O [guia do Marco 1](docs/milestone1.pt-BR.md) detalha as opções,
permissões por canal, clientes Harbour e comportamento de encerramento.
Referência: [servidor hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.prg).

As políticas do atendimento são configuráveis no mesmo INI/JSON e pela CLI:

| Configuração | Padrão | CLI | Significado |
| --- | --- | --- | --- |
| `protheusMaxPayloadBytes` | `0` | `-maxpayloadbytes=` | Teto opcional do JSON; `0` não acrescenta um teto do aplicativo. |
| `protheusMaxWireBytes` | `0` | `-maxwirebytes=` | Teto opcional dos bytes comprimidos; `0` não acrescenta um teto do aplicativo. |
| `protheusReadChunkBytes` | `65536` | `-readchunkbytes=` | Buffer operacional de I/O, limitado pelas APIs de socket e zlib; não é o tamanho máximo da mensagem. |
| `protheusTimeoutMs` | `30000` | `-iotimeout=` | Prazo total por fase de leitura/envio; `0` desativa esse prazo no servidor Harbour. |
| `netioTimeout` | `0` | `-netiotimeout=` | `0` usa o padrão nativo `-1`, sem prazo NETIO; valor positivo é um prazo em milissegundos. |
| `maxWorkers` | `64` | `-maxworkers=` | Concorrência operacional por listener. |

No Protheus, as opções do cliente ficam em `[hbBridge]` do INI efetivamente
usado pelo AppServer. O [template](config/examples/protheus-appserver.ini)
define `Host`, `Port`, `TimeoutMs`, `MaxPayloadBytes`, `MaxWireBytes`,
`ReadChunkBytes` e `SQLProfile`. `HBBridgeConfig` lê o arquivo indicado por
`GetSrvIniName()`; `HBBridgeClient():New()` usa os valores da seção, e seus
argumentos explícitos os sobrepõem. Os testes sem argumentos também usam
essas opções. A seção local já foi adicionada e o teste da configuração TLPP
passou com 13 checks em 2026-10-04 e com os 16 revisados em 2026-10-07,
incluindo leitura do INI ativo e seleção de perfil. Os perfis/conexões de banco pertencem ao servidor
hbBridge; `SQLProfile` no AppServer apenas seleciona um alias remoto.

`HBBridgeRuntimeLimits()` informa `stringBytesMax`, `socketChunkBytesMax`
(faixa de `long` na API C do socket), `zlibChunkBytesMax` (faixa de `uInt`
por entrada no codec) e `netioTimeoutMsMax` (faixa de `int`). O buffer aceita
o menor limite entre socket e codec; esses tamanhos por chamada não limitam
o total da mensagem.
Esses limites dependem do build e da arquitetura. Políticas de payload/rede
positivas acrescentam restrições explícitas da instalação; não ampliam a
capacidade dos runtimes nem a memória disponível. A parada do listener
Protheus aguarda as chamadas admitidas; com prazo `0`, um cliente que não
conclua nem feche pode prolongar essa espera indefinidamente.

O hbBridge deverá executar em console e como serviço Windows, reaproveitando
a [integração do hbnetio com o gerenciador de serviços](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/_winsvc.prg).
No Linux, a implantação
deverá oferecer execução supervisionada pelo gerenciador do sistema. Instalação,
início, parada e recuperação usarão o mesmo núcleo, com caminhos absolutos para
configuração, módulos, dados e logs, independentes do diretório de trabalho.
A parada deverá encerrar cursores e streams e tratar chamadas em andamento.
Esses modos ainda não estão implementados no produto.

### HTTP/REST e administração web

O listener opcional `hbhttpd` usa o mesmo registro que NETIO e Protheus.
GET `/api/v1/health` e `/api/v1/services` oferecem saúde/descoberta; POST
`/api/v1/rpc` ou `/api/v1/services/<serviço>` executa serviços registrados
com JSON. Protheus continua enviando suas entradas de negócio já resolvidas.

Configure `[HTTP]` no INI do servidor (ou os campos JSON correspondentes).
Serviços usam credencial bearer de `HTTP.Password`; `/admin/` e
`/admin/status` usam a credencial separada `Admin.Password`, com usuário
`admin`. O painel web atual mostra status do hbBridge e do NETIO; gestão de
configuração, sessões e alterações administrativas permanecem no roadmap.

O build gerenciado resolve `hbhttpd` e `hbtcpio`. `-hblib` é o modo de gerar
bibliotecas do `hbmk2`. `hbssl`/OpenSSL permite o caminho opcional de build TLS
direto; homologação de certificados/TLS/plataformas continua pendente.
Um proxy TLS é outra opção de implantação. Veja
[configuração e contratos HTTP](docs/http.pt-BR.md).

O [exemplo HTTP em TLPP](examples/http/README.pt-BR.md) usa
`HBBridge.Client.HBBridgeHTTPClient`, configurado por `HTTPURL`, `HTTPToken`
e `HTTPTimeoutSeconds` na seção `[hbBridge]` do AppServer ativo.
`U_HBBridgeHTTPTest()` cobre Health/descoberta por GET, Health/Echo/addon por
POST, erros 401/403/404, recuperação e páginas SQL opcionais com o dataset
existente. O relato anterior de 2026-10-07 usou a thread 25672. As rodadas
posteriores passaram nos 13 checks: thread 27296 às 16:10:44–16:10:45 e
thread 25456 às 16:15:03–16:15:04 (São Paulo), cada uma em um segundo.
O backend SQL HTTP não foi identificado; a rodada TCP Query separada
informou explicitamente SQLite.

### Extensibilidade e capacidades para as aplicações

O registro já descreve nome, versão, tipos de entrada/saída, permissões,
dependências e execução imediata. `Service.List` consulta os serviços disponíveis
no canal. Execução em lote/stream e resolução de contribs opcionais serão
ampliadas conforme o roadmap. Novos serviços entram por esse registro sem
exigir uma alteração no transporte.

| Capacidade pretendida | Recurso a aproveitar | Aplicação prática |
| --- | --- | --- |
| Funções e rotinas xBase | Core Harbour, contribs e addons `.prg`/`.hb`/`.hrb`. | Publicar rotinas próximas da linguagem do desenvolvedor Protheus. |
| Consultas e processamento de dados | `rddsql`/`SQLMIX`, conectores, RDDs DBF e NETIO. | Consultar, filtrar e transformar dados no servidor, devolvendo páginas ou resultados agregados. |
| Arquivos e conteúdo | Harbour VF IO API (`hb_vf*`), provedores como NETIO, compressão e arquivos ZIP. | Operar arquivos locais/remotos e transferir conteúdo em blocos. |
| Integrações externas | Contribs existentes, como `hbcurl` e `hbexpat`. | Consumir APIs e processar XML no servidor, expondo operações de domínio ao cliente. |
| Serviços HTTP e operação web | `hbhttpd`, `hbtcpio` e `hbssl`/OpenSSL opcional. | Serviços REST compartilhados e administração autenticada. |
| Processamento nativo | API C Harbour, bibliotecas C e extensões Zig. | Executar transformações e cálculos especializados, medindo seu benefício. |
| Operações demoradas | Threads Harbour e streams NETIO, com uma camada de jobs a implementar. | Submeter trabalho, consultar progresso, consumir resultados e solicitar cancelamento. |

Referências das contribs: [hbcurl](https://github.com/harbour/core/tree/master/contrib/hbcurl),
[hbexpat](https://github.com/harbour/core/tree/master/contrib/hbexpat) e
[hbziparc](https://github.com/harbour/core/tree/master/contrib/hbziparc).
São possibilidades de integração, cuja disponibilidade depende do build e
dos testes de cada serviço. Os primeiros casos continuam sendo os serviços
atuais, `RPCRDD.Query` com MSSQL/SQLite e DBF via NETIO.

As extensões C/Zig deverão usar uma ABI versionada, buffers com tamanho explícito,
regras de propriedade/liberação de memória e retorno de erros. O ponteiro para
string terminada em zero do `Health` atual é apenas a demonstração inicial;
conteúdo binário e execução concorrente exigem um contrato próprio de buffers.
Handles de cursores ou jobs terão escopo de sessão e ciclo de vida definido.

## RPC nativo e HB_EXTERN

O utilitário servidor de `contrib/hbnetio/utils/hbnetio` contém o ponto de
habilitação das funções do core para RPC:

```harbour
/* enable this if you need all core functions in RPC support */
#ifdef HB_EXTERN
REQUEST __HB_EXTERN__
#endif
```

`HB_EXTERN` é a definição de compilação; `__HB_EXTERN__` é o símbolo solicitado,
com dois underscores de cada lado. O projeto upstream `hbnetio.hbp` já inclui
a opção comentada `#-prgflag=-DHB_EXTERN`. Para habilitá-la ao construir esse
utilitário, a partir da raiz dos fontes Harbour e com o toolchain configurado:

```powershell
hbmk2 contrib/hbnetio/utils/hbnetio/hbnetio.hbp -prgflag=-DHB_EXTERN
```

A opção atua no executável que hospeda o RPC. Apenas recompilar `libhbnetio`
ou acrescentar `-lhbnetio` ao projeto não ativa esse trecho. Na execução do utilitário,
o RPC também precisa ser habilitado com `-rpc` ou `-rpc=<módulo>`.

No hbBridge, `hbbridge.hbm` já habilita `-prgflag=-DHB_EXTERN` e o núcleo
solicita `__HB_EXTERN__`. O filtro NETIO permite apenas o gateway registrado;
`Core.Upper` e `Core.Version` demonstram funções do runtime pelos dois
adaptadores. Contribs e drivers adicionais precisam ser vinculados
explicitamente; `HB_EXTERN` não instala suas dependências.

Referências: [fonte do servidor hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.prg),
[projeto hbnetio.hbp](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.hbp)
e [vinculação das funções do core](https://github.com/harbour/core/blob/master/src/hbextern/hbextern.prg).

### Clientes Harbour e serialização nativa

Clientes Harbour conectam-se diretamente ao NETIO, usando operações
como `netio_Connect`, `netio_FuncExec` e `netio_Disconnect`. O RPC nativo já
serializa argumentos e resultados; o adaptador hbBridge deve receber valores
Harbour. Essa integração está implementada e tem testes de valores nativos.
Veja a
[implementação do cliente NETIO](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).

Para operações que precisam produzir ou consumir um bloco serializado, a
troca Harbour ↔ Harbour poderá usar `hb_Serialize()`/`hb_Deserialize()`.
`HB_SERIALIZE_COMPRESS` é uma opção dessa serialização; a compressão do
transporte NETIO é outra camada. A política deverá evitar compressão redundante.
Fontes: [serialização Harbour](https://github.com/harbour/core/blob/master/src/rtl/itemseri.c)
e [opções de serialização](https://github.com/harbour/core/blob/master/include/hbserial.ch).

O perfil nativo poderá preservar tipos Harbour homologados entre as versões
usadas. Classes, símbolos e referências especiais exigem regras próprias;
ponteiros e recursos vivos do processo não se tornam recursos remotos pela
serialização. Cursores e jobs serão representados por identificadores de
serviço com abertura, uso e fechamento definidos.

O NETIO tem limites próprios: senha de até 64 bytes, 8.192 arquivos abertos
por conexão e campos `uint32` de comprimento em determinadas unidades de RPC
e streams. Esses campos não são o comprimento decimal do frame Protheus.
O limite de uma unidade nativa não define o volume total de um arquivo ou de
uma operação. A [documentação do transporte incorporado](src/hb/transports/netio/README.pt-BR.md)
registra as fontes e a distinção entre capacidades técnicas e políticas do host.

Os streams de dados e itens do NETIO também serão avaliados para resultados
incrementais e progresso. O uso dessas APIs deverá respeitar seus buffers e
o ritmo de consumo do cliente; habilitar um stream não garante memória limitada
por si só. Essa adaptação ainda faz parte do trabalho da ponte.

### Reaproveitamento de contrib/xhb/trpc.prg

A análise do TRPC identificou referências úteis para descrição e registro de
funções, associação a executores, progresso e cancelamento. O reaproveitamento
será seletivo, adaptando esses elementos ao núcleo e aos jobs do hbBridge.
Seu protocolo `XHBR` é distinto do NETIO e do contrato Protheus; ele não será
um terceiro transporte obrigatório.

A [avaliação técnica](docs/harbour-vfio-trpc.pt-BR.md) registra os trechos examinados,
as restrições encontradas e os critérios para extrair código. A análise foi
estática; nenhuma classe TRPC foi incorporada ao servidor nesta etapa.

## Módulos e acesso a dados

O utilitário hbnetio oferece `-rpc=<arquivo>` para carregar um módulo `.hrb`
ou compilar um fonte `.prg`/`.hb` com os recursos do Harbour. Esse modo utiliza
a função `HBNETIOSRV_RPCMAIN` do módulo como ponto de despacho. A integração
deve reaproveitar esse mecanismo e estabelecer o contrato de chamadas.
Veja o [exemplo oficial](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/rpcdemo.hb).

O serviço registrado `ADDON.Execute` recebe `params` com `module` e os
parâmetros do módulo em `params`. O loader em
[hbbridgeaddon.hb](src/hb/addons/hbbridgeaddon.hb), pela função `ExecuteAddonHRB`,
compila fontes `.prg` e `.hb` em memória com
`hb_compileBuf`; para `.hrb`, carrega o módulo compilado. A execução usa
`hb_hrbLoad`/`hb_hrbDo`/`hb_hrbUnload`, com símbolos locais a cada HRB ativo.
O Harbour pode preservar valores `STATIC` ao reciclar um módulo descarregado;
addons devem inicializar o estado de cada chamada a partir dos parâmetros.

O teste Protheus chama `ADDON.Execute` com
`{"module":"examples/hbbridgesampleaddon.hb","params":{...}}`, resolvido sob
`addonRoot`, e verifica o retorno `success` do módulo de exemplo. O mesmo
serviço está disponível pelo NETIO nativo. As regras de publicação, versão e
atualização dos módulos continuam no roadmap.

### SQL: RPCRDD.Query com páginas no SGBD

Para SQL, `rddsql` é a contrib que fornece os RDDs `SQLBASE` e `SQLMIX`
(a camada referida no escopo como RDDSQL/RDDSQLMIX). MSSQL e SQLite são os
alvos iniciais para os testes de integração com Protheus neste projeto.
Os componentes a integrar são:

| Banco/interface | Componentes Harbour existentes |
| --- | --- |
| MSSQL via ODBC — prioridade inicial | `sddodbc` com `rddsql`/`SQLMIX`; `hbodbc` para API direta e driver ODBC do ambiente. |
| SQLite — prioridade inicial | `sddsqlt3` com `rddsql`/`SQLMIX`; `hbsqlit3` para API direta quando necessária. |
| PostgreSQL — expansão posterior | `sddpg` com `rddsql`/`SQLMIX`; `hbpgsql` para API direta quando necessária. |
| MySQL/MariaDB — expansão posterior | `sddmy` com `rddsql`/`SQLMIX`; validar biblioteca cliente e versão do servidor. |

Fontes: [rddsql](https://github.com/harbour/core/tree/master/contrib/rddsql),
[sddpg](https://github.com/harbour/core/tree/master/contrib/sddpg),
[sddmy](https://github.com/harbour/core/tree/master/contrib/sddmy),
[sddsqlt3](https://github.com/harbour/core/tree/master/contrib/sddsqlt3) e
[sddodbc](https://github.com/harbour/core/tree/master/contrib/sddodbc).

O serviço implementado usa `SQLMIX`, `sddsqlt3` e `sddodbc`, com perfis lógicos
em `sqlProfiles` no JSON do servidor. Envia-se `alias` e `sql`; caminhos e
credenciais permanecem no host. Os [exemplos SQLite](config/examples/sqlite.json)
e [MSSQL](config/examples/mssql.json) estão disponíveis. SQLite foi escolhido
para a primeira regressão real; o caminho MSSQL/ODBC requer homologação com
o DSN e o banco do ambiente. O serviço é anunciado somente com perfis configurados.

O resultado usa hashes para `header` e `rows`, com `rowCount`, `driver` e
`resultVersion`. O cliente [HBBridgeRPCDataSet](src/tlpp/hbbridgerpcdataset.tlpp) usa
`JSONObject`, leitura por nome, navegação, fechamento e erros identificados.
O novo [teste Protheus](src/tlpp/tests/protheus/hbbridgequerytest.tlpp),
`U_HBBridgeQueryTest`, passou no AppServer em 2026-10-04 às 00:40:06,
perfil `sqlite_demo`: os 29 checks foram verdadeiros, incluindo campos,
decimal, vazio, erros, recuperação, páginas, EOF e fechamento.

O [launcher SQL](examples/sql/run.ps1) prepara esse teste com o mesmo produto:
`pwsh .\examples\sql\run.ps1` carrega `sqlite_demo` por padrão e informa a
chamada/WebApp. Aceita `-Config` INI/JSON, `-Profile`, `-Port` e `-MaxWorkers`; os detalhes
para SQLite e MSSQL estão no [exemplo SQL](examples/sql/README.pt-BR.md).

O parâmetro opcional `page = {number, size, orderBy}` aplica `ROW_NUMBER()` e
`BETWEEN` no SGBD, conforme o padrão do exemplo REST analisado. O banco devolve
até `size + 1` linhas: a extra informa `hasNext`, e a resposta contém até
`size`. `OpenPage`, `NextPage`, `HasNextPage`, `PageNumber` e `PageSize`
expõem essa navegação no TLPP. A ordenação deve incluir desempate único;
cada página executa nova consulta e não representa um snapshot.

Não há teto arbitrário de linhas. Os ordinais precisam ser inteiros exatos
representáveis pelo contrato JSON/TLPP. A paginação limita as linhas recebidas
e materializadas pela ponte; páginas profundas ainda podem custar ordenação
e varredura no banco. O [contrato do Marco 3](docs/milestone3-sql.pt-BR.md) detalha
gramática de ordenação, tipos, nulos, erros e o ciclo de conexão/área.
Parâmetros vinculados, cursores, transações, cancelamento, timeout SQL e
transferência incremental de BLOBs continuam no TODO.

### DBF nativo do Harbour via NETIO

O projeto também prevê aproveitar os RDDs nativos do Harbour para acessar
arquivos DBF através do NETIO. O `hbnetio` oferece a camada de entrada/saída
remota: no cliente Harbour, arquivos com prefixo `net:` são redirecionados
ao servidor NETIO, preservando o uso dos RDDs. Veja a
[documentação oficial do hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

Esse caminho permite trabalhar com DBF e seus arquivos associados usando
os recursos xBase do Harbour. A exposição dessas operações ao Protheus será
mediada pela ponte; o cliente TLPP atual ainda não implementa o protocolo
NETIO. A integração deverá validar abertura, leitura, navegação, índices,
bloqueios e fechamento. O acesso nativo a DBF é uma frente própria de dados;
`RPCRDD.Query` é a fachada implementada para as consultas SQL.

### Arquivos com Harbour VF IO API: hb_vf*

O suporte a arquivos deverá usar `hb_vfOpen`, `hb_vfRead`/`hb_vfWrite`,
`hb_vfReadAt`/`hb_vfWriteAt`, `hb_vfSeek`, `hb_vfSize` e `hb_vfClose`, além
das operações de diretório, metadados e bloqueios suportadas por cada provedor.
Clientes Harbour poderão usar a API diretamente sobre arquivos locais e
caminhos `net:` com o NETIO registrado.

Para Protheus, a família proposta `Files.*` traduzirá essas operações para
identificadores remotos por sessão, com transferência em blocos, contagem de
bytes, EOF, erros e fechamento definidos. Ponteiros VF e descritores do sistema
operacional permanecem no processo que os criou. C e Zig participarão por
buffers ou pela interface `hb_file*` através da ponte C.

Cada backend terá capacidades homologadas. A transferência incremental usará
leitura/escrita por blocos; `hb_vfLoad`/`hb_vfSave` serão reservadas a operações
cujo conteúdo caiba no orçamento de memória. O detalhamento das APIs e da
integração está em [Harbour VF IO e TRPC](docs/harbour-vfio-trpc.pt-BR.md).

## Contrato e compressão atuais

Uma requisição JSON contém `service` e `params`:

```json
{
  "service": "Echo",
  "params": { "message": "Protheus conectado ao Harbour" }
}
```

Antes da compressão, o frame tem o formato:

```text
HBBRIDGE/1|JSON|<tamanho-em-bytes-do-JSON>\n<payload-json>
```

`HBBRIDGE/1` identifica o produto e a versão atual do frame. Cliente e servidor
usam esse contrato único, com JSON enquadrado e gzip nos dois sentidos.
Assinatura, codec e comprimento são validados antes do despacho.
Essa identificação ainda não implementa a negociação prevista para o produto.
As constantes compartilhadas ficam em [includes/hbbridge.h](includes/hbbridge.h).

O frame inteiro é comprimido para envio. O tamanho declarado é o do JSON
descomprimido, sem o cabeçalho, e não o tamanho transmitido no socket.
O comprimento usa decimal canônico e é comparado com o tamanho efetivo do
corpo; o parser não impõe oito dígitos nem cabeçalho de 128 bytes. A estrutura
do cabeçalho e a quantidade de dígitos representável pelo runtime permitem
validá-lo antes de acumular o corpo.

| Sentido | Compressão | Descompressão |
| --- | --- | --- |
| Protheus → Harbour | `GzStrComp`, no cliente TLPP | zlib incremental pela API C, no servidor |
| Harbour → Protheus | Compressor gzip incremental pela API C, no servidor | `GzStrDecomp`, no cliente TLPP |

Esse caminho usa buffers em memória. Não depende de arquivos
temporários nem das APIs de arquivo `GzCompress`/`GzDecomp`. O cliente atual
envia JSON dentro do frame comprimido, e o servidor também comprime a resposta.
Os detalhes estão em [hbbridgeclient.tlpp](src/tlpp/hbbridgeclient.tlpp) e
[hbbridgeframing.hb](src/hb/transports/protheus/hbbridgeframing.hb).

O contrato não fixa um teto de 16 MiB. Por padrão, o aplicativo não acrescenta
limites de payload ou bytes transmitidos. O servidor respeita as capacidades
do runtime e as políticas opcionais configuradas, valida o trailer/CRC e
exige corpo com o comprimento exato. O decoder e o
[compressor C](src/c/hbbridgecompressor.c) reutilizam a zlib vinculada pelo
Harbour para processar o formato gzip definido pelo contrato, preservando
estado entre buffers de entrada/saída.
As versões anteriores permanecem no histórico Git; o código ativo e os
testes seguem a implementação do produto.

Cada chamada mantém uma unidade comprimida por sentido e uma conexão. O
Harbour preserva o estado de descompressão entre leituras; o TLPP acumula os
bytes até o fechamento normal e executa `GzStrDecomp` uma vez. Os dois lados
repetem envios positivos incompletos. A rodada manual Protheus confirmou a
conclusão normal das chamadas e o Echo pouco compressível. Os cenários de
timeout/falha e o envio parcial positivo forçado ainda exigem homologação TLPP.

O construtor TLPP aceita `New(cHost, nPort, nTimeout, nMaxPayloadBytes,
nMaxWireBytes, nReadChunkBytes)`. Os três primeiros argumentos permanecem
opcionais; o prazo padrão é 30 segundos e deve ser positivo no cliente,
pois o comportamento de espera infinita das APIs TOTVS ainda exige validação.
Os tetos opcionais usam `0` por padrão e a leitura usa buffer de 64 KiB.
O cálculo do prazo TLPP usa `TimeCounter()` por meio dos métodos estáticos da
classe `HBBridge.Client.HBBridgeTime`, em [hbbridgetime.tlpp](src/tlpp/hbbridgetime.tlpp),
adaptados de `dna.tech.StopWatch.__GetCurrentTimeStamp()`,
sem depender de `Date()`/`Seconds()` nem impor um teto artificial de um dia.
O adapter normaliza para milissegundos a diferença reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12):
Windows retorna milissegundos e Linux retorna segundos fracionários.
Por isso, aplica Unix × 1000. Regressões do contador expiram o orçamento.
O teste Protheus verifica escala e avanço durante `Sleep(1000)` antes do RPC,
inclusive para detectar eventual correção dessa diferença em novos builds.
O operador confirmou esse teste no Windows em 2026-10-04: delta bruto de
`1097.692700` e normalizado de `1097.773500` ms, resultado `OK`.
Em 2026-10-07 às 16:14:31, thread 27084, reconfirmou `OK`: delta bruto
`1089.987500`, normalizado `1090.088100 ms`.
A documentação não garante monotonicidade/wrap de `TimeCounter`; essa
validação ampliada e o caminho Linux permanecem pendentes. O servidor usa `HBBridgeMonotonicMs()` para
os prazos e o uptime, sem depender de ajustes de data/hora.

`GzStrComp`/`GzStrDecomp` operam sobre strings completas, sujeitas ao
`MAXSTRINGSIZE` efetivo do AppServer e à memória disponível. `GzStrDecomp`
não expõe controle da expansão durante a alocação; uma checagem posterior
não substitui esse controle. `TSocketClient:Send` também não oferece timeout
como argumento. As limitações e os testes estão em
[Marco 2 — fluxo TCP](docs/milestone2-framing.pt-BR.md). O corpo JSON ainda é materializado
inteiro nos dois lados. Compressão incremental no servidor não significa
transferência lógica em blocos; páginas, streams e `none`/`gzip` negociados
continuam pendentes.

## Evolução do contrato e da transferência

O contrato de serviços será compartilhado, com duas representações: valores
nativos no caminho Harbour/NETIO e uma representação interoperável no adaptador
Protheus, inicialmente JSON. A versão do protocolo de transporte e a versão
de cada serviço serão identificadas separadamente.

### Negociação e tipos

A evolução da conexão Protheus começará com uma troca pequena de capacidades,
de enquadramento conhecido e sem compressão, para escolher versão, codec,
compressão, tamanho por bloco e modos de transferência. Clientes Harbour farão
a descoberta de serviços pela conexão NETIO já estabelecida, preservando seu
handshake nativo. O cliente deverá declarar limites que consegue cumprir;
quando não puder obter sua configuração efetiva, usará um perfil explícito
homologado para aquele ambiente. A evolução será especificada e testada no
contrato do produto, com tratamento explícito de versões incompatíveis.

| Parte do contrato proposto | Definição necessária |
| --- | --- |
| Chamada | Identificador, serviço e versão, parâmetros, contexto e prazo de execução. |
| Resposta | Correlação com a chamada, sucesso, resultado e metadados; erro com código, origem e indicação de possibilidade de nova tentativa. |
| Tipos | Nulo, vazio, lógicos, inteiros, decimais/moeda, datas, timestamps, strings, binários, arrays e hashes; conversão explícita entre runtimes. |
| Texto e números | Encoding definido, contagem de bytes e preservação de precisão; fuso horário e representação de datas documentados. |
| Recursos remotos | Sessão, identificadores de cursor/stream/job, expiração, fechamento e cancelamento cooperativo. |
| Versões e resultados | Tipos e retornos de `Health`, `Echo`, `ADDON.Execute` e `HBBridgeRPCDataSet` definidos por versão; versão incompatível gera erro identificável. |

O enquadramento externo do adaptador deverá evoluir para identificar versão, chamada,
codec, compressão e comprimento em bytes transmitidos e expandidos de cada
bloco. A especificação binária/textual exata será validada com ambos os clientes
antes da implementação. Com isso, o receptor reúne uma unidade completa antes
de descomprimir, sem depender de quantos bytes cada `Receive` devolveu.

Novas tentativas após desconexão respeitarão a semântica do serviço: o mesmo
identificador de chamada não garante, sozinho, execução única. Operações que
alteram dados precisarão de idempotência ou consulta do resultado anterior.

### Conexões persistentes e contexto de execução

O brainstorming foi avaliado em [Transportes, sessões e segurança](docs/transports-sessions-security.pt-BR.md).
As decisões abaixo são evolução planejada: o cliente atual abre um socket por
chamada e o worker encerra a conexão após uma requisição.

A sequência será corrigir o enquadramento TCP, reutilizar uma conexão para
chamadas sequenciais e depois oferecer um pool limitado. Compartilhar um socket
entre chamadas simultâneas exige uma etapa adicional de multiplexação: correlação,
leitor único, despacho de respostas, escritas coordenadas e controle de fluxo.
Persistência reduz handshakes e pressão sobre portas efêmeras; não elimina todos
os limites de concorrência. Conexões ociosas também consomem recursos do servidor.

Harbour já oferece `hb_socketSetKeepAlive` e `hb_socketSetNoDelay`. Keepalive
depende dos temporizadores do sistema; prazos de chamada e eventual heartbeat
tratam a vivacidade da aplicação. `TCP_NODELAY` será configurável e medido.
Reconexão usará espera progressiva com variação aleatória, sem repetir operações
com efeitos cujo resultado ficou desconhecido.

Cada chamada terá identidade verificada, contexto opaco explícito autorizado,
correlação e prazo. Protheus resolve empresa/filial e regras ERP antes da
chamada. Áreas de trabalho, transações e buffers serão liberados mesmo
em falhas. O princípio é **isolamento por chamada e estado explícito por sessão**.
Cursores SQL, transações e handles VF IO têm proprietário, expiração e fechamento;
um identificador opaco não os torna duráveis ou transferíveis entre processos.
Retomada autenticada e balanceamento com recursos vivos exigem capacidade própria
e encaminhamento ao proprietário. Jobs só sobrevivem a reinício quando persistidos.

### TLS, JWT e adaptadores opcionais

| Proposta | Decisão para o hbBridge |
| --- | --- |
| TLS no cliente Protheus | Priorizar prova de interoperabilidade `TSSLClient` ↔ `hbssl`/OpenSSL, com validação de certificado e nome do servidor. |
| JWT | Usar como opção de autenticação/autorização sobre transporte protegido; validar assinatura, emissor, audiência, validade e escopo. |
| `tSktSslSrv` / `tSktSslConn` | Reservar para um caso futuro que exija o Protheus recebendo conexões; o fluxo atual pede um cliente TLS. |
| gRPC por `tGrpc` | Investigar: a API TOTVS documenta o modelo Smartlink predefinido, sem comprovar suporte a um `.proto` arbitrário. |
| AMQP por `tAMQP` | Adaptador opcional para jobs/eventos via RabbitMQ AMQP 0.9.1, com idempotência e recuperação de falhas. |
| Transporte nativo em Zig | Evoluir em `src/zig/` pela ABI C, reutilizando bibliotecas e medindo ganhos antes de substituir componentes. |

Referências: [TSSLClient](https://tdn.totvs.com/display/tec/Classe+TSSLClient),
[tJWT](https://tdn.totvs.com/display/tec/tJWT),
[tGrpc](https://tdn.totvs.com/display/tec/tGrpc) e
[tAMQP](https://tdn.totvs.com/display/tec/tAMQP).
JWT assinado não cifra o payload nem protege, sozinho, o restante da comunicação;
o contrato deve combinar identidade verificada com TLS e autorização por serviço.
Veja a [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html).

Os adaptadores compartilharão catálogo, contexto e erros do núcleo. RabbitMQ será
uma dependência externa somente de implantações que habilitem AMQP. A referência
continua sendo um executável hbBridge com NETIO incorporado; gRPC, AMQP e callbacks
não bloqueiam `RPCRDD.Query`, VF IO nem a evolução do contrato Protheus.
Zig mantém seus papéis fundamentais no toolchain e nas extensões; sua escolha
para um novo transporte dependerá da biblioteca, compatibilidade e medições.

### Volume total, memória e limites do cliente

O produto não impõe um teto fixo de 16 MiB. As políticas opcionais do host
convivem com os limites reais de memória, arquitetura, representações e APIs.
A evolução deverá permitir volumes lógicos maiores que uma mensagem ou
string, usando páginas, blocos e streams. Cada transporte e conector também
precisa ter seus limites técnicos validados; ausência de teto do aplicativo
não significa capacidade infinita.

No Protheus, `MAXSTRINGSIZE` depende do build e da configuração do AppServer.
O tamanho útil de cada bloco deve considerar o conteúdo descomprimido, JSON,
eventual base64, buffers temporários e cópias. A referência para homologação é
a [documentação TOTVS de MaxStringSize](https://tdn.totvs.com/pages/viewpage.action?pageId=161349793).

O controle será feito em três níveis: limites técnicos do peer, orçamento
operacional configurável por conexão/processo e volume lógico da operação.
Cada bloco transmitido deverá caber nos limites negociados, inclusive após expansão.
Haverá controle do número de blocos em trânsito e do ritmo de produção conforme
o consumidor, além de tempo máximo e fechamento de recursos.

Uma consulta poderá devolver páginas sem carregar todas as linhas no TLPP.
Um arquivo ou campo maior que uma string será consumido em blocos, gravado em
arquivo ou acessado por um identificador remoto. Dividir a transferência e
depois concatenar tudo em uma string continuaria sujeito a `MAXSTRINGSIZE`.
Serviços que exigem um único valor em memória deverão declarar esse requisito
e retornar um erro claro quando o cliente não puder recebê-lo.

### Compressão conforme o caso

A proposta para o adaptador Protheus é suportar `none` e `gzip`, com seleção
negociada e política automática opcional baseada em tamanho, ganho obtido e
custo de CPU/latência. Mensagens pequenas e conteúdo já comprimido podem ser
enviados sem compressão; o codec escolhido será declarado em cada bloco.
Os limiares serão definidos por medição, sem tornar compressão obrigatória.

Como `GzStrComp`/`GzStrDecomp` trabalham com strings completas, cada bloco gzip
deverá ser uma unidade independente e caber no limite efetivo do Protheus.
O tratamento deverá conferir os retornos dessas funções e lidar com conteúdo
vazio. A homologação incluirá amostras binárias nos dois sentidos, identificando
explicitamente o formato gzip usado no fio e sua distinção de zlib/DEFLATE.
Fontes: [GzStrComp](https://tdn.totvs.com/display/tec/GzStrComp) e
[GzStrDecomp](https://tdn.totvs.com/display/tec/GzStrDecomp).

Declarar o tamanho expandido permite rejeitar blocos inadequados, mas não
garante que o descompressor respeite esse limite. A homologação deverá verificar
expansão real e memória usada durante a descompressão; quando a API não permitir
expansão limitada, o perfil deverá usar blocos confiáveis ou o modo `none`,
conforme a política de conexão.

No caminho Harbour/NETIO, será usada a configuração nativa de compressão da
conexão, sem inserir cabeçalhos do adaptador Protheus no protocolo NETIO.
Compressão do stream e `HB_SERIALIZE_COMPRESS` serão avaliadas separadamente
para evitar trabalho duplicado. A matriz de testes comparará tráfego local e
remoto, JSON, dados binários e conteúdo com diferentes taxas de compressão.

## Produto e organização dos fontes

A organização prevista foi aplicada antes da evolução funcional. Os componentes
reutilizáveis ficam em `src/`, com uma implementação do servidor e um ponto de
entrada. [examples/mvp](examples/mvp/README.pt-BR.md) contém apenas um launcher de
exemplo para o mesmo executável, clientes e addon compartilhados. O nome da
pasta é uma referência à origem do exemplo; a implementação e os testes são
os do produto. O histórico Git preserva as provas de conceito anteriores.

### Estrutura atual

```text
hb.bridge/
|-- .hbcommit/                          # Validadores Harbour de commit
|-- src/
|   |-- hb/
|   |   |-- host/                        # Entrada, configuracao e ciclo de vida
|   |   |-- core/hbbridgedispatcher.hb           # Registro versionado e valores Harbour
|   |   |-- transports/
|   |   |   |-- netio/hbbridgenetio.hb         # RPC e arquivos nativos; threads do host
|   |   |   |-- http/hbbridgehttp.hb          # HTTP/REST e status web com hbhttpd
|   |   |   `-- protheus/
|   |   |       |-- hbbridgeserver.hb       # Listener e workers do produto
|   |   |       |-- hbbridgeadapter.hb          # JSON para o nucleo de servicos
|   |   |       `-- hbbridgeframing.hb          # Recepcao/envio HBBRIDGE/1 com gzip
|   |   |-- services/hbbridgeservices.hb         # Servicos, descoberta e administracao
|   |   |-- addons/hbbridgeaddon.hb      # Compilacao e carga de modulos
|   |   `-- telemetry/hbbridgesyslog.hb         # Modulo Syslog existente
|   |-- c/                              # API Harbour, gzip incremental e ABI C para Zig
|   |-- zig/runtime/hbbridgeruntime.zig          # Biblioteca Zig demonstrativa
|   `-- tlpp/                           # Clientes TCP/HTTP, HBBridgeRPCDataSet e tests/protheus
|-- addons/examples/                    # Addon compartilhado
|-- examples/
|   |-- mvp/                            # Launcher mínimo do mesmo produto
|   |-- http/                           # Consumo HTTP em TLPP e instruções de homologação
|   `-- sql/                            # Perfil e instruções de teste SQL
|-- includes/hbbridge.h                 # Constantes compartilhadas do contrato
|-- config/dependencies.json            # Dependencias e revisoes fixadas
|-- config/patches/                      # Patches gerenciados sobre fontes fixados
|-- config/examples/                    # INI/JSON do servidor e secao cliente AppServer
|-- tests/
|   |-- unit/                           # Validacao de configuracao
|   |-- contract/                       # Tipos, erros e registro de servicos
|   `-- integration/harbour/            # MT/NETIO/TCP/HTTP/SQL e fixtures HRB
|-- docs/                               # Arquitetura, analises e validacao
|-- scripts/                            # Build, launcher comum e runner de testes
|-- hbbridge.hbp                        # Executavel: entrada + componentes
|-- hbbridge.hbm                        # Fontes/flags compartilhados com testes
`-- build.zig                           # Build da biblioteca Zig
```

A estrutura pretendida agora está materializada. O [registro da reorganização](docs/reorganization.pt-BR.md)
detalha os caminhos anteriores, a revisão de referência e a comparação dos testes.
`hbbridge.hbp` compõe o host com `hbbridge.hbm`; o projeto de testes reutiliza
esse mesmo conjunto de componentes, com sua própria entrada de teste. O launcher
do exemplo posiciona o diretório de trabalho para o loader localizar `addons/`.

O adaptador separa a representação JSON do núcleo nativo. Registro, contexto,
NETIO e testes dedicados já estão implementados. O Marco 2 corrige a recepção
TCP e consolida o contrato `HBBRIDGE/1` nos componentes do produto.
Os fontes de teste Protheus ficam em `src/tlpp/tests/protheus`, permitindo
compilar toda a árvore TLPP de uma vez. Identificadores de código seguem a
preferência por inglês; o loader usa `ExecuteAddonHRB`.

## Depuração: hbdebug primeiro, HBDAP como evolução

A depuração fará parte do desenvolvimento dos serviços e addons do produto,
usando a mesma implementação do produto. A primeira etapa será aproveitar o
**`hbdebug`, depurador nativo do Harbour**, com breakpoints, execução passo a
passo e inspeção de pilha e variáveis em uma execução de desenvolvimento em
console. Referência: [depurador Harbour](https://github.com/harbour/core/tree/master/src/debug).

O perfil deverá compilar os fontes Harbour com informações de depuração (`-b`),
vincular o depurador e manter os fontes correspondentes acessíveis. Isso inclui
os `.prg`/`.hb` compilados em memória pelo loader e os `.hrb` preparados fora
do servidor. Hoje a composição [hbbridge.hbm](hbbridge.hbm) e a chamada a `hb_compileBuf` no
[loader](src/hb/addons/hbbridgeaddon.hb) não habilitam `-b`; ter `hbdebug` no
toolchain não significa que esse fluxo já esteja integrado e homologado.
No `hbmk2`, `-debug` controla informações para o depurador nativo C; a opção
Harbour `-b` tem outra função. Veja o [hbmk2](https://github.com/harbour/core/blob/master/utils/hbmk2/hbmk2.prg).

A validação inicial usará uma chamada e um worker controlados, com pausa em um
handler e em um addon, inspeção e retomada até a resposta ao cliente. Precisam
ser definidos o uso do terminal/GT, os efeitos da pausa nos timeouts RPC e a
limpeza de recursos. A operação como serviço continuará sem interação obrigatória;
o perfil de depuração será ativado explicitamente em ambiente de desenvolvimento.

### Integração futura com HBDAP

O **HBDAP** é o projeto privado em desenvolvimento, disponível neste ambiente em
`F:\GitHub\hbdap`, que adapta o motor de depuração Harbour ao **Debug Adapter
Protocol (DAP)**. A intenção é oferecer depuração por clientes DAP, como IDEs e
CLI, preservando o depurador tradicional como caminho inicial. O caminho local
é uma referência de desenvolvimento, não uma dependência fixa da instalação.

No VS Code, a interface prevista será a extensão **Harbour DAP**, desenvolvida
no projeto `hbdap-vscode-extension`, disponível localmente em
`F:\GitHub\hbdap-vscode-extension`. Ela registra o tipo de depuração
`harbour-dap` usado no `launch.json` e conecta o editor ao runtime habilitado
para DAP, diretamente ou por um adaptador, conforme o modo escolhido.
O fluxo pretendido no hbBridge é **VS Code → extensão Harbour DAP → HBDAP →
motor hbdebug no hbBridge**. O HBDAP também poderá ser usado por outros clientes
DAP, como o CLI; a extensão é a integração específica com o editor.

O pacote VSIX da extensão contém a integração com o VS Code. O runtime Harbour,
a biblioteca HBDAP e as ferramentas de adaptação exigidas pelo modo escolhido
são preparados separadamente. O roteiro do hbBridge deverá fixar versões
compatíveis, configurar executável/fontes e homologar launch/attach com um
handler e um addon reais. Esse fluxo completo ainda é uma integração futura
no hbBridge, mesmo existindo testes próprios nos projetos HBDAP e da extensão.

A documentação local do HBDAP descreve uma base experimental com bridge para
`hbdebug` e transportes DAP. Sua integração atual depende de hooks/patches no
runtime Harbour e de recompilação; a combinação de revisões e toolchain deverá
ser fixada e validada antes de incorporá-la ao hbBridge. A depuração multithread
e o ciclo de carga/descarga dos addons HRB exigem homologação específica no
servidor: suporte DAP básico não comprova controle dos workers do hbBridge.

O canal de depuração será separado dos protocolos RPC Protheus/NETIO e da
administração, com ativação explícita e acesso local/controlado. Logs e saída
do servidor não poderão interferir no framing DAP. Um adaptador ou cliente
externo será ferramenta de desenvolvimento opcional; o produto mantém seu
executável único. Breakpoints, stepping, pilha, variáveis e desconexão deverão
passar pelos critérios registrados no [TODO](TODO.pt-BR.md#depuração--frente-transversal-do-produto).

A inspeção aqui é da execução Harbour no hbBridge. O código AdvPL/TLPP usa as
ferramentas de depuração do AppServer; C e Zig precisam de símbolos e depurador
nativo compatível com o toolchain. A correlação da chamada ajudará a acompanhar
essas fronteiras, sem pressupor uma sessão única de stepping entre runtimes.

## Build do código atual

O build usa PowerShell 7+, o `hb_compile` gerenciado pelo próprio projeto,
Harbour e Zig nas revisões fixadas em `config/dependencies.json`. A compilação
do cliente Protheus/TLPP exige um AppServer e SDK configurados separadamente.
Zig participa tanto como toolchain de compilação Harbour/C quanto como
linguagem da biblioteca nativa vinculada ao servidor.

```powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/build-hbbridge.ps1
pwsh ./scripts/test-hbbridge.ps1
```

O bootstrap resolve as dependências e gera as ferramentas Harbour usadas pelo
produto e pelas verificações de commit. O build executa `zig build` e
`hbmk2 -comp=zig hbbridge.hbp`, gerando `out/hbbridge.exe` no Windows. Se esse
executável estiver em execução, o script pede que seja encerrado ou que se use
`-OutputDirectory` para compilar em outro diretório. Consulte
[dependências](docs/dependencies.pt-BR.md) e [scripts](scripts/README.pt-BR.md)
para os caminhos gerenciados, parâmetros e SDKs externos.

Usar Zig como toolchain C para compilar Harbour é uma escolha de build distinta
de implementar funcionalidades do servidor em Zig. Os dois usos já estão
presentes no produto e fazem parte da base tecnológica do projeto; a evolução
das extensões ocorrerá conforme os serviços forem consolidados.

Para testar o produto, execute `out/hbbridge.exe` a partir da raiz do projeto,
compile o cliente TLPP e rode `U_HBBridgeConnectionTest()` de
[hbbridgeconnectiontest.tlpp](src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp) no
Protheus. O teste exercita `Health`, `Echo` e, com
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitado (padrão atual),
`ADDON.Execute` com o módulo `examples/hbbridgesampleaddon.hb`. A execução a partir
da raiz permite ao servidor localizar o fonte em `addons/examples/`.
O [launcher de exemplo](examples/mvp/run.ps1)
prepara esse diretório automaticamente. O teste aceita host, porta e timeout,
preservando a chamada sem argumentos. As regressões Harbour podem ser executadas
com `scripts/test-hbbridge.ps1`; instruções em [testes](tests/README.pt-BR.md).

## Operação e próximos passos

O módulo [hbbridgesyslog.hb](src/hb/telemetry/hbbridgesyslog.hb) está disponível para enviar
eventos UDP a `127.0.0.1:514`, mas sua ligação ao fluxo do servidor permanece
pendente. Políticas mais amplas de identidade/tokens, configuração de acesso, gestão de credenciais e
políticas de módulos também fazem parte da consolidação da ponte.

O teste SQLite `U_HBBridgeQueryTest` foi homologado com o servidor preparado
por `examples/sql/run.ps1`. O próximo aceite SQL é MSSQL/ODBC com o perfil
correspondente. Serviço e conectores estão implementados; o launcher aceita
perfis em JSON ou INI, como `-Config config/examples/sqlite.ini`.
Em paralelo, a base de integração
deverá evoluir o contrato de transferência e ampliar os casos homologados.
NETIO/rede e VF IO nativo já têm testes; DBF via NETIO,
fachada de arquivos TLPP, serviço, processamento
em lotes/jobs e extensões C/Zig completam a evolução incremental.

Configuração e descoberta deverão informar quais serviços estão disponíveis,
quais limites foram negociados e quais versões estão em uso. Logs e métricas
de chamadas, bytes transmitidos/expandidos, memória, latência e erros orientarão
as escolhas de compressão e concorrência. O [roadmap](TODO.pt-BR.md) detalha as
dependências e os critérios de aceite, preservando as premissas Harbour/C/Zig.

## Licença e contribuições

Use **quatro espaços por nível de indentação** nos fontes próprios do projeto,
incluindo Harbour e TLPP, e identificadores em inglês. Arquivos ficam em
minúsculas; funções, procedures, métodos, namespaces e classes usam
**PascalCase**. O nome do arquivo é o nome da classe em minúsculas:
`HBBridgeClient` ↔ `hbbridgeclient.tlpp`. Veja os
[padrões](docs/standards.pt-BR.md). O
[.editorconfig](.editorconfig) registra esse padrão. Cabeçalhos de terceiros
preservam a formatação e os avisos de seus autores.

Fontes Harbour próprios usam `.hb`, fontes Protheus usam `.tlpp`, e addons
Harbour compilados usam `.hrb`. Módulos relacionados de Harbour/TLPP/C/Zig
seguem a mesma convenção de nomes-base; a extensão identifica a linguagem.
Builds comuns de `.hbp` mantêm o fluxo existente. `ADDON.Execute` continua
aceitando fontes `.prg` por compatibilidade, além de fontes `.hb` e módulos `.hrb`.

Prefira hashes no Harbour para registros, configurações, metadados e consultas
por chave, evitando arrays com posições que representam campos nomeados.
No AdvPL/TLPP, use [JSONObject](https://tdn.totvs.com/display/tec/Classe+JsonObject)
quando os dados fizerem parte do contrato JSON, ou
[THashMap](https://tdn.totvs.com/display/tec/Classe+THashMap) e as
[funções HashMap](https://tdn-homolog.totvs.com/pages/viewpage.action?pageId=77300615)
para mapas internos, conforme os tipos das chaves. Use arrays somente quando
forem estritamente necessários por uma exigência técnica concreta, como formatos
impostos pelas APIs ou pelos contratos. Avalie os custos de alocação, cópia e
busca; a existência de uma lista ou sequência não justifica, sozinha, um array.

Sempre que precisar expor uma função pública no Protheus (AdvPL/TLPP), prefira
uma classe com namespace explícito. Utilitários sem estado usam métodos
estáticos, como `HBBridge.Client.HBBridgeTime`. Funções e procedures de teste
podem usar o prefixo `U_`.
O pré-processador Protheus transforma `User Function <Name>` no símbolo
`U_<Name>`. Entradas já declaradas com esse prefixo podem ser preservadas,
como `procedure U_HBBridgeConnectionTest`, sem conversão para `User Function`.
Helpers privados ao arquivo podem usar `Static Function`. As
[convenções para agentes](AGENTS.pt-BR.md) registram essas regras para novas alterações.

O projeto ainda não possui um arquivo de licença publicado. A definição da
licença está na [proposta de licenciamento](docs/licensing.pt-BR.md): MIT para
código autoral, preservando os termos das dependências, com decisão pendente.
A revisão encontrou procedência a esclarecer no carregador de addons e no
relógio TLPP antes de padronizar os avisos. A proposta não substitui os
avisos de domínio público e de terceiros já presentes nos fontes.

---

## ⭐Gostou do projeto? Deixa uma estrelinha(⭐) aí no topo! Isso ajuda muito!
[![Stars](https://img.shields.io/github/stars/naldodj/hb.bridge?style=social)](https://github.com/naldodj/hb.bridge)
![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/naldodj/hb.bridge/refs/heads/main/clone-badge.json)

## 💼 Suporte Corporativo & Consultoria Especializada

O **hbBridge** é mantido como uma ferramenta open-source para a comunidade. Se a sua empresa utiliza esta biblioteca ou opera em grande escala com **ERP TOTVS Protheus** e precisa de apoio especializado, a **DNA Tech** oferece serviços corporativos dedicados:

* **Sustentação N3 & Arquitetura:** Resolução de incidentes complexos em customizações legadas e suporte arquitetural de alto nível.
* **Tuning de Banco e Rotinas:** Otimização de consultas, redução de *locks* e melhoria de performance em rotinas críticas (SQL Server, Oracle, PostgreSQL).
* **Integrações REST & Modernização:** Construção de APIs seguras, automações e modernização de bases legadas para TL++.
* **Modelos de Contratação:** Pacotes mensais de horas dedicadas (retainer com SLA) ou projetos de escopo fechado.

Precisa de apoio técnico sênior para o seu time ou para o ecossistema Protheus da sua operação?

📫 **Entre em contato para demandas B2B / PJ:**
[Conectar no LinkedIn](https://www.linkedin.com/in/naldodj/) • [Enviar E-mail](mailto:marinaldo.jesus@gmail.com) • [Visitar BlackTDN](https://blacktdn.com.br)

---

<img width="1024" height="1024" alt="dna_tech_logo_black_panter" src="https://github.com/user-attachments/assets/9b39a407-31ca-4a86-a1df-f76790e2036a" />
