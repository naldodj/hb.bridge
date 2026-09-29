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

Essa ligação já existe em [addon_loader.prg](src/hb/addons/addon_loader.prg):
o bloco C embutido usa `HB_FUNC`, `hb_parc` e `hb_retc` para chamar a função
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
| Servidor local | TCP multithread em `127.0.0.1:1512` por padrão, com dispatcher próprio. |
| Cliente Protheus | `THBBridgeClient`, JSON com frame `HBS1` e compressão em memória nos dois sentidos. |
| Serviços | `Health` chama a biblioteca Zig pela ponte C; `Echo` devolve os parâmetros; `ADDON.<arquivo>` executa um módulo Harbour. |
| Teste Protheus | `hbbridgeconnectiontest.tlpp` exercita `Health`, `Echo` e `ADDON.examples\sample_addon.prg`, incluindo o retorno de 200.000 caracteres no `Echo`. |
| Módulos Harbour | Compilação em memória de `.prg`/`.hb` e carregamento de `.hrb` pelo serviço `ADDON.`. |
| hbnetio | Biblioteca linkada em `hbbridge.hbp`; o servidor ainda não usa as APIs NETIO nem habilita `HB_EXTERN`. |
| Dados SQL | `TRPCDataSet` esboça o cliente de `RPCRDD.Query`; faltam o serviço de consulta e o teste com MSSQL e/ou SQLite. |
| Dados DBF | Acesso por RDDs nativos via NETIO previsto; ainda não integrado ao hbBridge. |
| VF IO | Integração de `hb_vf*` prevista para arquivos locais/remotos; a fachada de arquivos ainda não existe no servidor. |
| C e Zig | Ponte pela API C do Harbour e ABI C do Zig integrada ao `Health`; biblioteca Zig e toolchain exigidos pelo build atual. |
| Limites atuais | JSON declarado limitado a 16 MiB no servidor, compressão obrigatória e buffers de recepção de 65.535 bytes; falta negociação. |
| Operação | Executável de console; instalação como serviço e listener de administração ainda pendentes. |
| Syslog | Módulo UDP disponível no projeto, ainda sem chamadas no fluxo do servidor. |

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

O frame `HBS1` do MVP não é o protocolo NETIO. O endpoint Protheus deve ter
endereço e porta próprios configuráveis; `127.0.0.1:1512` permanece como perfil
de compatibilidade do MVP durante a transição. Simplesmente alterar a porta
do cliente TLPP para 2941 não o torna um cliente NETIO. Compartilhamento de
porta só poderá ser adotado após um mecanismo explícito de multiplexação e
testes de interoperabilidade; ele não é necessário ao desenho inicial.

### Rede e execução como serviço

Os padrões pretendidos acompanham o utilitário servidor hbnetio:

