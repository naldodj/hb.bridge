# Roadmap do hbBridge

O objetivo é disponibilizar os recursos de Harbour, C e Zig ao Protheus e a
clientes Harbour nativos por uma integração extensível. O [README.md](README.md)
registra os fundamentos, o estado do MVP e o desenho pretendido.

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
- **Arquivos:** Harbour VF IO API (`hb_vf*`) como base comum para provedores
  locais/remotos; clientes TLPP usam uma fachada de serviços com recursos por sessão.
- **Implementação única:** componentes reutilizáveis em `src/`, exemplo mínimo
  em `examples/mvp/` e validações migradas para testes de regressão. O histórico
  Git preserva o MVP original, sem duas cópias ativas do servidor.
- **Depuração:** adotar inicialmente `hbdebug`, já nativo do Harbour; evoluir
  para HBDAP opcional conforme a maturidade do projeto privado e os testes no hbBridge.
- **Volume:** substituir o teto fixo do MVP por transferência incremental e
  limites técnicos/operacionais negociados; considerar `MAXSTRINGSIZE` no TLPP.
- **Compressão:** preservar o MVP `HBBRIDGE/1`/`HBS1` e avaliar `none`/`gzip` no novo
  contrato; usar os mecanismos nativos no caminho Harbour/NETIO.
- **Rede e serviço:** NETIO em `0.0.0.0:2941`, administração em
  `127.0.0.1:2940`, com configuração própria e instalação como serviço. Um único
  executável hbBridge incorpora `hbnetio` por chamadas de função no mesmo processo.

As caixas concluídas abaixo registram código existente, não homologação geral.
Recursos disponíveis no Harbour só serão considerados integrados após os aceites.

## Base existente — preservar e ampliar

- [x] Servidor TCP multithread, bind `0.0.0.0` e porta padrão `1512`; destino local `127.0.0.1`.
- [x] Dispatcher com `Health`, `Echo` e `ADDON.<arquivo>`.
- [x] `Health` exercitando Harbour → C → Zig no build atual.
- [x] Cliente TLPP com frame `HBBRIDGE/1|JSON|<bytes-do-JSON>\n<payload-json>`.
- [x] Compressão em memória nos dois sentidos com `GzStrComp`/`hb_ZUncompress`
  e `hb_gzCompress`/`GzStrDecomp`.
- [x] Teste Protheus de `Health`, `Echo` e `ADDON.examples\sample_addon.prg`,
  incluindo retorno de 200.000 caracteres repetidos no `Echo`.
- [x] Compilação em memória de `.prg`/`.hb` e carregamento de `.hrb`, com
  símbolos locais à chamada e descarregamento do módulo.
- [x] Testes Harbour no repositório para concorrência, isolamento e falhas de addons.
- [x] Envio parcial tratado no servidor; o cliente TLPP ainda precisa de ajuste.
- [x] Build Harbour/C com Zig e biblioteca `hbBridge_zig` vinculada.
- [x] Biblioteca `hbnetio` no link, ainda sem listener NETIO ativo.
- [x] Esboço de `TRPCDataSet` para `RPCRDD.Query`, sem implementação no servidor.
- [x] Módulo Syslog UDP disponível, ainda sem ligação ao fluxo de chamadas.
- [x] Assinatura `HBBRIDGE/1`; servidor aceita `HBS1` e preserva a assinatura na resposta.
- [x] Regressões Harbour de `Echo` e erro com ambas as assinaturas no código de testes.
- [x] Análise do [brainstorming](docs/transportes-sessoes-seguranca.md), sem integrar novos transportes nesta etapa.

**Dívidas do MVP:** JSON limitado a 16 MiB no servidor, compressão obrigatória,
descompressão por leitura TCP, bind fixo, uma conexão por chamada e ausência de serviço
de sistema/administração. O teste com dados repetidos não valida transferência
grande pouco compressível nem fragmentação. Essas restrições não definem o
produto final e serão substituídas com compatibilidade documentada.

## Sequência de entrega

1. Separar responsabilidades dos fontes, exemplo MVP e regressões (marco 0).
2. Consolidar registro de serviços, NETIO nativo e configuração de rede (marco 1).
3. Especificar o contrato e corrigir transferência; validar versões em paralelo
   com os serviços existentes (marco 2).
4. Entregar o próximo teste funcional, `RPCRDD.Query` com MSSQL e/ou SQLite,
   e integrar DBF via NETIO e arquivos VF IO (marco 3).
5. Ampliar módulos, contribs e ABI C/Zig conforme os casos de uso (marco 4).
6. Homologar serviço, administração, acesso e distribuição (marco 5).
7. Acrescentar jobs, lotes e processamento incremental conforme demanda (marco 6).

