# hbBridge

Ponte extensível que disponibiliza os recursos de Harbour, C e Zig ao ERP
TOTVS Protheus (AdvPL/TLPP) e a clientes Harbour nativos. O objetivo é ampliar
as capacidades dessas aplicações com RPC, acesso a dados e arquivos, execução
de módulos e processamento nativo, aproveitando o ecossistema Harbour.

Este documento distingue o MVP implementado do desenho pretendido. Rede,
serviço, negociação, streams e extensões descritos como evolução ainda precisam
ser integrados e validados; o [TODO.md](TODO.md) registra as entregas e os aceites.

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

Essa ligação está em [zig_bridge.c](src/c/zig_bridge.c), extraída do loader:
o adaptador C usa `HB_FUNC`, `hb_parc` e `hb_retc` para chamar a função
`ZigEngine_Dispatch` exportada pela [biblioteca Zig](src/zig/runtime/engine.zig).
O caminho interno é **Harbour ↔ C ↔ Zig**, dentro do servidor.

### Zig: interoperabilidade com C e modernização

Zig foi escolhido pela interoperabilidade com C e pelos recursos modernos
que oferece para desenvolver componentes nativos: tratamento explícito de
erros, tipos opcionais, controle explícito de alocação e liberação de recursos,
e avaliação em tempo de compilação (`comptime`). Esses recursos permitem
evoluir as extensões mantendo a integração com Harbour pela ABI C.
Veja a [visão geral oficial do Zig](https://ziglang.org/learn/overview/).

No projeto, Zig tem dois papéis complementares: o toolchain usado no build
Harbour/C (`hbmk2 -comp=zig`) e a implementação de extensões nativas. O MVP
já vincula `hbBridge_zig` e exercita essa integração no serviço `Health`.
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
- Preservar a compatibilidade do MVP durante a evolução para transferência
  em blocos e compressão negociada, respeitando a capacidade de cada cliente.
- Permitir instalação como serviço, com endereços, portas, diretórios,
  concorrência e políticas de recursos configuráveis.
- Evoluir as extensões Zig pela ABI C conforme a base Harbour for consolidada.

O AppServer continua responsável pelo ambiente Protheus. O hbBridge amplia
suas capacidades por uma interface RPC e oferece acesso nativo a aplicações
Harbour, preservando a programação xBase na camada de serviços.

## Estado atual do MVP

| Recurso | Situação no código atual |
| --- | --- |
| Servidor TCP | Bind `0.0.0.0`, porta padrão `1512`, multithread e dispatcher próprio; cliente local usa `127.0.0.1`. |
| Cliente Protheus | `THBBridgeClient`, JSON com assinatura `HBBRIDGE/1`, compatibilidade `HBS1` e compressão em memória nos dois sentidos; uma conexão por chamada. |
| Serviços | `Health` chama a biblioteca Zig pela ponte C; `Echo` devolve os parâmetros; `ADDON.<arquivo>` executa um módulo Harbour. |
| Teste Protheus | `hbbridgeconnectiontest.tlpp` exercita `Health`, `Echo` e `ADDON.examples\sample_addon.prg`, incluindo o retorno de 200.000 caracteres no `Echo`. |
| Módulos Harbour | Compilação em memória de `.prg`/`.hb` e carregamento de `.hrb` pelo serviço `ADDON.`. |
| hbnetio | Biblioteca linkada pela composição compartilhada `hbbridge.hbm`; o servidor ainda não usa as APIs NETIO nem habilita `HB_EXTERN`. |
| Dados SQL | `TRPCDataSet` esboça o cliente de `RPCRDD.Query`; faltam o serviço de consulta e o teste com MSSQL e/ou SQLite. |
| Dados DBF | Acesso por RDDs nativos via NETIO previsto; ainda não integrado ao hbBridge. |
| VF IO | Integração de `hb_vf*` prevista para arquivos locais/remotos; a fachada de arquivos ainda não existe no servidor. |
| C e Zig | Ponte pela API C do Harbour e ABI C do Zig integrada ao `Health`; biblioteca Zig e toolchain exigidos pelo build atual. |
| Limites atuais | JSON declarado limitado a 16 MiB no servidor, compressão obrigatória e buffers de recepção de 65.535 bytes; falta negociação. |
| Operação | Executável de console; instalação como serviço e listener de administração ainda pendentes. |
| Syslog | Módulo UDP disponível no projeto, ainda sem chamadas no fluxo do servidor. |
| Depuração | `hbdebug` disponível no Harbour; falta preparar e validar o perfil de depuração do hbBridge e dos addons. HBDAP ainda não integrado. |

Com `Health`, `Echo` e `ADDON.` exercitados pelo teste Protheus, o próximo
teste funcional é `RPCRDD.Query` com MSSQL e/ou SQLite. A integração do hbnetio
continua sendo um trabalho de arquitetura: a presença da biblioteca no link
não transforma o transporte atual em RPC nativo do hbnetio. Os marcos gerais
e critérios de aceite estão no [TODO.md](TODO.md).

## Arquitetura pretendida

```text
Protheus / AdvPL / TLPP                  Clientes Harbour
          |                                     |
 contrato interoperavel                  protocolo NETIO nativo
          |                                     |
 adaptador Protheus                     hbnetio: RPC / arquivos
 (endpoint configuravel)                 0.0.0.0:2941
          |                                     |
          +---------- hbBridge -----------------+
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

O desenho proposto hospeda NETIO e o adaptador Protheus no hbBridge, com um
núcleo comum de serviços. Cada adaptador traduz seu transporte para esse
núcleo; módulos, consultas e extensões não precisam conhecer o protocolo do
cliente. Os listeners compartilham catálogo e configuração; cada chamada
mantém contexto, áreas de trabalho, conexões e módulos com propriedade definida.

### Um executável, módulos internos

A implantação de referência terá **um executável hbBridge**, em console ou
como serviço, incorporando a biblioteca `hbnetio` e chamando suas APIs no mesmo
processo. A vinculação inicial será estática, aproveitando o `-lhbnetio` já
presente no build. O trabalho é integrar inicialização, RPC, administração e
encerramento ao host do hbBridge, usando funções como `netio_MTServer`.
Referência: [APIs do hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

O ponto de entrada será único e coordenará os dois listeners e os recursos
ativos. Não haverá dependência de iniciar um `hbnetio.exe` separado para atender
as chamadas. O código do utilitário upstream serve de referência para adaptar
configuração e serviço, preservando o uso da biblioteca nativa.

Uma DLL poderá ser adotada para extensões com atualização independente, quando
isso justificar uma ABI e um ciclo de carregamento próprios. Um processo
separado poderá ser útil para isolar alguma carga específica. Essas opções
não são necessárias à integração inicial do NETIO. Drivers ODBC e bibliotecas
de conectores continuam como dependências conforme o build escolhido.

O frame `HBBRIDGE/1` do MVP, com alias legado `HBS1`, não é o protocolo NETIO.
O endpoint Protheus deve ter endereço e porta próprios configuráveis. Hoje o
servidor escuta em `0.0.0.0:1512`; `127.0.0.1:1512` é o destino do cliente local. Simplesmente alterar a porta
do cliente TLPP para 2941 não o torna um cliente NETIO. Compartilhamento de
porta só poderá ser adotado após um mecanismo explícito de multiplexação e
testes de interoperabilidade; ele não é necessário ao desenho inicial.

### Rede e execução como serviço

Os padrões pretendidos acompanham o utilitário servidor hbnetio:

| Canal | Endereço de escuta padrão | Porta | Finalidade |
| --- | --- | --- | --- |
| Dados/RPC NETIO | `0.0.0.0` | `2941` | Clientes Harbour, RPC e arquivos remotos. |
| Administração | `127.0.0.1` | `2940` | Gestão separada do tráfego de aplicações. |
| Adaptador Protheus | Configurável | Configurável | Contrato interoperável e compatibilidade com o MVP `HBBRIDGE/1`/`HBS1`. |

Esses valores correspondem a `_NETIOSRV_IPV4_DEF`, `_NETIOSRV_PORT_DEF`,
`_NETIOMGM_IPV4_DEF` e `_NETIOMGM_PORT_DEF`. `0.0.0.0` é o bind do servidor;
clientes usam seu IP ou DNS real. No utilitário upstream, a administração
depende de senha configurada. A integração deve preservar essa separação e
reaproveitar configuração de interfaces, portas, diretório raiz e acesso.
Referência: [servidor hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.prg).

O hbBridge deverá executar em console e como serviço Windows, reaproveitando
a [integração do hbnetio com o gerenciador de serviços](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/_winsvc.prg).
No Linux, a implantação
deverá oferecer execução supervisionada pelo gerenciador do sistema. Instalação,
início, parada e recuperação usarão o mesmo núcleo, com caminhos absolutos para
configuração, módulos, dados e logs, independentes do diretório de trabalho.
A parada deverá encerrar cursores e streams e tratar chamadas em andamento.
Esses modos ainda não estão implementados no MVP.

### Extensibilidade e capacidades para as aplicações

O registro de serviços deverá descrever nome, versão, parâmetros, resultados,
erros, permissões e suporte a execução imediata, em lote ou por stream. Um cliente
poderá consultar as capacidades instaladas; contribs ausentes no build serão
reportadas como indisponíveis. Novos serviços entram por esse registro sem
exigir uma alteração no transporte.

| Capacidade pretendida | Recurso a aproveitar | Aplicação prática |
| --- | --- | --- |
| Funções e rotinas xBase | Core Harbour, contribs e addons `.prg`/`.hb`/`.hrb`. | Publicar rotinas próximas da linguagem do desenvolvedor Protheus. |
| Consultas e processamento de dados | `rddsql`/`SQLMIX`, conectores, RDDs DBF e NETIO. | Consultar, filtrar e transformar dados no servidor, devolvendo páginas ou resultados agregados. |
| Arquivos e conteúdo | Harbour VF IO API (`hb_vf*`), provedores como NETIO, compressão e arquivos ZIP. | Operar arquivos locais/remotos e transferir conteúdo em blocos. |
| Integrações externas | Contribs existentes, como `hbcurl` e `hbexpat`. | Consumir APIs e processar XML no servidor, expondo operações de domínio ao cliente. |
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
ou acrescentar `-lhbnetio` ao MVP não ativa esse trecho. Na execução do utilitário,
o RPC também precisa ser habilitado com `-rpc` ou `-rpc=<módulo>`.

A incorporação ao build do hbBridge ainda faz parte da migração. Contribs e
drivers adicionais precisam ser vinculados explicitamente; `HB_EXTERN` não
instala suas dependências nem define a política de chamadas Protheus.

Referências: [fonte do servidor hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.prg),
[projeto hbnetio.hbp](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.hbp)
e [vinculação das funções do core](https://github.com/harbour/core/blob/master/src/hbextern/hbextern.prg).

### Clientes Harbour e serialização nativa

Clientes Harbour deverão conectar-se diretamente ao NETIO, usando operações
como `netio_Connect`, `netio_FuncExec` e `netio_Disconnect`. O RPC nativo já
serializa argumentos e resultados; o adaptador hbBridge deve receber valores
Harbour, sem exigir uma conversão intermediária para JSON. Veja a
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

A [avaliação técnica](docs/harbour-vfio-trpc.md) registra os trechos examinados,
as restrições encontradas e os critérios para extrair código. A análise foi
estática; nenhuma classe TRPC foi incorporada ao servidor nesta etapa.

## Módulos e acesso a dados

O utilitário hbnetio oferece `-rpc=<arquivo>` para carregar um módulo `.hrb`
ou compilar um fonte `.prg`/`.hb` com os recursos do Harbour. Esse modo utiliza
a função `HBNETIOSRV_RPCMAIN` do módulo como ponto de despacho. A integração
deve reaproveitar esse mecanismo e estabelecer o contrato de chamadas.
Veja o [exemplo oficial](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/rpcdemo.hb).

No MVP, o loader em [addon_loader.prg](src/hb/addons/addon_loader.prg) já recebe
chamadas `ADDON.<arquivo>`. Para `.prg` e `.hb`, compila o fonte em memória com
`hb_compileBuf`; para `.hrb`, carrega o módulo compilado. A execução usa
`hb_hrbLoad`/`hb_hrbDo`/`hb_hrbUnload`, com símbolos locais à chamada.

O teste Protheus chama `ADDON.examples\sample_addon.prg`, resolvido sob
`./addons/`, e verifica o retorno `success` do módulo de exemplo. Esse fluxo
já faz parte do MVP; a integração ao RPC nativo hbnetio e as regras de
publicação dos módulos continuam no roadmap.

### SQL: próximo teste com MSSQL e/ou SQLite

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

O trabalho do projeto é expor essas capacidades ao Protheus com perfis lógicos,
conversão de tipos, resultados e erros consistentes. `RPCRDD.Query` e
`TRPCDataSet` são uma proposta de fachada RPC para esses recursos; criar novos
drivers de banco ou um novo RDD não faz parte do escopo inicial. O suporte
existente no Harbour ainda precisa ser habilitado e testado nesta ponte.

O próximo teste deve chamar `RPCRDD.Query` a partir do Protheus, usando
MSSQL e/ou SQLite. Para viabilizá-lo, falta implementar o serviço no dispatcher
e habilitar o conector escolhido. A fachada atual em
[trpcdataset.tlpp](src/tlpp/trpcdataset.tlpp) envia `alias` e `sql` e espera
`success`, `header` e `rows` no retorno. A validação deve cobrir uma consulta
real, leitura dos campos e navegação pelo dataset, resultado vazio e erro
de consulta ou conexão.

A evolução deverá acrescentar parâmetros SQL, metadados de tipo e precisão,
paginação ou cursores, expiração e fechamento, além de transações com escopo
explícito. Campos grandes e BLOBs também precisarão de transferência incremental.
Paginar a resposta não basta se o conector materializar o resultado inteiro:
o consumo de memória deve ser medido desde a consulta até o cliente.

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
`RPCRDD.Query` é a fachada prevista para as consultas SQL.

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
integração está em [Harbour VF IO e TRPC](docs/harbour-vfio-trpc.md).

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

`HBBRIDGE/1` identifica o produto e a versão atual do frame. O servidor aceita
também `HBS1` e responde com a assinatura recebida; o cliente TLPP envia a nova
e aceita ambas nas respostas. Atualize primeiro o servidor e depois os clientes:
um servidor antigo não passa a aceitar a nova assinatura automaticamente.
Essa identificação ainda não implementa a negociação prevista para o produto.

O frame inteiro é comprimido para envio. O tamanho declarado é o do JSON
descomprimido, sem o cabeçalho, e não o tamanho transmitido no socket.

| Sentido | Compressão | Descompressão |
| --- | --- | --- |
| Protheus → Harbour | `GzStrComp`, no cliente TLPP | `hb_ZUncompress`, no servidor |
| Harbour → Protheus | `hb_gzCompress`, no servidor | `GzStrDecomp`, no cliente TLPP |

Esse caminho já funciona no MVP com buffers em memória. Não depende de arquivos
temporários nem das APIs de arquivo `GzCompress`/`GzDecomp`. O cliente atual
envia JSON dentro do frame comprimido, e o servidor também comprime a resposta.
Os detalhes estão em [thbbridgeclient.tlpp](src/tlpp/thbbridgeclient.tlpp) e
[framing.prg](src/hb/transports/protheus/framing.prg).

O limite declarado para o JSON enquadrado é de 16 MiB, uma decisão do MVP.
O teste manual usa
200.000 caracteres repetidos, um caso bastante compressível; a robustez com
dados pouco compressíveis, fragmentação TCP, envios parciais e limites antes
da descompressão ainda precisa de validação e ajustes. O fallback para conteúdo
sem as assinaturas reconhecidas ocorre depois da descompressão, e não constitui suporte documentado
a JSON cru no socket.

Atualmente, cliente e servidor tentam descomprimir cada leitura do socket,
embora TCP possa dividir ou juntar mensagens. O servidor já repete envios
parciais; o cliente TLPP ainda precisa desse tratamento. A nova versão deverá
enquadrar o conteúdo transmitido antes de descomprimir e tratar a recepção
como um fluxo de bytes. A compressão atual será mantida no perfil do MVP
(`HBBRIDGE/1` e alias `HBS1`) durante sua migração; desligá-la exige um contrato reconhecido pelos dois lados.

## Evolução do contrato e da transferência

O contrato de serviços será compartilhado, com duas representações: valores
nativos no caminho Harbour/NETIO e uma representação interoperável no adaptador
Protheus, inicialmente JSON. A versão do protocolo de transporte e a versão
de cada serviço serão identificadas separadamente.

### Negociação e tipos

A nova versão da conexão Protheus começará com uma troca pequena de capacidades,
de enquadramento conhecido e sem compressão, para escolher versão, codec,
compressão, tamanho por bloco e modos de transferência. Clientes Harbour farão
a descoberta de serviços pela conexão NETIO já estabelecida, preservando seu
handshake nativo. O cliente deverá declarar limites que consegue cumprir;
quando não puder obter sua configuração efetiva, usará um perfil explícito
homologado para aquele ambiente. O perfil do MVP (`HBBRIDGE/1` e alias `HBS1`)
mantém sua entrada comprimida direta enquanto estiver em suporte.

| Parte do contrato proposto | Definição necessária |
| --- | --- |
| Chamada | Identificador, serviço e versão, parâmetros, contexto e prazo de execução. |
| Resposta | Correlação com a chamada, sucesso, resultado e metadados; erro com código, origem e indicação de possibilidade de nova tentativa. |
| Tipos | Nulo, vazio, lógicos, inteiros, decimais/moeda, datas, timestamps, strings, binários, arrays e hashes; conversão explícita entre runtimes. |
| Texto e números | Encoding definido, contagem de bytes e preservação de precisão; fuso horário e representação de datas documentados. |
| Recursos remotos | Sessão, identificadores de cursor/stream/job, expiração, fechamento e cancelamento cooperativo. |
| Compatibilidade | Mapeamento dos retornos atuais de `Health`, `Echo`, `ADDON.` e `TRPCDataSet`; versão incompatível gera erro identificável. |

O enquadramento externo do novo adaptador deverá identificar versão, chamada,
codec, compressão e comprimento em bytes transmitidos e expandidos de cada
bloco. A especificação binária/textual exata será validada com ambos os clientes
antes da implementação. Com isso, o receptor reúne uma unidade completa antes
de descomprimir, sem depender de quantos bytes cada `Receive` devolveu.

Novas tentativas após desconexão respeitarão a semântica do serviço: o mesmo
identificador de chamada não garante, sozinho, execução única. Operações que
alteram dados precisarão de idempotência ou consulta do resultado anterior.

### Conexões persistentes e contexto de execução

O brainstorming foi avaliado em [Transportes, sessões e segurança](docs/transportes-sessoes-seguranca.md).
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

Cada chamada terá contexto explícito de identidade, empresa/filial autorizadas,
correlação e prazo, com limpeza de áreas de trabalho, transações e buffers mesmo
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

O limite fixo de 16 MiB não será o teto funcional do projeto. O desenho deverá
permitir volumes lógicos maiores que uma mensagem ou string, usando páginas,
blocos e streams. A capacidade real do Harbour depende de memória disponível,
arquitetura, representações e APIs utilizadas; cada transporte e conector
também precisa ter seus limites técnicos validados.

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

## MVP, produto e organização dos fontes

A organização prevista foi aplicada antes da evolução funcional. Os componentes
reutilizáveis ficam em `src/`, com uma implementação do servidor e um ponto de
entrada. [examples/mvp](examples/mvp/README.md) oferece o perfil mínimo usando
o mesmo executável, os clientes e o addon compartilhados. O histórico Git
preserva o MVP anterior à reorganização.

### Estrutura atual

```text
hb.bridge/
|-- src/
|   |-- hb/
|   |   |-- host/main.prg                 # Entrada e ciclo de vida do console
|   |   |-- core/dispatcher.prg           # Despacho atual (ainda usa JSON)
|   |   |-- transports/
|   |   |   |-- netio/                   # Espaco reservado; integracao pendente
|   |   |   `-- protheus/
|   |   |       |-- tcp_server.prg       # Listener e workers do MVP
|   |   |       `-- framing.prg          # Recepcao/envio HBBRIDGE/1 e HBS1
|   |   |-- services/builtin.prg         # Health, Echo e ADDON existentes
|   |   |-- addons/addon_loader.prg      # Compilacao e carga de modulos
|   |   `-- telemetry/syslog.prg         # Modulo Syslog existente
|   |-- c/zig_bridge.c                  # API Harbour / ABI C para Zig
|   |-- zig/runtime/engine.zig          # Biblioteca Zig demonstrativa
|   `-- tlpp/                           # Cliente Protheus e TRPCDataSet
|-- addons/examples/                    # Addon compartilhado
|-- examples/mvp/                       # README e launcher do mesmo produto
|-- config/examples/                    # Esbocos de configuracao
|-- tests/
|   |-- unit/                           # Espaco reservado para testes unitarios
|   |-- contract/                       # Espaco reservado para o novo contrato
|   `-- integration/
|       |-- harbour/                    # Suite MT e fixtures HRB
|       `-- protheus/                   # Teste TLPP Health/Echo/ADDON
|-- docs/                               # Arquitetura, analises e validacao
|-- scripts/                            # Build e runner de testes
|-- hbbridge.hbp                        # Executavel: entrada + componentes
|-- hbbridge.hbm                        # Fontes/flags compartilhados com testes
`-- build.zig                           # Build da biblioteca Zig
```

A estrutura pretendida agora está materializada. O [registro da reorganização](docs/reorganizacao.md)
detalha os caminhos anteriores, a revisão de referência e a comparação dos testes.
`hbbridge.hbp` compõe o host com `hbbridge.hbm`; o projeto de testes reutiliza
esse mesmo conjunto de componentes, com sua própria entrada de teste. O launcher
do exemplo posiciona o diretório de trabalho para o loader localizar `addons/`.

A extração preserva os retornos e limites atuais. O dispatcher e os handlers
ainda usam o contrato JSON do MVP; registro versionado e contexto nativo ficam
no marco 1. NETIO, testes unitários/contratuais dedicados e execução como serviço
continuam pendentes. Os READMEs das pastas reservadas identificam esse estado;
a existência dos diretórios não significa que os recursos foram implementados.

## Depuração: hbdebug primeiro, HBDAP como evolução

A depuração fará parte do desenvolvimento dos serviços e addons desde o MVP,
usando a mesma implementação do produto. A primeira etapa será aproveitar o
**`hbdebug`, depurador nativo do Harbour**, com breakpoints, execução passo a
passo e inspeção de pilha e variáveis em uma execução de desenvolvimento em
console. Referência: [depurador Harbour](https://github.com/harbour/core/tree/master/src/debug).

O perfil deverá compilar os fontes Harbour com informações de depuração (`-b`),
vincular o depurador e manter os fontes correspondentes acessíveis. Isso inclui
os `.prg`/`.hb` compilados em memória pelo loader e os `.hrb` preparados fora
do servidor. Hoje a composição [hbbridge.hbm](hbbridge.hbm) e a chamada a `hb_compileBuf` no
[loader](src/hb/addons/addon_loader.prg) não habilitam `-b`; ter `hbdebug` no
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
passar pelos critérios registrados no [TODO](TODO.md#depuração--frente-transversal-desde-o-mvp).

A inspeção aqui é da execução Harbour no hbBridge. O código AdvPL/TLPP usa as
ferramentas de depuração do AppServer; C e Zig precisam de símbolos e depurador
nativo compatível com o toolchain. A correlação da chamada ajudará a acompanhar
essas fronteiras, sem pressupor uma sessão única de stepping entre runtimes.

## Build do código atual

O caminho atual usa PowerShell 7+, `hb_compile` com Harbour em `out/zig`, Zig
0.16 ou a versão validada no ambiente, e Protheus/TLPP para compilar o cliente.
Zig participa tanto como toolchain de compilação Harbour/C quanto como
linguagem da biblioteca nativa vinculada ao servidor.

```powershell
.\scripts\build-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

O script executa `zig build` e `hbmk2 -comp=zig hbbridge.hbp`, gerando
`out/hbBridge.exe`. Seu parâmetro padrão ainda aponta para
`C:\GitHub\hb_compile`. Antes de compilar, encerra o executável canônico ativo
e remove variantes `hbBridge-*` de `.exe`/`.pdb` em `out`.

Usar Zig como toolchain C para compilar Harbour é uma escolha de build distinta
de implementar funcionalidades do servidor em Zig. Os dois usos já estão
presentes no MVP e fazem parte da base tecnológica do projeto; a evolução
das extensões ocorrerá conforme os serviços forem consolidados.

Para testar o MVP, execute `out/hbBridge.exe` a partir da raiz do projeto,
compile o cliente TLPP e rode `U_HBBridgeConnectionTest()` de
[hbbridgeconnectiontest.tlpp](tests/integration/protheus/hbbridgeconnectiontest.tlpp) no
Protheus. O teste exercita `Health`, `Echo` e, com
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitado (padrão atual),
`ADDON.examples\sample_addon.prg`. A execução a partir da raiz permite ao
servidor localizar o fonte em `addons/examples/`. O [launcher MVP](examples/mvp/run.ps1)
prepara esse diretório automaticamente. As regressões Harbour podem ser executadas
com `scripts/test-hbbridge.ps1`; instruções em [testes](tests/README.md).

## Operação e próximos passos

O módulo [syslog.prg](src/hb/telemetry/syslog.prg) está disponível para enviar
eventos UDP a `127.0.0.1:514`, mas sua ligação ao fluxo do servidor permanece
pendente. Autenticação, configuração de acesso, gestão de credenciais e
políticas de módulos também fazem parte da consolidação da ponte.

O próximo teste funcional é `RPCRDD.Query` com MSSQL e/ou SQLite, após
implementar o serviço e habilitar seu conector. Em paralelo, a base de integração
deverá ativar NETIO para clientes Harbour, parametrizar rede e homologar o
contrato de transferência. DBF via NETIO, arquivos pela VF IO API, serviço, processamento
em lotes/jobs e extensões C/Zig completam a evolução incremental.

Configuração e descoberta deverão informar quais serviços estão disponíveis,
quais limites foram negociados e quais versões estão em uso. Logs e métricas
de chamadas, bytes transmitidos/expandidos, memória, latência e erros orientarão
as escolhas de compressão e concorrência. O [roadmap](TODO.md) detalha as
dependências e os critérios de aceite, preservando as premissas Harbour/C/Zig.

## Licença e contribuições

O projeto ainda não possui um arquivo de licença publicado. A definição da
licença permanece no roadmap, antes da primeira distribuição pública.

---

## ⭐Gostou do projeto? Deixa uma estrelinha(⭐) aí no topo! Isso ajuda muito!
[![Stars](https://img.shields.io/github/stars/naldodj/hb.bridge?style=social)](https://github.com/naldodj/hb.bridge)
![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/naldodj/hb.bridge/refs/heads/master/clone-badge.json)

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