| Canal | Endereço de escuta padrão | Porta | Finalidade |
| --- | --- | --- | --- |
| Dados/RPC NETIO | `0.0.0.0` | `2941` | Clientes Harbour, RPC e arquivos remotos. |
| Administração | `127.0.0.1` | `2940` | Gestão separada do tráfego de aplicações. |
| Adaptador Protheus | Configurável | Configurável | Contrato interoperável e compatibilidade `HBS1`. |

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
HBS1|JSON|<tamanho-em-bytes-do-JSON>\n<payload-json>
```

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
[server.prg](src/hb/server/server.prg).

O limite declarado para o JSON enquadrado é de 16 MiB, uma decisão do MVP.
O teste manual usa
200.000 caracteres repetidos, um caso bastante compressível; a robustez com
dados pouco compressíveis, fragmentação TCP, envios parciais e limites antes
da descompressão ainda precisa de validação e ajustes. O fallback para conteúdo
sem `HBS1` ocorre depois da descompressão, e não constitui suporte documentado
a JSON cru no socket.

Atualmente, cliente e servidor tentam descomprimir cada leitura do socket,
embora TCP possa dividir ou juntar mensagens. O servidor já repete envios
parciais; o cliente TLPP ainda precisa desse tratamento. A nova versão deverá
enquadrar o conteúdo transmitido antes de descomprimir e tratar a recepção
como um fluxo de bytes. A compressão atual será mantida no perfil `HBS1`
durante sua migração; desligá-la exige um contrato reconhecido pelos dois lados.

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
homologado para aquele ambiente. O perfil legado `HBS1` mantém sua entrada
comprimida direta enquanto estiver em suporte.

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

O MVP é uma etapa de validação da arquitetura. A evolução manterá uma única
implementação dos componentes reutilizáveis em `src/`, organizada por
responsabilidade. A versão original permanece no histórico Git; as validações
de `Health`, `Echo`, `ADDON.` e os próximos testes SQL passam a proteger a
implementação do produto como testes de regressão.

`examples/mvp/` será um cenário mínimo executável com configuração e instruções
para usar o mesmo binário e núcleo. Poderá selecionar poucos serviços para
demonstrar a integração, sem manter cópias de servidor, dispatcher, loader ou
enquadramento. O exemplo acompanhará o núcleo atual; o histórico preservará a
prova de conceito original.

Comportamentos legados necessários, como `HBS1`, ficam isolados no adaptador
Protheus e cobertos por testes de compatibilidade. Componentes existentes serão
extraídos e reorganizados gradualmente, validando o comportamento antes e depois
de cada mudança. A estrutura de diretórios distingue produto, exemplos e testes;
a aptidão para produção depende dos critérios de aceite, não do nome da pasta.

### Estrutura atual

```text
hb.bridge/
|-- addons/examples/        # Exemplo de módulo Harbour
|-- config/examples/        # Esboços de configuração
|-- docs/                   # Documentação técnica da integração
|-- scripts/                # Build e operação
|-- src/hb/                 # Servidor MVP, dispatcher, loader e Syslog
|-- src/tlpp/               # Cliente RPC e fachada de dataset Protheus
|-- src/zig/runtime/        # Biblioteca Zig integrada ao Harbour pela ABI C
|-- tests/                  # Testes Protheus e testes locais Harbour
|-- build.zig               # Build da biblioteca Zig demonstrativa
|-- hbbridge.hbp            # Build atual do servidor
|-- README.md
`-- TODO.md
```

### Estrutura pretendida

A árvore abaixo é uma proposta; a movimentação dos fontes ainda não foi feita.

```text
hb.bridge/
|-- src/
|   |-- hb/
|   |   |-- host/                    # Entrada, configuracao, console/servico
|   |   |-- core/                    # Registro, despacho, contexto e recursos
|   |   |-- transports/
|   |   |   |-- netio/               # Adaptacao e ciclo de vida do NETIO nativo
|   |   |   `-- protheus/            # Novo contrato e compatibilidade HBS1
|   |   |-- services/                # Health, Echo, ADDON, SQL, DBF e arquivos VF
|   |   |-- addons/                  # Compilacao, carga e ciclo de vida dos modulos
|   |   `-- telemetry/               # Logs e metricas
|   |-- c/                          # Ponte API Harbour / ABI C, extraida do PRG
|   |-- zig/                        # Extensoes nativas
|   `-- tlpp/                       # Cliente Protheus e TRPCDataSet
|-- addons/examples/                # Modulos de demonstracao
|-- examples/mvp/                   # Perfil minimo usando o produto
|-- config/examples/                # Perfis de rede, dados e operacao
|-- tests/
|   |-- unit/                       # Componentes Harbour, C e Zig
|   |-- contract/                   # Tipos, versoes, codecs e amostras de dados
|   `-- integration/
|       |-- harbour/                # NETIO, dados, modulos e ciclo de vida
|       `-- protheus/               # Cliente TLPP, HBS1 e contrato novo
|-- docs/                           # Arquitetura, protocolo e operacao
|-- scripts/                        # Build, empacotamento e instalacao
|-- hbbridge.hbp                    # Composicao do executavel unico
`-- build.zig                       # Bibliotecas nativas vinculadas ao produto
```

O build e a lista de componentes serão compartilhados entre execução normal,
serviço e perfil de demonstração. A migração de `server/` e `dispatcher/` para
`host/`, `core/`, `transports/` e `services/` será feita por responsabilidade,
preservando testes e corrigindo caminhos de módulos, scripts e documentação
no mesmo passo. O C embutido no loader poderá ser extraído para `src/c/` sem
alterar a fronteira Harbour ↔ C ↔ Zig.

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
[hbbridgeconnectiontest.tlpp](tests/protheus/hbbridgeconnectiontest.tlpp) no
Protheus. O teste exercita `Health`, `Echo` e, com
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitado (padrão atual),
`ADDON.examples\sample_addon.prg`. A execução a partir da raiz permite ao
servidor localizar o fonte em `addons/examples/`.

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
