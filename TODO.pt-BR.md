# Roadmap do hbBridge

[English](TODO.md)

[WIP](WIP.pt-BR.md) registra o pacote ativo delimitado, tarefas ordenadas,
decisões, pré-requisitos e evidências. Continue por ele, sem reanalisar todo
este roadmap. Concilie itens concluídos aqui ao encerrar o pacote;
commits/publicações intermediários preservam seu progresso. Pacote 001: MSSQL real.

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

O objetivo é disponibilizar os recursos de Harbour, C e Zig ao Protheus e a
clientes Harbour nativos por uma integração extensível. O [README.md](README.pt-BR.md)
registra os fundamentos, o estado do produto e o desenho pretendido.

## Premissas a preservar

- **Harbour:** a familiaridade sintática xBase com AdvPL/TLPP facilita a
  programação dos serviços; runtime, RDDs e contribs fornecem a base funcional.
- **C:** a API nativa Harbour e a ABI C conectam o runtime às bibliotecas e ao Zig.
- **Zig:** interoperabilidade com C, modernização de componentes nativos e
  toolchain de build são fundamentos do projeto e evoluem junto com a ponte.
- **Dois perfis de cliente:** NETIO e serialização nativa para Harbour;
  contrato interoperável adaptado às capacidades do Protheus.
- **Extensibilidade:** serviços versionados e descobertos em um registro comum,
  independentes de transporte, codec e linguagem de implementação.
- **HTTP e web:** usar `hbhttpd` e suas dependências para HTTP/REST e
  administração web de hbBridge/NETIO, compartilhando o mesmo núcleo.
- **Nomes e fontes:** identificadores em inglês, arquivos em minúsculas;
  funções, procedures, métodos, namespaces e classes em PascalCase. O arquivo
  usa o nome da classe em minúsculas; fontes próprios usam quatro espaços.
- **Arquivos:** Harbour VF IO API (`hb_vf*`) como base comum para provedores
  locais/remotos; clientes TLPP usam uma fachada de serviços com recursos por sessão.
- **Implementação única:** componentes reutilizáveis em `src/`, launcher de
  exemplo em `examples/mvp/` e testes dos componentes reais do produto. O
  histórico Git preserva as provas de conceito anteriores.
- **Estruturas de dados:** preferir hashes no Harbour e `JSONObject`/`THashMap`
  (ou funções HashMap) no TLPP para registros e mapas por chave. Usar arrays apenas
  quando estritamente necessários por exigência técnica, considerando custos de
  alocação, cópia e busca; listas ou sequências não justificam seu uso por si só.
- **Depuração:** adotar inicialmente `hbdebug`, já nativo do Harbour; evoluir
  para HBDAP opcional conforme a maturidade do projeto privado e os testes no hbBridge.
- **Volume:** não impor um teto arbitrário por padrão; distinguir capacidades
  reais dos runtimes de políticas operacionais opcionais. Evoluir para blocos
  negociados, considerando `MAXSTRINGSIZE` e o consumo de memória no TLPP.
- **Contrato Protheus:** usar somente `HBBRIDGE/1`, JSON enquadrado e gzip na
  implementação atual; evoluir a negociação de `none`/`gzip` e blocos no
  contrato do produto. Harbour/NETIO usa seus mecanismos nativos.
- **Rede e serviço:** NETIO em `0.0.0.0:2941`, administração em
  `127.0.0.1:2940`, com configuração própria e instalação como serviço. Um único
  executável hbBridge incorpora `hbnetio` por chamadas de função no mesmo processo.

As caixas concluídas abaixo registram código existente, não homologação geral.
Recursos disponíveis no Harbour só serão considerados integrados após os aceites.

## Base existente — preservar e ampliar

- [ ] Delegar dependências externas selecionadas, incluindo OpenSSL, ao
  hb_compile; consumir ambiente gerado, distribuir runtime e validar cache
  por capacidades/triplet/versões, sem duplicar resolvedor.
- [ ] Resolver upstream a lacuna Linux nativo do hb_compile ou declarar rota
  WSL/Docker suportada; fixar também baselines/checksums dos pacotes externos.

- [x] Servidor TCP multithread, bind `0.0.0.0` e porta padrão `1512`; destino local `127.0.0.1`.
- [x] Registro/dispatcher com `Health`, `Echo` e `ADDON.Execute`.
- [x] `Health` exercitando Harbour → C → Zig no build atual.
- [x] Cliente TLPP com frame `HBBRIDGE/1|JSON|<bytes-do-JSON>\n<payload-json>`.
- [x] Compressão em memória nos dois sentidos: `GzStrComp`/`GzStrDecomp` no TLPP
  e zlib incremental pela API C no servidor.
- [x] Teste Protheus de `Health`, `Echo` e `ADDON.Execute` com o módulo de exemplo,
  incluindo retorno de 200.000 caracteres repetidos no `Echo`.
- [x] Compilação em memória de `.prg`/`.hb` e carregamento de `.hrb`, com
  símbolos locais ao HRB ativo e descarregamento do módulo.
- [x] Testes Harbour no repositório para concorrência, isolamento e falhas de addons.
- [x] Envio parcial tratado no servidor e no código TLPP; homologação TLPP do ajuste pendente.
- [x] Build Harbour/C com Zig e biblioteca `hbbridge_zig` vinculada.
- [x] Biblioteca `hbnetio` na composição `hbbridge.hbm`, com listener nativo integrado no marco 1.
- [x] `RPCRDD.Query` com SQLMIX/SQLite/MSSQL-ODBC, resultados por chave,
  páginas no SGBD e cliente `HBBridgeRPCDataSet`; SQLite AppServer aceito em 2026-10-04,
  com 29 checks verdadeiros; reconfirmado em 2026-10-07 às 16:13:33,
  thread 27136, `profile=sqlite_demo`. MSSQL real pendente.
- [x] Módulo Syslog UDP disponível, ainda sem ligação ao fluxo de chamadas.
- [x] Contrato único `HBBRIDGE/1`, JSON e gzip, com constantes compartilhadas em `includes/hbbridge.h`.
- [x] Regressões Harbour de `Echo`, erros e rejeição de entradas fora do contrato do produto.
- [x] Análise do [brainstorming](docs/transports-sessions-security.pt-BR.md), sem integrar novos transportes nesta etapa.

**Características intermediárias do produto:** gzip obrigatório, materialização
integral do JSON, uma conexão por chamada e ausência de serviço de sistema.
Os tetos arbitrários de tamanho foram removidos; payload e bytes transmitidos
podem receber políticas opcionais, desativadas com `0`. Buffers, prazos e
concorrência são configuráveis, dentro das capacidades reais do runtime.
Bind/configuração e consulta administrativa evoluíram no marco 1.
O teste com dados repetidos não valida transferência
grande pouco compressível nem fragmentação no AppServer. As regressões Harbour
cobrem esse fluxo; a rodada TLPP de 2026-10-03 confirmou dois Echo de 200.000
bytes idênticos, com gzip de requisição de 152.964 bytes no caso variado. Essas restrições não definem o
produto final; páginas SQL estão implementadas, enquanto blocos de transporte
e negociação continuam pendentes.

## Sequência de entrega

1. Separar responsabilidades dos fontes, launcher de exemplo e regressões (marco 0).
2. Consolidar registro de serviços, NETIO nativo e configuração de rede (marco 1).
3. Consolidar o contrato do produto e corrigir a transferência; testar sua
   evolução nos serviços existentes (marco 2).
4. Entregar o próximo teste funcional, `RPCRDD.Query` com MSSQL e/ou SQLite,
   e integrar DBF via NETIO e arquivos VF IO (marco 3).