Um primeiro teste SQL pode usar o contrato do MVP enquanto o novo é desenvolvido.
Grandes volumes dependem do marco 2; DBF remoto depende do NETIO do marco 1.
ABI C/Zig e infraestrutura de serviço podem avançar junto com esses marcos.
A depuração com `hbdebug` começa em paralelo ao marco 0 e acompanha os serviços;
o desenvolvimento do HBDAP não bloqueia essa primeira entrega.

## Marco 0 — separar produto, exemplo MVP e regressões

A [estrutura pretendida](README.md#estrutura-pretendida) organiza uma única
implementação. A reorganização será incremental; nenhuma pasta nova significa,
por si só, que um componente já foi homologado para produção.

- [ ] Corrigir o destino local da suite Harbour para `127.0.0.1` e alinhar
  nomes/chamadas das fixtures HRB; registrar testes executados e eventuais skips.
- [ ] Registrar a revisão Git de referência do MVP e os resultados conhecidos
  de seus cenários antes da reorganização.
- [ ] Classificar os fontes atuais entre host, núcleo, transportes, serviços,
  carregamento de addons, telemetria e clientes.
- [ ] Separar o ponto de entrada e ciclo de vida em `src/hb/host/`, mantendo um
  único executável para console, serviço e perfil de demonstração.
- [ ] Extrair registro/despacho/contexto para `src/hb/core/` e handlers para
  `src/hb/services/`, preservando os comportamentos dos serviços existentes.
- [ ] Isolar sockets/enquadramento do MVP em `src/hb/transports/protheus/`,
  mantendo o perfil `HBBRIDGE/1`/`HBS1` como compatibilidade configurável e testada.
- [ ] Criar a integração do NETIO nativo em `src/hb/transports/netio/`, que
  usará a biblioteca existente e o mesmo registro de serviços.
- [ ] Preservar loader/telemetria em seus módulos; extrair o adaptador C embutido
  para `src/c/` quando separar build e responsabilidades for útil.
- [ ] Criar `examples/mvp/` com perfil mínimo e instruções para usar o binário
  do produto, referenciando addons e clientes compartilhados.
- [ ] Migrar cenários `Health`/`Echo`/`ADDON.` e os testes de concorrência,
  isolamento e falhas para `tests/integration/harbour/` e `protheus/`.
- [ ] Acrescentar regressões em `tests/contract/` para tipos, erros e formatos;
  criar testes unitários onde houver comportamento independente relevante.
- [ ] Centralizar composição do build e dependências, sem duplicar fontes
  de servidor/dispatcher/loader entre exemplo e produto.
- [ ] Ajustar caminhos do build, testes, scripts, módulos e documentação no
  mesmo passo de cada extração; comparar comportamento antes e depois.

**Aceite:** execução de referência e exemplo usam a mesma implementação;
regressões preservam o comportamento conhecido do MVP. A árvore distingue
produto, demonstração e testes, com um único ponto de entrada e sem cópias
ativas dos componentes. Novos recursos serão validados diretamente no produto.

## Depuração — frente transversal desde o MVP

A [estratégia de depuração](README.md#depuração-hbdebug-primeiro-hbdap-como-evolução)
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

- [ ] Fixar versões/revisões Harbour e Zig, plataformas e contribs do build;
  registrar a matriz de versões AppServer/TLPP suportadas.
- [ ] Separar handlers de negócio dos adaptadores de transporte. O núcleo
  recebe/devolve valores Harbour; cada adaptador cuida da representação.
- [ ] Criar registro de serviços com nome, versão, assinatura, tipos, permissões,
  handler, dependências e modalidades de resultado; expor descoberta de capacidades.
- [x] Avaliar estaticamente `contrib/xhb/trpc.prg` e o cliente associado;
  registrar conclusões em [Harbour VF IO e TRPC](docs/harbour-vfio-trpc.md).
- [ ] Avaliar extração do modelo de descrição/executor de `TRPCFunction` para
  o registro comum, independente dos sockets e do protocolo `XHBR`.
- [ ] Adaptar nomes com namespaces, tipos, erros e autorização; manter argumentos
  por chamada e testar concorrência antes de incorporar código do TRPC.
- [ ] Hospedar NETIO e adaptador Protheus no mesmo executável hbBridge,
  compartilhando núcleo/catálogo e isolando o estado de cada chamada.
- [ ] Vincular `hbnetio` estaticamente na implantação inicial e integrar suas
  funções ao host, sem iniciar um segundo executável de servidor.
- [ ] Reaproveitar o modelo do utilitário upstream para configuração/administração
  e serviço, mantendo um único ponto de entrada e runtime Harbour.
- [ ] Integrar as APIs de servidor/RPC do hbnetio e reaproveitar seu atendimento
  multithread, com configuração e ciclo de vida explícitos.
- [ ] Adotar `_NETIOSRV_IPV4_DEF = "0.0.0.0"` e `_NETIOSRV_PORT_DEF = 2941`
  como padrões do listener nativo; permitir configuração de interface e porta.
- [ ] Adotar `_NETIOMGM_IPV4_DEF = "127.0.0.1"` e `_NETIOMGM_PORT_DEF = 2940`
  para administração, habilitada com configuração/credencial própria.
- [ ] Dar ao adaptador Protheus endpoint independente configurável, com perfil
  MVP em `0.0.0.0:1512` e opção de bind local; validar conflitos e configuração inválida.
- [ ] Externalizar host/porta do cliente TLPP e do teste; clientes usam IP/DNS
  do servidor, nunca `0.0.0.0` como endereço de destino.
- [ ] Documentar precedência entre parâmetros, arquivo e padrões, incluindo
  diretórios de dados/addons, timeouts, concorrência e orçamento de memória.
- [ ] Habilitar `-prgflag=-DHB_EXTERN` e `REQUEST __HB_EXTERN__` no executável
  que hospeda o RPC; disponibilizar explicitamente as contribs adicionais.
- [ ] Validar `-rpc`/`-rpc=<módulo>` no servidor de referência e definir o filtro
  de chamadas do hbBridge. Vinculação de símbolos não autoriza todas as funções.
- [ ] Criar cliente Harbour de integração usando NETIO, com chamada ao core
  e aos mesmos serviços acessíveis ao Protheus.
- [ ] Aproveitar a serialização nativa de argumentos/resultados do NETIO;
  homologar `hb_Serialize`/`hb_Deserialize` quando um serviço usa blocos serializados.
- [ ] Definir tipos permitidos no perfil Harbour, codepages e compatibilidade
  entre versões; tratar recursos vivos por identificadores de serviço.

**Aceite:** cliente Harbour remoto conecta-se ao listener NETIO em 2941 e
executa um serviço registrado e uma função do core. O Protheus continua
executando `Health`, `Echo` e `ADDON.` pelo adaptador. Interfaces e portas são
configuráveis; administração usa canal separado. Os protocolos permanecem
interoperáveis com seus respectivos clientes.

## Marco 2 — contrato, grandes volumes e compressão negociada

### Contrato de serviços e compatibilidade

- [ ] Versionar protocolo e serviços separadamente, com descoberta e tratamento
  de versões/capacidades não suportadas.
- [ ] Especificar handshake pequeno e sem compressão para o novo adaptador TLPP;
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
- [ ] Preservar/migrar explicitamente retornos de `Health`, `Echo`, `ADDON.` e
  `header`/`rows` esperados por `TRPCDataSet`, com testes entre versões.
- [ ] Definir prazos, cancelamento cooperativo, idempotência e política de nova
  tentativa. Não repetir automaticamente operações com efeitos após desconexão.

### Conexões persistentes, pool e sessão

- [ ] Implementar primeiro o enquadramento incremental da seção seguinte;
  persistência será uma capacidade negociada do novo perfil, sem alterar o legado.
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
  empresa/filial autorizadas e prazo. Metadados do cliente não concedem acesso.
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

- [ ] Especificar os bytes do novo frame externo: versão, codec, compressão,
  identificação da chamada/stream, sequência/final e comprimentos transmitido
  e expandido, validados antes de alocar ou descomprimir.
- [ ] Tratar TCP como fluxo: cabeçalhos/corpos parciais, mensagens coalescidas,
  envio parcial, EOF, truncamento, timeout e reconexão.
- [ ] Corrigir o envio TLPP e substituir a descompressão de cada `Receive`
  pela leitura da unidade completa. Verificar retornos de socket e compressão.
- [ ] Definir a migração do enquadramento `HBBRIDGE/1`/`HBS1`, sem confundir seu comprimento
  JSON descomprimido com o comprimento transmitido; não desligar gzip no legado.
- [ ] Substituir o teto fixo de 16 MiB no novo contrato por limites configuráveis
  e negociados por bloco/conexão, mantendo compatibilidade explícita do legado.
- [ ] Inventariar limites de runtime, arquitetura, campos dos protocolos e APIs
  Harbour/NETIO/TLPP/conectores; evitar promessas de tamanhos infinitos.
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
O novo adaptador funciona com e sem gzip e transfere volume total maior que
16 MiB e que o limite de uma string do perfil Protheus homologado, consumindo
blocos sem ultrapassar os limites por valor e o orçamento de memória medido.
O consumidor lento, a descompressão inválida e a desconexão têm comportamento
testado; o perfil legado tem caminho de migração documentado.

## Marco 3 — MSSQL, SQLite, DBF e Harbour VF IO

### Próximo teste: RPCRDD.Query

- [ ] Escolher MSSQL via ODBC e/ou SQLite para o primeiro teste real e registrar
  versões do servidor, bibliotecas cliente e dependências do build.
- [ ] Habilitar `rddsql`/`SQLMIX` com `sddodbc` para MSSQL e `sddsqlt3` para SQLite;
  avaliar `hbodbc`/`hbsqlit3` quando a operação exigir a API direta.
- [ ] Implementar `RPCRDD.Query` no registro/dispatcher, com perfil lógico de
  conexão, `alias`, `sql` e retorno compatível com `success`, `header`, `rows`.
- [ ] Atualizar exemplos de perfis para MSSQL/SQLite, mantendo credenciais no
  servidor; o arquivo atual é apenas esboço e não implementa criptografia.
- [ ] Integrar o teste Protheus e `TRPCDataSet`: leitura por nome, navegação,
  resultado vazio, consulta inválida, conexão indisponível e fechamento.
- [ ] Exercitar o mesmo serviço a partir de cliente Harbour nativo.

### Evolução do acesso a dados

- [ ] Adicionar parâmetros SQL e metadados de tipo, tamanho, precisão e nulos,
  com evolução compatível do cabeçalho atual.
- [ ] Implementar páginas/cursores, prazo, fechamento/expiração e campos grandes;
  adaptar `TRPCDataSet` para consumo incremental.
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

Esta frente evolui com os serviços. A integração C/Zig existente é preservada;
novas extensões entram conforme a necessidade e os resultados medidos.

- [ ] Integrar `ADDON.` ao registro comum mantendo a chamada do MVP; evoluir
  de caminho de arquivo para nome/versão de módulo com mapeamento compatível.
- [ ] Reutilizar compilação `.prg`/`.hb` e execução `.hrb`; validar
  `HBNETIOSRV_RPCMAIN` nos módulos usados no modo `-rpc=<arquivo>` do hbnetio.
- [ ] Definir metadados de módulos, dependências, tipos, permissões e erros;
  permitir consumo pelos dois perfis de cliente.
- [ ] Configurar diretórios permitidos e canonicalização, publicação e política
  de confiança; preservar isolamento de símbolos e estáticos já implementado.
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
- [ ] Tornar concorrência, timeouts, filas e memória configuráveis; validar
  compatibilidade com threads das rotinas, drivers e extensões escolhidos.
- [ ] Conectar Syslog ao ciclo do servidor e às chamadas, preservando operação
  quando o coletor estiver indisponível e excluindo credenciais dos logs.
- [ ] Registrar correlação, latência, erros, bytes transmitidos/expandidos,
  memória e recursos ativos; distinguir vida do processo e prontidão dos serviços.
- [ ] Automatizar build e regressões `Health`/`Echo`/`ADDON.`, NETIO, SQL, DBF,
  binários, limites negociados, concorrência e falhas de rede/módulo/driver.
- [ ] Homologar instalação, inicialização após reinício, parada e recuperação
  do serviço em Windows e Linux, incluindo porta ocupada e configuração inválida.
- [ ] Criar empacotamento reproduzível com dependências e versões explícitas;
  atualizar `docs/`, `tests/` e scripts conforme cada comportamento for entregue.
- [ ] Documentar instalação, diagnóstico, atualização e recuperação; definir a
  licença e criar `LICENSE` antes da primeira distribuição pública.

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
[Transportes, sessões e segurança](docs/transportes-sessoes-seguranca.md).

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

- Especificação exata do novo frame/handshake e período de suporte ao MVP `HBBRIDGE/1`/`HBS1`.
- Configuração padrão do endpoint Protheus, distinta dos canais NETIO/administração.
- MSSQL ou SQLite no primeiro teste, builds Protheus e versões de conectores homologadas.
- Tipos adicionais do perfil nativo Harbour e regras de conversão para TLPP.
- Tamanhos de bloco, orçamento de memória e política automática de compressão,
  escolhidos por medição no ambiente, respeitando limites técnicos.
- Primeiro caso funcional C/Zig e ordem de exposição das contribs.
- Modelo de acesso, emissão de tokens, publicação de módulos e durabilidade de jobs.
- Escopo do pool TLPP, retomada/afinidade de sessões e bibliotecas TLS/gRPC/AMQP homologadas.
- Licença do projeto e formato da distribuição.

As referências técnicas oficiais e as distinções entre MVP e proposta estão
no [README.md](README.md). Decisões futuras devem preservar os motivos para
Harbour, C e Zig, o suporte aos dois clientes e a reutilização dos recursos nativos.
