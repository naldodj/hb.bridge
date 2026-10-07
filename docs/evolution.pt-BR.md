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

Um primeiro adaptador de apresentação pode criar `FWTemporaryTable` no TLPP
a partir de schema explícito, copiar páginas e retornar objeto proprietário e
alias para `FWMBrowse`, preservando o transporte atual. Os contratos TOTVS de
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

Esses serviços de apresentação/materialização são propostas de desenho e
não estão implementados no serviço de query atual.