5. Ampliar módulos, contribs e ABI C/Zig conforme os casos de uso (marco 4).
6. Homologar serviço, administração, acesso e distribuição (marco 5).
7. Acrescentar jobs, lotes e processamento incremental conforme demanda (marco 6).

Um primeiro teste SQL pode usar o contrato atual do produto enquanto a
transferência incremental é desenvolvida.
Grandes volumes dependem do marco 2; DBF remoto depende do NETIO do marco 1.
ABI C/Zig e infraestrutura de serviço podem avançar junto com esses marcos.
A depuração com `hbdebug` começa em paralelo ao marco 0 e acompanha os serviços;
o desenvolvimento do HBDAP não bloqueia essa primeira entrega.

## Marco 0 — organizar produto, launcher de exemplo e regressões

A [estrutura atual](README.pt-BR.md#estrutura-atual) materializa a organização prevista.
A reorganização preservou o comportamento da revisão de referência; sua
validação histórica está registrada separadamente da evolução do produto.
O [registro da mudança](docs/reorganization.pt-BR.md) contém o mapa de
arquivos e a validação sobre a revisão de referência `b45595b`.

- [x] Corrigir o destino local da suíte Harbour para `127.0.0.1` e alinhar
  nomes/chamadas das fixtures HRB; automatizar o preparo sem skips na execução validada.
- [x] Registrar a revisão Git de referência e comparar as regressões
  antes/depois da reorganização, distinguindo correções do próprio teste.
- [x] Adotar `.hb` nos fontes Harbour próprios, `.tlpp` no Protheus e `.hrb`
  nos addons compilados; migrar referências atuais de fontes/build/docs,
  preservando nomes-base comuns, builds `.hbp` e suporte a addons `.prg`.
- [x] Classificar os fontes entre host, núcleo, transportes, serviços,
  carregamento de addons, telemetria e clientes.
- [x] Separar a entrada e o ciclo de vida do console em `src/hb/host/hbbridgemain.hb`;
  o mesmo host será ampliado para serviço no marco 5.
- [x] Mover o dispatcher existente para `src/hb/core/` e extrair handlers para
  `src/hb/services/`. Registro versionado e contexto nativo ficam no marco 1.
- [x] Isolar sockets/enquadramento em `src/hb/transports/protheus/`,
  preservando o comportamento daquela revisão na reorganização. A
  consolidação do contrato único pertence ao marco 2.
- [x] Reservar `src/hb/transports/netio/` com estado documentado; o listener
  nativo e sua integração ao núcleo permanecem no marco 1.
- [x] Preservar loader/telemetria em seus módulos e extrair a ponte C para
  `src/c/hbbridgezig.c`, mantendo a função Zig e o retorno do serviço `Health`.
- [x] Criar `examples/mvp/` como launcher do mesmo binário,
  referenciando addons e clientes compartilhados.
- [x] Migrar testes e fixtures para `tests/integration/harbour/`; reunir os
  testes Protheus em `src/tlpp/tests/protheus/` para compilar a árvore TLPP inteira;
  verificar `Health` e o addon Harbour de exemplo também na suíte Harbour.
- [x] Criar `tests/unit/` e `tests/contract/` com escopo e estado documentados.
- [x] Extrair testes dedicados de tipos/erros/registro para `tests/contract/`
  e criar unitários de configuração em `tests/unit/` no marco 1.
  O contrato do produto segue coberto na integração com os mesmos componentes.
- [x] Centralizar fontes/flags em `hbbridge.hbm`, compartilhado pelo produto e
  pelo projeto de testes; manter entradas separadas e uma implementação dos componentes.
- [x] Ajustar caminhos do build, testes, scripts e documentação; validar 72
  verificações da referência normalizada e 74 após a extração, sem falhas.
- [x] Reexecutar o teste TLPP real no AppServer após a reorganização, conforme
  homologação ; ambiente registrado na [matriz](docs/acceptance.pt-BR.md).
- [x] Recompilar e homologar classes TLPP renomeadas e seleção de perfil revisada:
  recompilação informada pelo operador após `.hb`; Query/Config/Connection/HTTP
  passaram em 2026-10-07. Os 16 checks de configuração foram verdadeiros às
  16:14:06, thread 30596; log real do compilador e hashes não fornecidos.

**Aceite estrutural atingido:** produto e exemplo compartilham implementação e
binário; a suíte Harbour e o build/CLI do produto foram validados. NETIO, serviço,
novo contrato e depuração não são entregues por essa movimentação. A homologação
TLPP da reorganização foi confirmada. As alterações funcionais do
marco 1 foram exercitadas no AppServer em 2026-10-03; resultado na [matriz](docs/acceptance.pt-BR.md).

## Depuração — frente transversal do produto

A [estratégia de depuração](README.pt-BR.md#depuração-hbdebug-primeiro-hbdap-como-evolução)
usa os mesmos fontes e serviços do produto. `hbdebug` existe no Harbour, mas
o build/loader atuais ainda não habilitam o perfil descrito abaixo.

### Etapa inicial — hbdebug nativo

- [ ] Criar perfil de desenvolvimento com `-b`, vinculação de `hbdebug` e
  terminal/GT adequado; documentar ativação, saída e localização dos fontes.
  Separar informações Harbour das informações nativas C/Zig (`-debug` no hbmk2).
- [ ] Aplicar a escolha de depuração também ao `hb_compileBuf` para `.prg`/`.hb`
  e ao preparo de `.hrb`, preservando identificação de módulo, fonte e linhas.
- [ ] Validar breakpoint e stepping em um handler Harbour e em um addon,
  com pilha, variáveis locais e retomada até a resposta RPC correta.
- [ ] Começar com requisição/worker controlado; definir propriedade do terminal
  e comportamento das demais threads durante uma pausa, antes de ampliar concorrência.
- [ ] Definir timeouts do perfil de depuração e comportamento de desconexão do
  cliente enquanto o worker está parado, sem repetir operações com efeitos.
- [ ] Testar carga/descarga de HRB, falha no addon, retomada e encerramento,
  verificando liberação de recursos e ausência de estado de debug obsoleto.
- [ ] Manter ativação explícita; validar execução normal e serviço sem interação
  obrigatória com o depurador, compartilhando fontes e composição do build.
- [ ] Documentar um roteiro reproduzível com `Echo` e um addon; registrar build,
  resultado e limitações. Vincular correlação RPC aos logs para investigar o TLPP
  no AppServer e a fronteira C/Zig com suas ferramentas próprias.

**Aceite inicial:** uma chamada a partir de Protheus ou cliente de teste Harbour
para em um breakpoint, permite inspecionar pilha/variáveis e retoma com resposta
correta. Handler e addon são exercitados; perfil normal continua sem UI de debug.

### Etapa futura — integração opcional ao HBDAP

Referências locais de desenvolvimento: projeto privado `F:\GitHub\hbdap`
e extensão Harbour DAP para VS Code em `F:\GitHub\hbdap-vscode-extension`.
Os itens abaixo tratam da integração no hbBridge; a existência de recursos no
HBDAP ou na extensão não os torna entregues ou homologados neste servidor.

- [ ] Fixar revisões Harbour/HBDAP, versão da extensão/VS Code, toolchain e
  requisitos dos hooks/patches do runtime; validar a base suportada do HBDAP
  antes do primeiro teste hbBridge.
- [ ] Integrar a bridge DAP de forma opcional, preservando o fluxo com `hbdebug`
  e configurando a localização da dependência sem caminhos de máquina fixos.
- [ ] Definir o modo de conexão suportado, canal separado e acesso local/controlado;
  isolar stdout/stderr/logs do framing DAP e limpar a sessão após desconexão.
- [ ] Validar breakpoints, continue, stepping, pilha e variáveis em um cliente DAP;
  anunciar somente as capacidades comprovadas na combinação runtime/adaptador.
- [ ] Documentar instalação da extensão Harbour DAP por VSIX e configuração
  `launch.json` com tipo `harbour-dap`, executável, diretório de trabalho e fontes;
  homologar os modos launch/attach escolhidos e o adaptador quando necessário.
  Preparar runtime/biblioteca/ferramentas separadamente do pacote da extensão.
- [ ] Validar a extensão instalada no VS Code contra o hbBridge real: breakpoint
  em handler e addon, pilha, variáveis, stepping, retomada e desconexão limpa.
  Reutilizar os cenários de integração DAP, com um subconjunto representativo no
  editor, distinguindo testes com protocolo simulado daqueles com runtime real.
- [ ] Homologar identidade de workers/threads, escopo de pausa/retomada e isolamento
  entre sessões antes de oferecer depuração concorrente. O HBDAP consultado ainda
  não garante suporte multithread/process; manter essa dependência explícita.
- [ ] Validar fontes e breakpoints de `.prg`/`.hb`/`.hrb` carregados dinamicamente,
  inclusive recarga, descarga e referências invalidadas durante a sessão.
- [ ] Repetir os cenários aceitos com `hbdebug` pela bridge DAP; testar attach no
  modo escolhido, perda do cliente de debug, término da chamada e parada do servidor.
- [ ] Documentar limites da depuração Harbour e o procedimento separado para
  código TLPP e C/Zig; não anunciar stepping unificado sem implementação própria.

**Aceite futuro:** sessão DAP reproduzível no hbBridge com handler e addon,
validada também pela extensão instalada no VS Code, com recursos liberados ao
desconectar e capacidades/limitações documentadas.
Depuração concorrente só será anunciada após suporte e testes dos workers.

## Marco 1 — núcleo extensível, NETIO e rede configurável

- [x] Registrar [matriz de referência](docs/acceptance.pt-BR.md): Harbour
  `3.2.1dev (r2608271822)`, Zig `0.16.0`, Windows x64 e AppServer `24.3.1.5`.
- [ ] Fixar o commit exato do runtime compilado e dependências para distribuição;
  homologar outras combinações AppServer/TLPP/plataforma antes de declará-las suportadas.
- [x] Separar handlers de negócio dos adaptadores de transporte. O núcleo
  recebe/devolve valores Harbour; cada adaptador cuida da representação.
- [x] Criar registro de serviços com nome, versão, assinatura, tipos, permissões,
  handler, dependências e modalidades de resultado; expor descoberta de capacidades.
- [x] Avaliar estaticamente `contrib/xhb/trpc.prg` e o cliente associado;
  registrar conclusões em [Harbour VF IO e TRPC](docs/harbour-vfio-trpc.pt-BR.md).
- [x] Aproveitar o modelo descrição/handler de `TRPCFunction` como referência
  do registro comum; implementar argumentos por chamada sem copiar o protocolo
  `XHBR` ou seu executor mutável. Ver [marco 1](docs/milestone1.pt-BR.md).
- [x] Adaptar nomes com namespaces, tipos, erros e permissões por canal;
  preservar argumentos por chamada. Autorização de usuário/tenant segue no marco 5.
- [x] Hospedar NETIO e adaptador Protheus no mesmo executável hbBridge,
  compartilhando núcleo/catálogo e isolando o estado de cada chamada.
- [x] Vincular `hbnetio` estaticamente na implantação inicial e integrar suas
  funções ao host, sem iniciar um segundo executável de servidor.
- [x] Reaproveitar padrões de configuração/administração do utilitário upstream,
  mantendo um único ponto de entrada e runtime Harbour. Serviço do sistema fica no marco 5.
- [x] Integrar as APIs de servidor/RPC do hbnetio e reaproveitar seu atendimento
  multithread, com configuração e ciclo de vida explícitos.
- [x] Adotar `_NETIOSRV_IPV4_DEF = "0.0.0.0"` e `_NETIOSRV_PORT_DEF = 2941`
  como padrões do listener nativo; permitir configuração de interface e porta.
- [x] Adotar `_NETIOMGM_IPV4_DEF = "127.0.0.1"` e `_NETIOMGM_PORT_DEF = 2940`
  para administração, habilitada com configuração/credencial própria.
- [x] Dar ao adaptador Protheus endpoint independente configurável, com padrão
  `0.0.0.0:1512` e opção de bind local; validar conflitos e configuração inválida.
- [x] Externalizar host/porta/timeout do cliente TLPP e do teste; clientes usam IP/DNS
  do servidor, nunca `0.0.0.0` como endereço de destino.
- [x] Documentar precedência padrões < INI/JSON < CLI, diretórios de dados/addons,
  timeout NETIO e concorrência por listener em [marco 1](docs/milestone1.pt-BR.md).
- [x] Carregar INI/JSON pelo mesmo esquema, procurar `hbbridge.ini` junto ao
  executável e oferecer `--config-info` sanitizado sem iniciar listeners.
- [x] Ler `[hbBridge]` do INI ativo do AppServer por classe estática com namespace;
  usar IP/porta/timeout, políticas de transferência e alias SQL como padrões
  do cliente e dos testes, com argumentos explícitos prioritários.
- [x] Homologar a nova configuração TLPP no AppServer: o operador confirmou
  `U_HBBridgeConfigTest` com 13 checks verdadeiros, relógio/RPC e
  `U_HBBridgeQueryTest` com 29 checks verdadeiros em 2026-10-04.
  A tentativa de compilação pelo agente ficou bloqueada na parada dos
  processos; o aceite posterior é da execução manual informada pelo operador.
- [x] Homologar a configuração revisada e as classes TLPP renomeadas em 2026-10-07
  após recompilação informada: 16 checks verdadeiros, incluindo explicitProfile,
  noForcedProfile e invalidProfile; regressões Query/relógio/RPC/HTTP passaram.
  Horários/threads fornecidos; log real do compilador, hashes, argumentos e
  destino efetivo não fornecidos. Veja [homologação](docs/acceptance.pt-BR.md).
- [ ] Registrar rodada com Host/Port/SQLProfile diferentes dos padrões e
  argumentos omitidos, identificando o artefato e a configuração utilizados.
- [x] Tornar payload/rede, buffer e prazo Protheus políticas explícitas da
  instalação; usar `0` para desativar tetos do aplicativo ou prazo do servidor.
- [ ] Definir orçamento operacional de memória e negociar capacidades de transferência
  no marco 2, respeitando os limites reais de cada cliente.
- [x] Habilitar `-prgflag=-DHB_EXTERN` e `REQUEST __HB_EXTERN__` no executável
  que hospeda o RPC; disponibilizar explicitamente as contribs adicionais.
- [x] Definir filtro RPC explícito: `HBBridge.Call` e, no admin,
  `HBBridge.Admin.Status`; vinculação de símbolos não autoriza todas as funções.
- [ ] Validar as variantes upstream `-rpc`/`-rpc=<módulo>` como referência
  adicional; o host hbBridge usa registro/ADDON.Execute e não expõe esses flags.
- [x] Criar cliente Harbour de integração usando NETIO, com chamada ao core
  e aos mesmos serviços acessíveis ao Protheus.
- [x] Aproveitar a serialização nativa de argumentos/resultados do NETIO;
  homologar `hb_Serialize`/`hb_Deserialize` quando um serviço usa blocos serializados.
- [x] Definir e testar tipos nativos `U/C/L/N/D/T/A/H`, bytes binários e hashes
  com chaves string; recusar ciclos, objetos, codeblocks e ponteiros vivos.
- [ ] Homologar codepages e compatibilidade de serialização entre revisões
  distintas; implementar identificadores de serviço para recursos de sessão.
- [x] Recompilar `src/tlpp/` e homologar Health, Echo e ADDON do marco 1
  no AppServer : 3 fontes compilados sem erros e teste
  real com sucesso, confirmado pelos logs em 2026-10-03.
  Classes renomeadas e perfil revisado aceitos pelo operador na regressão de
  2026-10-07 após recompilação informada.

**Aceite:** cliente Harbour remoto conecta-se ao listener NETIO em 2941 e
executa um serviço registrado e uma função do core. O Protheus continua
executando `Health`, `Echo` e addons pelo adaptador. Interfaces e portas são
configuráveis; administração usa canal separado. Os protocolos permanecem
interoperáveis com seus respectivos clientes.

## Marco 2 — contrato, grandes volumes e compressão negociada

**Em andamento.** A [primeira entrega](docs/milestone2-framing.pt-BR.md) corrige o TCP
do produto e consolida `HBBRIDGE/1`, JSON e gzip. Os testes exercitam a
implementação real; provas de conceito anteriores ficam no histórico Git.
Handshake, persistência, transferência em blocos e compressão negociada
continuam pendentes.

- [x] Padronizar fontes Harbour próprios com quatro espaços e registrar o padrão no `.editorconfig`.
- [x] Receber e emitir gzip incrementalmente no Harbour, validando CRC/final,
  capacidade real do runtime e políticas opcionais durante a expansão/envio.
- [x] Consolidar `HBBRIDGE/1` e `ADDON.Execute`; rejeitar formatos e nomes fora do contrato registrado.
- [x] Compartilhar as constantes do contrato por `includes/hbbridge.h` entre servidor, cliente e testes.
- [x] Rejeitar cabeçalhos inválidos, truncamento e divergência no comprimento do corpo.
- [x] Usar comprimento decimal canônico comparado ao corpo efetivo; derivar a
  capacidade do cabeçalho da estrutura e dos dígitos do runtime.
- [x] Remover tetos fixos de payload/rede, oito dígitos de tamanho e cabeçalho de 128 bytes.
- [x] Expor `HBBridgeRuntimeLimits()` com `stringBytesMax`, `socketChunkBytesMax`,
  `zlibChunkBytesMax` e `netioTimeoutMsMax`; validar opções contra as capacidades
  reais da API C e dimensionar o buffer pelo menor limite entre socket e codec.
- [x] Configurar `protheusMaxPayloadBytes`/`protheusMaxWireBytes` com padrão `0`,
  `protheusReadChunkBytes = 65536` e `protheusTimeoutMs = 30000`; `0` desativa
  o prazo no servidor Harbour. Expor opções JSON e CLI.
- [x] Usar `netioTimeout = 0` como padrão, mapeando-o para `-1` nativo;
  preservar `maxWorkers = 64` como configuração operacional.
- [x] Ampliar regressões Harbour com gzip maior que 65.535 bytes e fragmentação do header/trailer.
- [x] Validar Echo com 24.000.000 bytes exatos, JSON/gzip maior que 16 MiB,
  políticas positivas/zero e compressor incremental: 305 verificações, zero falhas.
- [x] Ajustar o código TLPP para envio parcial, gzip completo e erros estruturados.
- [x] Preparar Echo TLPP com comparação integral e fixture pouco compressível.
- [x] Externalizar políticas opcionais e buffer no construtor TLPP; manter os
  três primeiros argumentos e prazo positivo padrão de 30 segundos.
- [x] Calcular o prazo TLPP com `TimeCounter()`, sem `Date()`/`Seconds()` nem teto
  artificial de um dia; expirar o orçamento se o contador regredir.
- [x] Usar relógio monotônico nos prazos e no uptime Harbour, substituindo
  `hb_MilliSeconds()`, que depende de hora civil UTC.
- [x] Adaptar `dna.tech.StopWatch.__GetCurrentTimeStamp()` nos métodos estáticos
  de `HBBridge.Client.HBBridgeTime`, em `src/tlpp/hbbridgetime.tlpp`, e preparar teste
  de escala/espera e aritmética do prazo no AppServer.
- [x] Organizar utilitários TLPP compartilhados em classes com namespace,
  usando métodos estáticos; preservar a entrada `U_HBBridgeConnectionTest`
  e registrar a convenção em `AGENTS.md`, sem funções públicas comuns para APIs.
- [x] Registrar a diferença de unidades reproduzida na
  [issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12)
  como fundamento da normalização Unix × 1000.
- [x] Homologar escala/avanço do `TimeCounter()` no Windows: `Unix=false`,
  delta bruto `1097.692700`, normalizado `1097.773500` ms após `Sleep(1000)`;
  teste de relógio `OK` informado pelo operador em 2026-10-04.
  Reconfirmado em 2026-10-07 às 16:14:31, thread 27084: delta bruto
  `1089.987500`, normalizado `1090.088100 ms`, `OK`; Health/ADDON e os dois
  Echo exatos de 200.000 bytes também passaram, com gzip de 152.964 bytes.
- [ ] Homologar `TimeCounter()` no Linux e ampliar precisão, ajustes de relógio
  e wrap no build alvo; detectar alterações de unidade
  no build alvo para manter o contorno compatível com futuras correções.
- [x] Homologar manualmente Health, ADDON.Execute e dois Echo no AppServer:
  conteúdo integral de 200.000 bytes, gzip de requisição de 152.964 bytes e
  conclusão normal das chamadas, confirmados pelo operador em 2026-10-03.
- [ ] Homologar timeout/falhas de socket e envio parcial positivo forçado no
  TLPP; registrar o artefato exato do servidor. Os valores do teste de relógio
  Windows já foram informados e registrados.

### Contrato de serviços e versões

- [ ] Versionar protocolo e serviços separadamente, com descoberta e tratamento
  de versões/capacidades não suportadas.
- [ ] Especificar handshake pequeno e sem compressão para a evolução do adaptador TLPP;
  no NETIO, consultar capacidades via RPC após a conexão nativa.
- [ ] Negociar codecs, compressão, tamanho transmitido/expandido por bloco e
  suporte a páginas/streams, considerando a capacidade nos dois sentidos.
- [ ] Mapear configuração efetiva/build do AppServer e `MAXSTRINGSIZE` para um
  perfil de cliente; definir configuração explícita quando não houver descoberta.
- [ ] Definir identificador da chamada, serviço/versão, parâmetros, contexto,
  prazo, resultado, metadados e erro estruturado com código/origem.
- [ ] Especificar nulo versus vazio, inteiros, decimal/moeda sem perda de precisão,
  datas/timestamps/fuso, texto, binários, arrays/hashes e tipos nativos adicionais.
- [ ] Definir encoding e contagem de bytes, incluindo Unicode, zeros em binários
  e expansão de JSON/base64; homologar APIs TLPP usadas para cada representação.
- [ ] Definir por versão os retornos de `Health`, `Echo`, `ADDON.Execute` e
  `header`/`rows` esperados por `HBBridgeRPCDataSet`, com testes do contrato do produto.
- [ ] Definir prazos, cancelamento cooperativo, idempotência e política de nova
  tentativa. Não repetir automaticamente operações com efeitos após desconexão.

### Conexões persistentes, pool e sessão

- [ ] Implementar primeiro o enquadramento incremental da seção seguinte;
  persistência será uma capacidade negociada do contrato do produto.
- [ ] Manter socket aberto no cliente TLPP e loop de requisições no servidor,
  começando com uma chamada em andamento por conexão e fechamento explícito.
- [ ] Definir prazos de conexão, leitura, escrita, chamada e ociosidade; tornar
  keepalive configurável e medir `TCP_NODELAY` com as APIs nativas Harbour.
- [ ] Validar heartbeat quando necessário, sem confundir conexão TCP viva com
  aplicação responsiva; limitar conexões ociosas e ocupação de workers.
- [ ] Implementar pool limitado por endpoint, perfil TLS e identidade/sessão,
  com empréstimo exclusivo, fila limitada e expurgo; validar ciclo de vida por
  job/thread TLPP antes de compartilhar objetos de socket entre execuções.
- [ ] Reconectar com backoff e jitter; separar reconexão de reenvio, tratando
  resultado desconhecido, idempotência e prazo total da chamada.
- [ ] Definir contexto imutável por chamada: correlação, identidade verificada,
  contexto opaco explícito autorizado e prazo. Protheus resolve empresa/filial
  e regras ERP; metadados do cliente não concedem acesso.
- [ ] Garantir limpeza em sucesso/erro/cancelamento: áreas de trabalho, opções
  SET, transações e buffers; testar STATIC/PUBLIC/PRIVATE e drivers sob concorrência.
- [ ] Manter registro de recursos por sessão/usuário/tenant com TTL, proprietário,
  fechamento explícito e proteção contra uso por outra sessão.
- [ ] Definir desconexão por perfil: liberar recursos transitórios por padrão;
  retomada exige autenticação, prazo, revalidação e encaminhamento ao proprietário.
  Não prometer migração de handles/transações nem durabilidade sem armazenamento.
- [ ] Avaliar multiplexação somente após persistência/pool: IDs por chamada,
  leitor único, demultiplexação, escrita coordenada, cancelamento e backpressure.
- [ ] Testar chamadas sucessivas, frames coalescidos/fragmentados, consumidor lento,
  token expirado, queda de rede e interrupção do AppServer; medir memória, workers,
  sockets, latência e isolamento entre tenants.

**Aceite incremental:** várias chamadas sequenciais usam uma conexão; o pool
respeita seu limite; falhas não repetem escritas nem vazam recursos/contexto.
Multiplexação e retomada permanecem indisponíveis até seus testes específicos.

### Enquadramento e consumo incremental

- [ ] Especificar a evolução dos bytes do frame externo: versão, codec, compressão,
  identificação da chamada/stream, sequência/final e comprimentos transmitido
  e expandido, validados antes de alocar ou descomprimir.
- [ ] Tratar TCP como fluxo: cabeçalhos/corpos parciais, mensagens coalescidas,
  envio parcial, EOF, truncamento, timeout e reconexão.
- [x] Corrigir no código o envio TLPP e substituir a descompressão de cada `Receive`
  pela leitura da unidade completa. Verificar retornos de socket e compressão;
  o aceite do fluxo normal e do Echo pouco compressível foi confirmado no
  AppServer em 2026-10-03; os cenários de falha/timeout continuam pendentes.
- [ ] Evoluir o enquadramento `HBBRIDGE/1`, distinguindo comprimento JSON
  descomprimido, comprimento transmitido e identificação/versionamento do bloco.
- [x] Remover o teto fixo de 16 MiB; permitir políticas opcionais explícitas,
  mantendo as capacidades técnicas do runtime e das APIs.
- [ ] Negociar limites por bloco/conexão e capacidades nos dois sentidos,
  respeitando `MAXSTRINGSIZE`, campos de protocolo e orçamento de memória.
- [ ] Inventariar limites de runtime, arquitetura, campos dos protocolos e APIs
  Harbour/NETIO/TLPP/conectores; evitar promessas de tamanhos infinitos.
- [x] Documentar limites NETIO presentes nos fontes examinados: senha de 64 bytes,
  8.192 arquivos abertos por conexão e comprimentos `uint32` em determinadas
  unidades RPC/streams; distinguir essas unidades do contrato Protheus.
- [ ] Diferenciar volume lógico total, limite por valor/mensagem e orçamento
  operacional de memória, incluindo cópias e expansão durante a descompressão.
- [ ] Implementar fluxo em blocos/páginas sem remontagem integral, com controle
  do ritmo do produtor e quantidade de blocos em trânsito.
- [ ] Tratar campos individuais grandes/BLOBs por stream ou identificador remoto;
  um dataset paginado ainda pode conter uma coluna maior que `MAXSTRINGSIZE`.
- [ ] Avaliar streams NETIO de dados/itens, fechamento, buffering e ritmo de
  consumo; manter essas APIs nativas no caminho Harbour.
- [ ] Definir propriedade, expiração, cancelamento e limpeza de recursos em
  desconexão. Retomada só será anunciada para serviços que a implementem.

### Compressão e validação

- [ ] Implementar `none` e `gzip` negociados no adaptador Protheus; cada bloco
  comprimido será uma unidade independente compatível com as APIs de strings.
- [ ] Medir tamanho mínimo e ganho necessários para política automática;
  comparar custo de CPU, latência e bytes em rede local/remota.
- [ ] Validar dados vazios, incompressíveis e já comprimidos; tratar falhas de
  `GzStrComp`/`GzStrDecomp`, além das funções Harbour correspondentes.
- [ ] Homologar amostras binárias gzip nos dois sentidos, diferenciando o formato
  no fio de zlib/DEFLATE e fixando os identificadores de codec/compressão.
- [ ] Verificar limitação da expansão durante a descompressão, não apenas o
  tamanho anunciado ou uma checagem após a alocação. Para APIs sem esse controle,
  definir uso de blocos confiáveis ou modo `none` conforme o perfil de conexão.
- [ ] Usar configuração nativa de compressão NETIO; medir separadamente
  `HB_SERIALIZE_COMPRESS` e evitar compressão redundante das mesmas informações.
- [ ] Testar ambos os clientes com dados íntegros, pequenos/grandes, Unicode,
  binários, fragmentação, coalescência, falhas e versões incompatíveis.

**Aceite:** ambos os perfis acessam serviços com tipos/erros consistentes.
O adaptador evoluído funciona com e sem gzip e transfere volume lógico total
maior que o limite de uma string do perfil Protheus homologado, consumindo
blocos sem ultrapassar os limites por valor e o orçamento de memória medido.
O consumidor lento, a descompressão inválida e a desconexão têm comportamento
testado; somente versões e capacidades efetivamente implementadas são anunciadas.

## Marco 3 — MSSQL, SQLite, DBF e Harbour VF IO

### RPCRDD.Query — primeira entrega e homologação

- [x] Escolher SQLite para a primeira regressão real, mantendo MSSQL/ODBC como
  segundo backend. Dependências e resultados em `docs/milestone3-sql.pt-BR.md`.
- [x] Habilitar `rddsql`/`SQLMIX` com `sddodbc` para MSSQL e `sddsqlt3` para SQLite.
- [ ] Homologar conexão/consulta/paginação com MSSQL real e registrar driver,
  DSN, versão do servidor e bibliotecas cliente.
- [ ] Avaliar `hbodbc`/`hbsqlit3` quando a operação exigir a API direta.
- [x] Implementar `RPCRDD.Query` no registro/dispatcher, com perfil lógico,
  `alias`, `sql`, metadados e retorno por chave com contagem/versão explícitas.
- [x] Atualizar exemplos de perfis para MSSQL/SQLite, mantendo credenciais no
  servidor; arquivos JSON/INI não implementam criptografia nesta etapa.
- [x] Implementar `HBBridgeRPCDataSet` com JSONObject e `U_HBBridgeQueryTest`, incluindo
  páginas explícitas, erros, EOF e fechamento; fontes sob `src/tlpp/`.
- [x] Preparar `examples/sql/run.ps1` com perfil SQLite padrão, configuração/
  perfil alternativos e instruções Protheus; reaproveitar o launcher comum
  `scripts/run-hbbridge.ps1` também no exemplo mínimo.
- [x] Homologar SQLite no Protheus com `HBBridgeRPCDataSet`: leitura por nome,
  decimal, vazio, consulta/perfil inválidos, recuperação, páginas, EOF e
  fechamento; 29 checks verdadeiros em 2026-10-04 às 00:40:06, reconfirmados
  em 2026-10-07 às 16:13:33, thread 27136, profile=sqlite_demo.
- [ ] Homologar conexão SQL indisponível, tipos/nulos ampliados e volume real
  no AppServer; perfil desconhecido não comprova falha do conector.
- [x] Integrar regressões com SQLite em arquivo, chamadas concorrentes e o
  mesmo serviço por cliente Harbour NETIO e TCP/JSON.
- [x] Registrar o aceite SQLite Protheus informado pelo operador, distinguindo-o
  da regressão Harbour. Aceite MSSQL continua pendente.

### Evolução do acesso a dados

- [ ] Adicionar parâmetros SQL e metadados de tipo, tamanho, precisão e nulos,
  com evolução compatível do cabeçalho atual.
- [x] Implementar páginas no SGBD com `ROW_NUMBER`/`BETWEEN`, linha extra para
  `hasNext`, ordem explícita e `OpenPage`/`NextPage` no TLPP; sem teto de MVP.
- [ ] Evoluir paginação por chave/cursores, snapshot, prazo, fechamento/expiração
  e campos grandes; homologar consumo incremental e estabilidade sob escritas.
- [ ] Medir materialização/cache do conector/RDD desde a consulta; paginação da
  resposta não garante que o servidor deixou de carregar todas as linhas.
- [ ] Definir transações por sessão/operação, commit/rollback e comportamento
  na falha/desconexão; isolar conexões e áreas de trabalho entre chamadas.
- [ ] Avaliar reutilização de conexões, concorrência e processamento em lote
  com as APIs existentes, preservando o ciclo de vida dos recursos.
- [ ] Ampliar homologação para PostgreSQL (`sddpg`/`hbpgsql`) e MySQL/MariaDB
  (`sddmy`), registrando diferenças dos conectores e bibliotecas cliente.

### DBF e arquivos nativos

- [ ] Habilitar diretório raiz e acesso `net:` para RDDs nativos no cliente Harbour.
- [ ] Homologar DBF, índices e memos: abrir, ler, navegar, localizar, escrever,
  bloquear/desbloquear e fechar, incluindo acesso concorrente e desconexão.
- [ ] Definir serviços equivalentes para o cliente TLPP, com identificadores
  remotos de áreas/cursores, autorização e limpeza ao encerrar a sessão.
- [ ] Manter explícita a distinção entre acesso DBF por RDD/NETIO e consultas SQL
  de `RPCRDD.Query`; compartilhar representação de dados onde fizer sentido.

### Arquivos locais/remotos com hb_vf*

- [ ] Usar a Harbour VF IO API para abertura/fechamento, leitura/escrita,
  acesso por offset, tamanho, diretórios e metadados, conforme o provedor.
- [ ] Homologar inicialmente arquivos locais e `net:`; configurar/registrar
  NETIO e anunciar apenas capacidades verificadas por backend.
- [ ] Definir a família `Files.*` para TLPP no catálogo comum, com perfis de
  armazenamento, caminhos permitidos, parâmetros e erros versionados.
- [ ] Mapear identificadores opacos por sessão para handles VF; implementar
  fechamento, expiração e limpeza na desconexão, sem serializar ponteiros.
- [ ] Manter `hb_vfHandle` e opções de configuração que exponham descritores
  internos fora da fachada RPC; selecionar explicitamente operações/opções remotas.
- [ ] Tratar contagem efetiva, EOF, `FError()`, operações parciais e offsets
  sem perda de precisão nos dois clientes e na ponte C/Zig.
- [ ] Integrar blocos negociados e evitar carregar arquivos inteiros por
  `hb_vfLoad`/`hb_vfSave` fora do orçamento de memória.
- [ ] Homologar seek, truncamento, flush/commit e locks de bytes por backend;
  preservar a gestão de registros/índices/bloqueios DBF pelos RDDs.
- [ ] Testar cópia/renomeação entre provedores e reportar operações não suportadas,
  sem presumir atomicidade ou equivalência de semântica entre backends.
- [ ] Validar round-trip binário local/NETIO em Harbour e Protheus, incluindo
  conteúdo vazio, volume grande, offset, permissão negada e desconexão.

**Aceite inicial:** Protheus e Harbour consultam o primeiro SGBD homologado,
com tipos, erros e fechamento verificados. **Aceite de evolução:** dataset
incremental e campo grande respeitam memória/limites do marco 2; cliente
Harbour acessa DBF via NETIO e Protheus usa a fachada correspondente, incluindo
validação de índices, bloqueios e isolamento. A fachada VF transfere arquivos
locais/remotos em blocos, com integridade binária, erros e liberação verificados.

## Marco 4 — módulos, contribs e extensões C/Zig

### Apresentação nativa e resultados compartilhados

- [ ] Adaptador TLPP de schema explícito/dataset paginado para FWTemporaryTable
  do cliente e browse nativo, preservando tipos/nulos e liberando recursos.
- [ ] Contrato separado RPCRDD.Materialize/Release para staging MSSQL confirmado:
  perfis/schema explícitos, handle opaco/posse/lease, metadados, publicação
  atômica, expiração/limpeza após crash e cancelamento real no conector.
  Tabela temporária SQL local e SQLite :memory: não atravessam conexões por si.
  Veja o [desenho de resultados](docs/evolution.pt-BR.md#tabelas-para-apresentação-nativa-no-protheus).

### Execução de módulos e extensões nativas

- [x] Verificar isolamento THREAD STATIC por thread, inclusive com HRB
  compartilhado, e conservação de valores em chamadas/recargas no mesmo
  worker. Estado de requisição explícito; mutexes globais compartilhados.

Esta frente evolui com os serviços. A integração C/Zig existente é preservada;
novas extensões entram conforme a necessidade e os resultados medidos.

- [x] Integrar `ADDON.Execute` ao registro comum para Protheus e Harbour,
  com parâmetros `module` e `params`.
- [ ] Evoluir a identificação de módulos de caminho de arquivo para nome/versão
  registrado, com contrato e testes próprios.
- [ ] Reutilizar compilação `.prg`/`.hb` e execução `.hrb`; validar
  `HBNETIOSRV_RPCMAIN` nos módulos usados no modo `-rpc=<arquivo>` do hbnetio.
- [ ] Definir metadados de módulos, dependências, tipos, permissões e erros;
  permitir consumo pelos dois perfis de cliente.
- [ ] Configurar diretórios permitidos e canonicalização, publicação e política
  de confiança; preservar isolamento de símbolos/estáticos entre HRBs ativos
  simultaneamente. Recarga nativa pode conservar valores STATIC.
- [ ] Definir cache, descarregamento e atualização sem invalidar chamadas ativas;
  avaliar isolamento por processo quando exigido pelo módulo.
- [ ] Documentar separadamente Zig como toolchain e como linguagem das extensões.
- [ ] Formalizar ABI C versionada: ponteiro + tamanho, propriedade/liberação,
  erros, alinhamento, concorrência e ciclo de vida dos resultados.
- [ ] Manter bibliotecas vinculadas no build inicial. Avaliar DLL apenas quando
  atualização independente justificar ABI e ciclo de carga próprios, evitando
  duplicação incompatível do runtime Harbour; processo separado exige caso de isolamento.
- [ ] Evoluir o adaptador demonstrativo de string terminada em zero para suportar
  binários e buffers grandes, integrando resultados ao contrato de streams.
- [ ] Definir acesso à VM Harbour a partir de código nativo e evitar compartilhar
  recursos de uma chamada sem regras de sincronização e propriedade.
- [ ] Integrar buffers VF IO ou `hb_file*` à ponte C/Zig quando necessário,
  com propriedade e ciclo de vida explícitos dos arquivos e resultados.
- [ ] Homologar a primeira extensão C/Zig funcional além do diagnóstico `Health`,
  com caso concreto, medição e testes dos dois clientes.
- [ ] Selecionar serviços adicionais sobre contribs existentes: HTTP/APIs com
  `hbcurl`, XML com `hbexpat`, arquivos/ZIP e transformações de dados.
- [ ] Anunciar no catálogo somente componentes habilitados e homologados;
  retornar erro de capacidade indisponível para dependências ausentes.

**Aceite:** novo addon ou serviço de contrib e uma extensão C/Zig acessíveis
por Protheus e Harbour, com contrato versionado, buffers/erros testados e
disponibilidade consultável, sem alterar os transportes para cada extensão.

## Marco 5 — serviço, administração e operação

### HTTP/REST e administração web

- [x] Cliente/exemplo HTTP TLPP com INI ativo do AppServer, FWRest nativo,
  GET/POST/bearer, erros JSON e dataset SQL existente. Operador homologou os
  13 checks em 2026-10-07, inicialmente thread 25672; reconfirmados nas threads
  27296 (16:10:44–16:10:45) e 25456 (16:15:03–16:15:04), cada uma em um segundo,
  horário de São Paulo. Backend SQL HTTP não identificado.
  Veja o [exemplo](examples/http/README.pt-BR.md).
- [ ] Ampliar aceite HTTP TLPP para configuração alternativa, falhas de transporte,
  Unicode variado/maior, outras LIBs, HTTPS e backends SQL identificados.

- [x] Adaptador opcional `hbhttpd` chama os mesmos serviços registrados que
  NETIO e Protheus. Credenciais HTTP e permissões administrativas separadas;
  desativado por padrão, bind/porta configuráveis, sem senha padrão.
- [x] Patch gerenciado sobre revisão fixada do `hbhttpd` expõe o corpo JSON
  e torna configurável a quantidade de workers nativos. Usar `hbtcpio`;
  `-hblib` é o modo de gerar biblioteca, não uma dependência separada.
- [x] GET de saúde/catálogo, POST JSON de serviços e status web autenticado,
  somente leitura, para hbBridge e seus endpoints NETIO incorporados.
- [x] Validar inicialização/rollback HTTP, separação de autenticação, JSON/SQL/
  addons, chamadas concorrentes, parada/reinício e regressões TCP/NETIO.
- [ ] HTTPS direto com `hbssl`/OpenSSL: resolução reproduzível de SDK/runtime,
  certificados/nome/cadeia/renovação e política TLS em Windows/Linux.
  HTTP atrás de proxy TLS é configuração de implantação distinta.
- [ ] Ampliar verbos/rotas REST, contrato OpenAPI, negociação de conteúdo/
  compressão e interoperabilidade; serviços genéricos recebem contexto explícito.
- [ ] Avaliar adaptador HTTP compatível com Zig 0.16 contra lacunas medidas do
  hbhttpd; preservar núcleo/contratos e definir ABI C/posse de threads VM.
  Comparar conformidade, recursos, ciclo de vida e homologação Windows/Linux.
- [ ] Políticas HTTP configuráveis de admissão para fila de sockets aceitos,
  recursos de cabeçalho/corpo e prazos. Workers não limitam a fila; o parser
  nativo lê o corpo antes da autenticação do adaptador.
- [ ] Ampliar a administração web além do status: sessões/recursos NETIO,
  métricas, gestão de configuração/credenciais e ações privilegiadas com
  autorização/auditoria, reutilizando o núcleo operacional no mesmo processo.

### Serviço, segurança e implantação

Configuração e acesso orientam os marcos anteriores. Esta etapa reúne a
homologação operacional do conjunto.

- [ ] Integrar execução como serviço Windows com a base `hbwin` usada pelo hbnetio;
  definir nome próprio, instalação, desinstalação e inicialização automática.
- [ ] Garantir console/serviço com a mesma configuração, sem entrada interativa
  obrigatória e com caminhos independentes do diretório de trabalho.
- [ ] Publicar modo supervisionado para Linux, com sinais, inicialização,
  recuperação e procedimento de instalação documentados.
- [ ] Implementar parada controlada: parar admissões, aguardar/delimitar chamadas,
  coordenar listeners NETIO/Protheus/administração, cancelar cooperativamente e
  liberar conexões, cursores, streams e módulos.
- [ ] Integrar administração NETIO, status e diagnóstico; manter credenciais,
  interface e permissões separadas das chamadas de aplicação.
- [ ] Definir autenticação, autorização por serviço/perfil e acesso a arquivos,
  aproveitando os filtros nativos; separar funções do core vinculadas e expostas.
- [ ] Prototipar `TSSLClient` (AppServer 19.3.1.0+ documentado) com `hbssl`/OpenSSL
  no listener Protheus; homologar build real, `SSLConfigure`, certificados,
  cadeia de confiança, nome do servidor, prazos e renovação. Falha não rebaixa para TCP aberto.
- [ ] Fixar versões TLS aceitas no perfil de produção; validar mTLS se exigido,
  sem copiar habilitação de SSL antigo dos exemplos históricos.
- [ ] Definir proteção separada para NETIO/administração conforme capacidades
  comprovadas; não presumir que a integração TLS Protheus protege os outros canais.
- [ ] Integrar JWT opcional ao contexto comum usando biblioteca existente:
  algoritmo permitido, assinatura, emissor, audiência, expiração, `nbf`, chaves
  confiáveis e rotação; validar interoperabilidade com `tJWT` (17.3.0.19+ documentado).
- [ ] Definir emissão/renovação de credenciais, autorização por serviço/tenant e
  revalidação em conexões persistentes; proibir tokens e segredos nos logs.
- [ ] Testar assinatura/chave inválida, audiência errada, expiração, tenant não
  autorizado e certificado inválido. JWT assinado exige transporte protegido;
  decodificar claims não equivale a autenticar a chamada.
- [ ] Definir armazenamento de perfis/segredos, usando bibliotecas existentes
  quando houver criptografia em repouso e chaves externas ao repositório.
- [ ] Desenho do pacote 003: provedor comum de credenciais no servidor com
  OpenBao KV v2/AppRole ou Agent/Proxy opcionais, referências configuradas
  autorizadas, validação de bootstrap/CA, cache/renovação de token/sanitização
  e aceite de ABI/memória Zig 0.16. Guardar credenciais SQL estáveis e permitir
  atualização manual; rotação automática de senha SQL/plugins dinâmicos de
  banco ficam fora deste escopo inicial. Renovar token do cofre ou substituir
  chave de criptografia não muda a senha SQL. Veja a
  [análise de credenciais](docs/credentials.pt-BR.md). Nenhum serviço implementado;
  essa frente futura não é pré-requisito do pacote MSSQL 001.
- [ ] Tornar concorrência, timeouts, filas e memória configuráveis; validar
  compatibilidade com threads das rotinas, drivers e extensões escolhidos.
- [ ] Conectar Syslog ao ciclo do servidor e às chamadas, preservando operação
  quando o coletor estiver indisponível e excluindo credenciais dos logs.
- [ ] Registrar correlação, latência, erros, bytes transmitidos/expandidos,
  memória e recursos ativos; distinguir vida do processo e prontidão dos serviços.
- [ ] Automatizar build e regressões `Health`/`Echo`/`ADDON.Execute`, NETIO, SQL, DBF,
  binários, limites negociados, concorrência e falhas de rede/módulo/driver.
- [ ] Homologar instalação, inicialização após reinício, parada e recuperação
  do serviço em Windows e Linux, incluindo porta ocupada e configuração inválida.
- [ ] Criar empacotamento reproduzível com dependências e versões explícitas;
  atualizar `docs/`, `tests/` e scripts conforme cada comportamento for entregue.
- [ ] Documentar instalação, diagnóstico, atualização e recuperação.
- [x] Comparar os termos oficiais Harbour/Zig e registrar a
  [proposta de licenciamento](docs/licensing.pt-BR.md), distinguindo bibliotecas
  com exceção de vinculação, utilitários GPL e código autoral.
- [ ] Esclarecer a procedência de `FileSig`/carregamento de addons em relação
  ao utilitário `hbnetio.prg`, e da adaptação de `dna.tech.StopWatch` no TLPP;
  preservar os avisos e obter permissões aplicáveis antes da padronização.
- [ ] Definir a licença do código autoral e confirmar titulares; criar `LICENSE`,
  avisos de terceiros e SPDX correspondentes, preservando os termos existentes.
- [ ] Incluir no pacote as licenças/avisos e obrigações dos componentes
  efetivamente distribuídos, com versões/origens registradas.

**Aceite:** instalação como serviço reproduzível, conexão remota com os binds
documentados, administração separada, parada/recuperação testadas e recursos
liberados. Testes, métricas e instruções permitem verificar o ambiente instalado.

## Marco 6 — jobs, lotes e processamento incremental

Depende do registro de serviços e do ciclo de vida de recursos dos marcos 1–2.
O processamento usa Harbour/contribs e extensões C/Zig conforme cada tarefa.

- [ ] Definir contratos para submeter, consultar progresso/estado, obter resultado
  e cancelar jobs; estabelecer propriedade por sessão/usuário e expiração.
- [ ] Definir fila, concorrência e orçamento de recursos, com controle do ritmo
  de produção; documentar se resultados sobrevivem a reinício e por quanto tempo.
- [ ] Mapear progresso/resultados para streams NETIO e consumo incremental TLPP,
  sem bloquear o cliente durante toda a execução.
- [ ] Adaptar os modelos de callbacks, loop/foreach e cancelamento encontrados
  no TRPC, preservando o contrato hbBridge e seus limites negociados.
- [ ] Testar cancelamento concorrente com progresso/resultado e revisar o indício
  de conflito de mensagens no par TRPC antes de reutilizar qualquer trecho desse fluxo.
- [ ] Separar desconexão de cancelamento e definir idempotência na submissão;
  cancelamento cooperativo não promete interromper qualquer chamada nativa.
- [ ] Definir chamadas em lote com resultados/erros por item e limites negociados;
  atomicidade/transação será uma capacidade explícita do serviço.
- [ ] Demonstrar importação/exportação ou transformação de grande volume feita
  no servidor, com páginas/blocos e devolução somente do resultado necessário.

**Aceite:** Protheus e Harbour acompanham uma operação longa, recebem seu
resultado incrementalmente e exercitam cancelamento/falha com limpeza e consumo
de recursos medidos. Durabilidade e retomada só são anunciadas se implementadas.

### AMQP opcional para jobs e eventos

- [ ] Prototipar `tAMQP` ↔ RabbitMQ ↔ consumidor hbBridge com AMQP 0.9.1,
  adaptando mensagens ao mesmo registro/contexto de serviços.
- [ ] Registrar build TOTVS e biblioteca C/integração ABI C/Zig homologados;
  confirmar TLS, virtual hosts, publisher confirms e rejeição/requeue disponíveis.
  O parâmetro vhost da classe TOTVS é documentado a partir de 24.3.0.6.
- [ ] Definir correlação, ReplyTo, prazos, tamanho de mensagem e referências a
  resultados grandes; limitar prefetch/concorrência e autorizar destinos de resposta.
- [ ] Definir filas duráveis, mensagens persistentes, confirmação de publicação
  e ack após resultado persistido; admitir redelivery com deduplicação/idempotência.
- [ ] Testar queda do produtor/worker/broker, mensagens duplicadas, retries limitados
  e fila de falhas; documentar capacidades ausentes na API TLPP sem prometer exactly-once.

**Aceite opcional:** job atravessa falha/reentrega sem duplicar seu efeito segundo
o contrato de idempotência; instalação sem AMQP continua funcional sem broker.

## Investigações condicionadas — gRPC e transporte Zig

Estas provas de conceito não bloqueiam os marcos principais. A avaliação está em
[Transportes, sessões e segurança](docs/transports-sessions-security.pt-BR.md).

- [ ] Obter o `smartlink.proto` correspondente ao AppServer alvo: `tGrpc` documenta
  somente o modelo Smartlink predefinido, disponível a partir de 20.3.1.0.
- [ ] Confirmar os métodos reais, incluindo a divergência documental
  `sendMessages`/`sendMessage`; verificar restrições de build/distribuição do contrato.
- [ ] Fazer chamada mínima ao servidor de prova e validar TLS, credenciais,
  metadados, tenant, erros, deadlines e modos de streaming efetivamente expostos.
- [ ] Avaliar biblioteca gRPC existente com ABI C ou wrapper C para integração
  Harbour/C/Zig; não implementar HTTP/2, HPACK e Protobuf do zero nesta etapa.
- [ ] Decidir adotar ou adiar pelo resultado da interoperabilidade, dependências,
  licença e custo. Não anunciar `HB_Grpc` genérico com base apenas em `tGrpc`.
- [ ] Medir protótipo de transporte/buffers em `src/zig/` contra a base Harbour:
  latência p95/p99, vazão, CPU, memória, cópias e comportamento sob falha/carga.
- [ ] Homologar propriedade/liberação dos buffers e acesso à VM pela ABI C;
  anunciar zero-copy somente nos trechos medidos que efetivamente o implementem.
- [ ] Manter `tSktSslSrv`/`tSktSslConn` fora do caminho principal; reconsiderar
  apenas diante de um requisito concreto de conexões recebidas pelo Protheus.

**Aceite da investigação:** decisão registrada com contrato/build e resultados
reproduzíveis. HTTP/2 multiplexa streams, mas continua sujeito ao bloqueio do TCP
por perda de pacotes; essa prova não deve prometer eliminar tal limitação.

## Decisões a fechar durante a implementação

- Especificação exata da evolução do frame/handshake do produto e tratamento de versões incompatíveis.
- Configuração padrão do endpoint Protheus, distinta dos canais NETIO/administração.
- MSSQL ou SQLite no primeiro teste, builds Protheus e versões de conectores homologadas.
- Tipos adicionais do perfil nativo Harbour e regras de conversão para TLPP.
- Tamanhos de bloco, orçamento de memória e política automática de compressão,
  escolhidos por medição no ambiente, respeitando limites técnicos.
- Primeiro caso funcional C/Zig e ordem de exposição das contribs.
- Modelo de acesso, emissão de tokens, publicação de módulos e durabilidade de jobs.
- Escopo do pool TLPP, retomada/afinidade de sessões e bibliotecas TLS/gRPC/AMQP homologadas.
- Licença do projeto e formato da distribuição.

As referências técnicas oficiais e a distinção entre implementação e proposta estão
no [README.md](README.pt-BR.md). Decisões futuras devem preservar os motivos para
Harbour, C e Zig, o suporte aos dois clientes e a reutilização dos recursos nativos.
