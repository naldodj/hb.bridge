# Runtime, HTTP, dependências e resultados SQL

[English](evolution.md)

Análise das quatro propostas recebidas em 2026-10-07. Este documento separa
comportamento nativo e capacidades verificadas do trabalho de implementação.
hbBridge permanece um executor genérico: Protheus prepara contexto de negócio,
nomes de tabelas e SQL, recebendo resultados explícitos.

## Estado da thread e estado da requisição

`THREAD STATIC` do Harbour dá a cada thread seu próprio valor da variável.
É a declaração adequada para estado persistente pertencente ao worker. Isso
não significa que cada requisição começa no valor inicial: o pool reutiliza
threads, e uma recarga de HRB na mesma thread pode reutilizar estáticos
inicializados.

| Vida útil pretendida | Armazenamento |
| --- | --- |
| Uma requisição | Parâmetros, valores `LOCAL` ou contexto inicializado explicitamente. |
| Uma thread worker | `THREAD STATIC`, com reset explícito por requisição quando necessário. |
| Recurso compartilhado do processo | `STATIC` comum com sincronização e ciclo de vida definido. |
| Um módulo carregado | Handles HRB independentes e `HB_HRB_BIND_FORCELOCAL`; estado por thread é uma propriedade distinta. |

O hbhttpd nativo já declara contexto/resposta como thread statics e reinicia
o estado da resposta entre requisições. Veja as [declarações fixadas](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbhttpd/core.prg#L29)
e o [reset por requisição](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbhttpd/core.prg#L557-L560).

O mutex SQL do projeto e a barreira de testes precisam continuar compartilhados.
Syslog já usa thread statics. Funções/métodos static e as tabelas C imutáveis
do coletor são declarações diferentes e não exigem conversão.

A prova nativa gerenciada passou em **31 asserções**: um HRB compartilhado
isolou estado em 12 threads; duas chamadas por worker conservaram seu contador
privado; quatro ciclos de carga/execução/descarga na mesma thread produziram
1, 2, 3 e 4. Dois HRBs na mesma thread mantiveram armazenamento independente.
Evidências: `tmp/thread-static-probe.log`, `tmp/thread-static-probe.hb` e
`tmp/thread-static-addon.prg`. Essa prova complementa o teste de isolamento
de módulos com STATIC comum, preservando aquela cobertura.

Reprodução atual: `scripts/test-harbour-thread-state.ps1`, com fontes
versionados em `tests/probes/`. Caminhos tmp acima são somente históricos.


## Alternativas de transporte HTTP

Manter hbhttpd como adaptador atual e avaliar Zig quando requisitos medidos
justificarem a alternativa. As lacunas atuais incluem verbos além do GET/POST
nativo, requisições chunked, política de fila/admissão e homologação mais ampla
de ciclo de vida/TLS. A alternativa deve usar o mesmo registro de serviços,
permissões, contexto e contrato de resultado/erro.

Zig pode cuidar do parser HTTP, rede e buffers enquanto Harbour executa
serviços. A ABI C precisa definir tamanhos em bytes, propriedade/liberação
de memória, erros, prazos e cancelamento. Workers criados por Zig devem entrar
na VM Harbour por interfaces suportadas ou enfileirar trabalho para workers
Harbour. Copiar executor, implementação SQL ou regras Protheus para outro
transporte comprometeria o desenho de núcleo compartilhado.

O [tutorial sugerido](https://ziglang.com.br/tutoriais/zig-http-server/) é uma
referência arquitetural, sem constituir implementação fixada para a versão
do projeto. Seus exemplos com `std.net.Address` não correspondem à API Zig
0.16.0 instalada. `std.http.Server` recebe interfaces `std.Io.Reader`/`Writer`
e trata uma conexão; listeners, rotas, agendamento, autorização, TLS e parada
ainda precisam de integração. Consulte as [mudanças oficiais de I/O/rede
em 0.16.0](https://ziglang.org/download/0.16.0/release-notes.html#Networking).

Antes de alterar o padrão, comparar os adaptadores com os mesmos serviços,
payloads, concorrência, memória, integridade de bytes, requisições inválidas,
parada e homologação Windows/Linux. Transporte HTTP Zig ainda não implementado.

## Um único resolvedor de dependências

hb_compile já é dependência fixada, pertencente ao bootstrap do projeto.
Também deve resolver dependências externas de build do Harbour; hbBridge
seleciona as capacidades necessárias e consome ambiente/artefatos gerados.

No Windows, o runner fixado permite resolução seletiva com
`-Full -Dependency openssl -DependencyTriplet x64-windows -StrictDependencies`.
Essa é a próxima integração pretendida para `HB_HTTP_TLS=1`. Selecionar
dependências evita incorporar Qt/GUI/SDKs de bancos sem relação com HTTP.
`config/external-deps.generated.zig.ps1` pertence ao hb_compile. Seus caminhos
de include/link precisam ser consumidos pelo adaptador de toolchain com
ambiente temporário, inclusive em processos separados de build/teste. O reuso
do receipt deve considerar seleção, arquitetura, configuração gerada e runtime.

O catálogo OpenSSL atual espera DLLs Windows dinâmicas. Resolver includes/libs
não distribui essas DLLs junto do executável de serviço. Triplets, implantação
do runtime, baseline vcpkg e versões/checksums de pacotes precisam de contrato
explícito antes de declarar dependências externas reproduzíveis. Os scripts
hbBridge atuais ainda exigem SDK OpenSSL informado para TLS; delegar essa
resolução permanece pendente, não foi entregue por esta análise.

O resolvedor fixado usa executáveis Windows. Os perfis Linux WSL/Docker partem
do Windows e diferem do bootstrap Linux nativo. Resolução Linux nativa deve
tornar-se capacidade upstream do hb_compile ou usar uma rota de build suportada
e declarada separadamente. Manter essa lacuna explícita, sem duplicar downloader
OpenSSL no hbBridge. Recursos licenciados TOTVS e identidade da instalação
continuam fora do resolvedor de dependências abertas.

## Tabelas para apresentação nativa no Protheus

Compartilhar banco não compartilha conexão/sessão. `RPCRDD.Query` abre sua
própria conexão e a fecha depois de coletar linhas; o dataset cliente recebe
JSON, sem criar alias AppServer/DBAccess.
A Microsoft documenta o [escopo de sessão das tabelas SQL temporárias](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver17#temporary-tables).
O SQLite documenta [bancos em memória privados e compartilhados](https://www.sqlite.org/inmemorydb.html);
mesmo os bancos nomeados com shared-cache exigem conexões no mesmo processo.

| Destino do resultado | Contrato |
| --- | --- |
| MSSQL `#temp` local | Pertence à sessão SQL criadora; outra conexão DBAccess não a consome automaticamente. |
| MSSQL `##temp` global | Exige vida útil explícita, nome único, posse e gestão da conexão; não é a estratégia padrão. |
| Tabela SQL real de staging | Compartilha resultados confirmados com outra conexão; exige schema de saída reservado e ciclo de vida gerenciado. |
| `FWTemporaryTable` Protheus | Criada e mantida pela thread Protheus; copia o dataset atual para browse/navegação nativos. |
| SQLite `:memory:` | Não é armazenamento compartilhado com AppServer; a conexão atual fecha a cada chamada. |
| Arquivo SQLite | Exige local compartilhado explícito, acesso cliente compatível, schema, locks/journaling e limpeza. `LOCALFILES=SQLITE` não entrega essa integração sozinho. |

`HBBridgeBrowseData` já apresenta a página atual em arrays FWBrowse, com
títulos/máscaras resolvidos no Protheus e temporária usada pela interface de
filtros. T04 do pacote 002 adiciona o
[adapter de tabela nativa](native-presentation.pt-BR.md) por esquema explícito,
preservando o caminho existente. Popula uma `FWTemporaryTable` pertencente ao
chamador a partir da página atual do dataset tipado e expõe seu alias ao
`FWBrowse` nativo. Alias, tabela física e índices de pesquisa por campo são
criados uma vez e preservados entre páginas, limpando/preenchendo linhas.
Conversão de esquema/valores é sempre validada; releitura completa é diagnóstico
opcional, exercitado independentemente pelos testes nativos. Close/Destroy
final libera o armazenamento. O dataset mantém os valores UTF-8 originais;
páginas seguintes exigem chamadas explícitas.
Os controles da UI solicitam essas páginas. O browse nativo é função estática
local do exemplo de apresentação, não método público de `HBBridgeBrowseData`;
uma API genérica de browse nativo permanece futura. O transporte existente é
preservado. Os contratos TOTVS de
[tabela temporária](https://tdn.totvs.com/display/framework/FWTemporaryTable)
e [integração ao browse](https://tdn.totvs.com/display/framework/Dados%2BProtegidos%2Bno%2BBrowse)
definem posse e APIs nativas de apresentação.

Para evitar transferir todas as linhas em JSON, criar contrato separado, por
exemplo `RPCRDD.Materialize`, preservando `RPCRDD.Query`. Primeiro backend
proposto: schema MSSQL de staging configurado explicitamente. Retornar handle
opaco, perfil destino, referência schema/tabela, metadados de colunas, quantidade
de linhas, estado pronto e expiração. Publicar somente após commit; liberação
idempotente, leases, recuperação de crash e verificação de posse são necessários.
Restrições de identificadores, precisão/escala, nulos, encoding e ordem explícita
das linhas integram o contrato. Nome físico não é token de autorização.

Protheus pode consumir a tabela confirmada com SELECT/TCGenQry próprio ou
copiá-la para temporária nativa quando a apresentação exigir. Uma tabela criada
por ODBC não fica automaticamente registrada no DBAccess/dicionário Protheus.
[TCGenQry](https://tdn.totvs.com/display/tec/TCGenQry) define conexão/cursor.
Empresa/filial/tenant, metadados de dicionário, títulos, máscaras e ações
permanecem no chamador. Medir gravação/leitura de staging contra JSON paginado
antes de escolher o caminho padrão.

O adapter de resultados nativos está implementado no cliente em T04;
homologação conjunta backend/UI permanece em T05. Materialização no servidor
continua proposta, sem implementação no serviço de query atual.

<a id="resultados-em-memoria-entre-requisicoes"></a>

## Resultados em memória entre requisições

Ideia futura registrada em 2026-10-23, fora da implementação do pacote 002:
materializar um resultado SQL uma vez e reutilizá-lo entre requisições sem
repetir o SELECT de origem. **MEMIO do Harbour (`hbmemio`, `mem:`)** é um sistema
de arquivos virtual em memória, distinto de `MemoRead()`/`MemoWrit()`. Um RDD
DBF pode armazenar tabela, memo e índices nele. O contrib integra o catálogo
gerenciado; o produto atual não vincula/expõe serviço de cache MEMIO de resultados.

A [implementação MEMIO fixada](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbmemio/memio.c)
mantém arquivos nomeados depois de fechar o último handle, em armazenamento
compartilhado do processo. Fechar conexão SQL ou área RDD não exige removê-los.
Essa observação se refere a arquivos DBF/memo/índice nomeados comuns. Uma
tabela temporária/com exclusão automática do RDD pode apagar seus arquivos ao
fechar a área proprietária (por exemplo via `DBI_ISTEMPORARY`); MEMIO não
substitui essa política.
Outra thread pode reabrir arquivos preservados com área/cursor próprios. Exclusão explícita ou
encerramento do processo termina essa vida útil; outro processo/host não acessa
o mesmo armazenamento MEMIO. Há reuso no host ativo, sem durabilidade entre
reinícios do serviço. As operações de locks de bytes são stubs; a seção crítica
interna não comprova gravação/locks de registros DBF concorrentes. Começar a
avaliação futura com resultados publicados imutáveis e áreas independentes de
leitura, sem escritores concorrentes.

O [probe nativo reutilizável](../tests/probes/hbbridge.memio.snapshot.test.hb)
e o [runner](../scripts/test-harbour-memio.ps1) passaram em 2026-10-23 com
Harbour/Zig gerenciados no Windows: **22 verificações em um processo mais uma
em processo novo**, zero falhas/saída 0. Cobrem fechamento/término da thread
produtora, reabertura DBF/FPT/CDX, duas threads leitoras com cursores próprios,
NUL no memo, exclusão explícita dos três arquivos e perda no encerramento.
Não homologam SQL, endpoint do produto, serviço de cache, locks de gravação
ou Linux.

Fluxo futuro proposto, sem definir novos nomes de serviços/APIs neste momento:

1. Chamador autorizado solicita resultado materializado com perfil, SQL,
   valores e escopo de acesso resolvido pelo chamador explícitos.
2. Host lê uma vez, constrói resultado privado, valida esquema/valores e só
   publica para leitura depois de concluir cópia/índices.
3. Retorna handle opaco autorizado. Requisições seguintes leem páginas/buscam
   em áreas independentes através desse handle, sem repetir o SELECT.
4. Liberação explícita, expiração ou descarte por memória retiram o resultado.
   Aguardar leitores ativos antes de excluir todos os arquivos associados.
   Atualização cria/publica novo resultado, sem reescrever o snapshot publicado.

O conteúdo representa uma observação no momento da materialização. Não cria
garantia transacional/snapshot do banco durante a leitura original nem detecta
gravações posteriores via DBAccess/outras aplicações. O chamador escolhe
atualidade/renovação; Protheus resolve tenant/empresa/filial, e o host aplica o
escopo autorizado fornecido. Não reutilizar transparentemente resultado/texto
SQL de outro usuário nem inferir contexto ERP. Nome físico não autoriza acesso.

Antes de implementar, definir posse, isolamento por escopo, expiração/último
uso, referências ativas, cancelamento/limpeza parcial, orçamento configurável
de memória e comportamento em falta de memória/descarte. Comprovar UTF-8,
NULL, texto longo, representação numérica exata e índices; copiar para DBF não
pode alterar tipos SQL silenciosamente. Comparar MEMIO/RDD com hashes ou outro
armazenamento explícito, medindo criação/cópia/índices, leituras repetidas,
memória e atualidade da origem. O banco pode manter seu próprio cache de
consultas; guardar em RAM isoladamente não comprova vantagem de desempenho.

Preservar a semântica atual de query/página nova em `RPCRDD.Query`. Reuso de
resultados é separado de pooling físico ODBC, FWTemporaryTable do Protheus e
staging MSSQL. O resultado reutilizável pode reduzir trabalho na origem e
estabilizar páginas subsequentes, com custo de memória e dados deliberadamente
mais antigos.
