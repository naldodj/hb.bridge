# Serviços HTTP e administração web

[English](http.md)

O hbBridge usa o **hbhttpd** do Harbour no mesmo executável do NETIO e do
adaptador TCP Protheus. O [adaptador HTTP](../src/hb/transports/http/hbbridge.http.hb)
autentica as requisições e chama o registro versionado existente. HTTP não
duplica os executores de Health, addons ou SQL nem interpreta regras de
tenant/empresa/filial/xFilial/tabelas Protheus; o chamador fornece parâmetros
explícitos. Veja [arquitetura](architecture.pt-BR.md).

## Habilitar HTTP

HTTP fica desativado por padrão. Seu bind configurado é `127.0.0.1:8080`,
sem senha padrão. Use um INI privado da instalação baseado em
[hbbridge.ini](../config/examples/hbbridge.ini), e inicie o produto com
`./scripts/run-hbbridge.ps1 -Config <private-configuration>`:

```ini
[HTTP]
Enabled=true
Host=127.0.0.1
Port=8080
Password=<service-secret>
TLS=false
SendTimeoutMs=30000
Compression=auto
CompressionMinBytes=1024
CompressionLevel=1
Certificate=
PrivateKey=

[Admin]
Password=<different-admin-secret>
```

Substitua os placeholders localmente. `Enabled` e `TLS` aceitam `true`/`false`
em INI e valores lógicos em JSON. As chaves JSON são `httpEnabled`, `httpHost`,
`httpPort`, `httpPassword`, `httpTLS`, `httpCertificate`, `httpPrivateKey`.
A CLI `-httphost=`/`-httpport=` sobrepõe o bind; ativação e segredos continuam
no arquivo. Vale a precedência padrões < um arquivo < CLI. Caminhos de
certificado/chave são relativos ao arquivo de configuração. Conflitos de
portas impedem o início; falha parcial fecha os outros listeners já abertos.
`maxWorkers` define o teto do pool hbhttpd, substituindo o limite original 50.

`SendTimeoutMs` limita o envio da resposta completa depois da execução e da
codificação, sem limitar SQL ou recebimento da requisição. Padrão 30000 ms;
zero desativa esse prazo. O hbhttpd gerenciado envia blocos de 65536 bytes,
repete envios parciais/não bloqueantes dentro do orçamento restante e encerra
resposta incompleta antes de registrar sucesso ou atender outra requisição
keep-alive. O argumento 1000 ms do socket é orçamento de espera por prontidão,
sem pausa obrigatória. O relógio usa `hb_timerGet()` do Harbour; o comportamento
depende da plataforma/runtime. TLS direto e Linux exigem aceite separado.

## Compressão de respostas

`Compression=auto` negocia gzip por `Accept-Encoding`, incluindo pesos,
exclusões explícitas e wildcard. O limiar padrão é 1024 bytes, com nível zlib 1.
Preferir identity quando tiver peso maior, corpo pequeno ou compressão sem
redução de bytes. Se identity estiver proibido, gzip aceito pode ser usado
mesmo em corpos pequenos/maiores após compressão. Sem codificação disponível
aceitável, retornar 406 vazio. `Compression=off` desativa gzip.
`Vary: Accept-Encoding`, `Content-Encoding: gzip` e `Content-Length` dos bytes
compactados descrevem a representação; JSON/UTF-8 permanecem preservados.

Chaves JSON: `httpSendTimeoutMs`, `httpCompression`, `httpCompressionMinBytes`
e `httpCompressionLevel`. CLI correspondente: `-httpsendtimeoutms=`,
`-httpcompression=`, `-httpcompressionminbytes=` e `-httpcompressionlevel=`.
Nível aceita 1..9. Limiar zero permite tentar comprimir todo corpo não vazio,
sem impor limite de payload. Reutiliza-se o codec nativo incremental, sem
reduzir o tamanho total ao tipo de um bloco zlib. Respostas continuam
materializadas em memória; não é query streaming nem transferência HTTP chunked.

O cliente HTTP TLPP passa a solicitar `Accept-Encoding: gzip`, configurável
por `[hbBridge] HTTPAcceptEncoding=gzip|identity` no AppServer INI ou quarto
argumento opcional do construtor. Na prova isolada, FWRest entregou gzip ainda
compactado; hbBridge usa `GzStrDecomp()` antes do parser JSON seguro para NUL
e rejeita gzip corrompido. Caso o cliente nativo já expanda o corpo, JSON é
interpretado sem nova descompressão. Requisições continuam em JSON sem gzip.
Comparar novas rodadas com a política efetiva registrada; relatórios antigos
em identity não medem gzip.

O benchmark sobrepõe a preferência do INI: a rota HTTP instancia explicitamente
`New(url, token, timeout, "gzip", .T.)`, envia
`Accept-Encoding: gzip, identity;q=0` e verifica o suporte do cliente ao modo
obrigatório. Rejeita resposta sem gzip com `HTTP_COMPRESSION_REQUIRED`, incluindo
406 quando o servidor desativa compressão. O relatório registra
`httpRequireGzip=true` e `httpAcceptEncoding`. Clientes de aplicações continuam
com negociação opcional, salvo quando o quinto argumento for verdadeiro.

O RPC HTTP também recebe o resultado nativo do dispatcher compartilhado e
codifica uma vez, eliminando encode/decode/encode do resultado inteiro.
TCP/HTTP preservam validação, permissões, rejeição de binários e JSON numérico
com preservação de precisão.

A ativação HTTP exige segredo próprio de serviço, não vazio. Quando a
administração está habilitada, os segredos de serviço e admin precisam
diferir. Definir `adminPassword` também habilita o endpoint administrativo
NETIO existente; a administração web usa essa mesma credencial explícita.
`--config-info` informa ativação/bind/TLS e omite segredos e caminhos de
certificado/chave.

## Rotas e autorização

| Rota | Método | Autorização | Corpo / resultado |
| --- | --- | --- | --- |
| `/api/v1/health` | GET | `Bearer <service-secret>` | Resultado do Health compartilhado. |
| `/api/v1/services` | GET | Bearer de serviço | Descoberta dos serviços permitidos. |
| `/api/v1/rpc` | POST | Bearer de serviço | Envelope JSON: `service`, `params` e `version` opcional (padrão 1). |
| `/api/v1/services/<service-name>` | POST | Bearer de serviço | Corpo JSON contém os parâmetros do serviço; versão 1. |
| `/admin` ou `/admin/` | GET | Basic, usuário `admin` e segredo admin | Página web de status, somente leitura. |
| `/admin/status` | GET | Basic admin | JSON do Admin.Status compartilhado. |

Envie `Content-Type: application/json` no POST. Use JSON UTF-8 sem
compressão, com `Content-Length` HTTP em bytes; o frame `HBBRIDGE/1`/gzip do Protheus
não pertence ao HTTP. As respostas negociam gzip conforme descrito abaixo.
O adaptador não implementa gzip de requisição nem decodificação de corpo chunked.
Requisições Transfer-Encoding são recusadas antes de ler o corpo/executar.
Nomes de serviços e campos JSON mantêm a grafia publicada.
Nomes de esquemas de autenticação ignoram maiúsculas/minúsculas; os bytes
das credenciais continuam distinguindo a caixa. O usuário admin é `admin`.

A fronteira HTTP valida UTF-8 antes da execução. Caracteres suplementares
brutos e pares surrogate escapados em JSON produzem o mesmo texto, inclusive
nas chaves dos objetos. A normalização fica nas strings JSON HTTP e preserva
backslashes/aspas escapados; não altera o codec JSON global Harbour nem os
adaptadores TCP. Surrogates órfãos ou invertidos retornam
`INVALID_JSON`/400 antes da execução. UTF-8 bruto inválido retorna
`INVALID_UTF8`/400; um serviço que devolva texto UTF-8 inválido recebe
`INVALID_UTF8_RESULT`/500.

```json
{
    "service": "RPCRDD.Query",
    "params": {
        "alias": "MSSQL/pData",
        "sql": "SELECT 1 AS CALLER_VALUE"
    }
}
```

O perfil precisa existir no servidor; SQLProfile do INI AppServer não
participa da requisição HTTP. Cada chamada escolhe seu alias opaco. A mesma
rota chama Echo, ADDON.Execute ou outros serviços de dados registrados.
Credenciais de dados não executam Admin.Status nem acessam `/admin`; sem
credencial admin, a administração web fica desativada. Requisições sem
autorização retornam 401, administração desativada 403 e mídia não suportada
415. Uso incorreto de GET/POST nas rotas do adaptador retorna 405. O parser
nativo hbhttpd aceita GET/POST; outros verbos podem retornar 501 nativo
antes do adaptador. Falhas de serviço preservam o resultado
estruturado `success/error/code`, com o status HTTP definido pelo adaptador.
Cabeçalhos HTTP malformados são recusados pelo hbhttpd antes do adaptador
e podem produzir sua resposta HTML nativa de erro; o cliente precisa
verificar Content-Type antes de decodificar JSON.

A página mostra uptime, bind/estado/chamadas ativas dos endpoints e contadores
HTTP de requisições/rejeições, incluindo os endpoints NETIO incorporados.
Ainda não administra usuários, credenciais, arquivos, perfis SQL, conexões
ou encerramento remoto. Essas ações exigem contratos autorizados e testes
próprios.

## Cliente HTTP Protheus

O [exemplo TLPP](../examples/http/README.pt-BR.md) usa
`HBBridge.Client.HBBridgeHTTPClient` e `U_HBBridgeHTTPTest`, compilados com
a mesma árvore `src/tlpp/`. FWRest faz GET/POST com bearer do serviço, e
`HBBridgeRPCDataSet` reaproveita seu contrato de páginas SQL pelo HTTP.
A validação manual AppServer homologou 13 checks em 2026-10-07 sem identificar
aquele backend SQL. Em execuções manuais AppServer de 2026-10-08,
`U_HBBridgeHTTPTestMSSQL()` e
`U_HBBridgeHTTPTestSQLite()` passaram separadamente nos **13 checks cada**,
com os padrões de fixture `MSSQL/pData` e `sqlite_demo`. MSSQL executou na
thread 25976 às 10:33:33–10:33:34; SQLite, na thread 9916 às 10:34:07,
horários de São Paulo. Ambos incluem páginas/valores SQL pelo dataset comum;
veja [homologação](acceptance.pt-BR.md). Essas entradas de conveniência não
impõem perfil ao cliente HTTP genérico.

O texto da requisição segue a codificação AppServer e passa por EncodeUTF8.
As strings da resposta parseada mantêm UTF-8; a comparação de acento usa
DecodeUTF8 naquele campo. O comportamento 401 observado do FWRest recebe
fallback de compatibilidade, sem preservar o JSON do servidor nesse caso.
Unicode mais amplo/outras LIBs e HTTPS exigem homologação própria.

## Dependências e TLS

O bootstrap gerenciado compila **hbhttpd** e **hbtcpio** a partir do Harbour
fixado. hbhttpd gerencia parsing HTTP, sockets e pool; hbtcpio disponibiliza
a extensão VF IO TCP nativa para usos posteriores de arquivos/transporte.
`-hblib` é o modo de compilação de biblioteca do hbmk2, não uma contrib
Harbour separada. Veja [dependências](dependencies.pt-BR.md).

[O patch hbhttpd revisado](../config/patches/hbhttpd.patch) disponibiliza o
corpo bruto em `REQUEST_BODY`, torna `MaxWorkers` configurável e recusa
Transfer-Encoding não suportado com HTTP 400 e fechamento da conexão.
O patch também recusa Content-Length duplicado/não decimal, informa
prontidão após iniciar o listener,
habilita reuso do endereço e verifica parada nos loops de aceitação,
cabeçalho e corpo; o encerramento coordenado não depende de clientes ociosos
concluírem suas requisições. Corpos de erro não vazios dos handlers são preservados,
mantendo JSON estruturado em vez da página HTML padrão de resposta não 200.
Enquadramento HTTP nativo, Content-Length e tamanhos do log usam operações
Harbour por bytes. O adaptador valida UTF-8 bruto, usa UTF8EX em cada chamada
JSON/serviço e restaura a codepage anterior do worker em ALWAYS. Bytes de
configuração/credenciais não são recodificados. O aceite Unicode corresponde
aos testes concretos abaixo, independentemente de Protheus/MSSQL.
O checksum fica em [dependencies.json](../config/dependencies.json).
O Git mantém LF nos patches para preservar o checksum entre plataformas.
[prepare-http.ps1](../scripts/prepare-http.ps1) verifica e aplica o patch
em cópia isolada dentro de `.deps/http/`, preservando o checkout fixado,
e grava o registro da dependência. Avisos originais de autoria/licença são
mantidos.

HTTPS direto é opcional: compile com `HB_HTTP_TLS=1`, disponibilize
SDK/runtime **hbssl/OpenSSL** para a arquitetura e configure `TLS=true`,
`Certificate` e `PrivateKey`. Um build sem hbssl vinculado recusa ativar TLS;
não passa silenciosamente a HTTP aberto. Por exemplo:

```powershell
$env:HB_HTTP_TLS = '1'
$env:HB_WITH_OPENSSL = '<openssl-include-directory>'
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1 -OutputDirectory tmp/https-candidate
```

Validação de certificado/hostname, versões TLS, renovação e integração dos
clientes ainda precisam de homologação HTTPS real. Credenciais Basic/bearer
exigem canal protegido na implantação remota. Deixe HB_HTTP_TLS ausente no
build HTTP padrão; outros valores não vazios são recusados. HTTP em loopback
permite desenvolvimento local ou um proxy TLS configurado deliberadamente.
TLS no HTTP não protege automaticamente NETIO ou o listener TCP Protheus.

## Validação e próximos passos

[Os testes HTTP](../tests/integration/harbour/hbbridge.http.test.hb) cobrem
autenticação/separação dos canais, Health/Echo/addon/SQL, equivalência NETIO,
erros JSON/corpo, contextos concorrentes, status sem segredos, parada/reinício
e rollback de início. Os resultados ficam em [homologação](acceptance.pt-BR.md);
o registro histórico de 416 checks antecede HTTP.

A rodada Windows específica de 2026-10-06 passou em **65 verificações, zero
falhas e nenhum skip**, log
tmp/http-tests-f3476462dfbb4fe6b64d63b0de1c1149/results.log.
Cobriu framing HTTP por bytes sob UTF8EX, acentos/CJK/caracteres
suplementares, escapes BMP e pares surrogate, texto SQLite, execução Unicode
nativa, bytes das credenciais e rejeição de entradas malformadas. Foi testado
HTTP aberto; não cobriu HTTPS direto, Linux ou Unicode MSSQL. A suíte nativa
MSSQL de 2026-10-08 homologou posteriormente os tipos Unicode exercitados.
Execuções manuais das entradas HTTP no AppServer homologaram seus 13 checks
comuns por backend.
Unicode/tipos SQL ampliados pelo HTTP Protheus, HTTPS, Linux e cenários
controlados de falha/recursos/desempenho continuam pendentes. Os resultados manuais
AppServer não substituem os **92 checks MSSQL nativos** nem as **566 regressões
padrão**. Retome M06 no [WIP](../WIP.pt-BR.md) para falhas controladas/recuperação.

Parsing e timeouts nativos do hbhttpd diferem do adaptador Protheus. Seus
buffers/prazos não herdam `protheusReadChunkBytes`, `protheusTimeoutMs` nem
os budgets de payload/rede Protheus. Corpo, JSON e resultados são
materializados na memória. `MaxWorkers` limita threads; a fila nativa de
conexões aceitas não tem teto explícito nesta entrega. Ela não oferece a
rejeição imediata por capacidade do listener Protheus. O parser nativo lê
o corpo antes de o adaptador autenticar a chamada. Políticas configuráveis
de admissão/fila/cabeçalho/corpo/prazo permanecem pendentes, sem introduzir
um teto fixo de payload de prova de conceito. Conformidade HTTP
mais ampla, volumes maiores e outras combinações de codepage/banco,
TLS e Linux exigem aceite próprio
antes de anunciar um perfil remoto de produção. Ações web e um modelo REST
versionado podem ampliar o mesmo registro sem inferir regras do ERP.

<a id="http-review-on-2026-10-24"></a>

## Revisão HTTP em 2026-10-24

Os relatórios de benchmark fornecidos mostraram custos HTTP que justificaram
investigação. Três cargas ilustram essa observação diagnóstica; os tempos são
médias em milissegundos, sem comparação equivalente do servidor revisado:

| Linhas / tamanho da página | hbBridge TCP | hbBridge HTTP | Protheus REST |
| --- | ---: | ---: | ---: |
| 1000 / 100 | 417,5 | 637,6 | 770,8 |
| 10000 / 1000 | 1188,7 | 2569,1 | 1642,2 |
| 10000 / 10000 | 712,6 | 1982,3 | 895,1 |

Esses relatórios não identificam hashes dos fontes/RPO implantados nem pooling
físico. Seus tempos não estabelecem o efeito de uma alteração posterior.
A análise identificou espera de socket por envio, tratamento de envio incompleto
a reforçar, gzip HTTP ausente e ciclo redundante de encode/decode/encode JSON
do resultado RPC completo. O argumento de 1000 ms era espera máxima do socket,
não pausa incondicional. O patch gerenciado e o adaptador descritos acima
tratam esses caminhos.

A validação Windows nova usou HTTP aberto em loopback, dependências fixadas e
AppServer 24.3.1.5 isolado. Serviços, INI e RPO instalados não foram substituídos.
O [manifesto sanitizado](validation/http.response.windows.json) registra
identidades de fontes/build e os escopos distintos de verificação:

| Verificação | Resultado |
| --- | --- |
| Regressão nativa completa | 777 checks, zero falhas, saída 0. |
| Probe de falhas de envio do hbhttpd gerenciado | 18 asserções, zero falhas, saída 0; envios curtos, keep-alive, prazo com leitor parado, pipeline incompleto e parada coordenada. |
| Compilação TLPP isolada | Os 55 fontes, zero erros, saída 0. |
| FWRest instalado e cliente TLPP real | 14 checks, zero falhas, saída 0; UTF-8/NUL, identity/gzip, blocos de transferência de sete bytes, CRC inválido, recuperação e gzip obrigatório. |

O benchmark MSSQL AppServer real confirmou depois os dois resultados de gzip
obrigatório, com `HTTPAcceptEncoding=identity` definido deliberadamente no INI
isolado. Com compressão ativa no servidor, duas varreduras medidas e um
aquecimento de 10000 linhas/página10000 passaram, saída 0; o relatório manteve
`httpRequireGzip=true` e `httpAcceptEncoding="gzip, identity;q=0"`. Com
compressão desativada, o aquecimento falhou conforme esperado: amostra
`QUERY_FAILED`, código do serviço `HTTP_COMPRESSION_REQUIRED`, HTTP 406 e
saída 1. Não houve fallback identity. São casos de correção, sem comparação
pareada de desempenho.

A comparação MSSQL real separada usou `m08.constant.v1`, 10000 linhas em uma
página de 10000, concorrência um e pooling ODBC off. Quatro rodadas AppServer
alternaram identity, gzip, identity, gzip, com dois aquecimentos e cinco
varreduras medidas por rodada. Passaram as 20 medidas e oito aquecimentos:

| Política da resposta | Média primeira rodada (ms) | Média segunda rodada (ms) | Média combinada medida (ms) |
| --- | ---: | ---: | ---: |
| identity | 1948,210 | 1790,348 | 1869,279 |
| gzip | 816,158 | 1004,748 | 910,453 |

A média combinada gzip foi cerca de 51,3% menor nesta série local curta.
Ambas as políticas usaram o mesmo build revisado do servidor: mede-se a
política de encoding da resposta, sem isolar cada alteração de envio ou
serialização. A comparação antecedeu gzip obrigatório no benchmark. A rota
HTTP atual não pode ser alterada para identity pelo INI. Comparações
diagnósticas identity exigem cliente comum configurado explicitamente.

A verificação independente no fio obteve 582624 bytes identity e 107099 bytes
gzip, redução de 81,6%. Os corpos descompactados são idênticos byte a byte,
SHA-256 `37FAB9EF66483944DEEF51F9C51ADFC9E13EDACABDBAAB0EFA5638F4B7A03EA9`.
O helper mantido `tests/probes/hbbridge.http.wire.test.py` reproduz esse check
com o `endpoints.json` de uma fixture MSSQL recém-iniciada; portas e pastas
temporárias antigas não são pré-requisitos. Taxa de compressão isolada não
mede latência.

Resumos brutos AppServer tiveram uma linha INFO conhecida de inicialização
intercalada dentro do JSON. A análise removeu essa linha exata e as quebras de
linha físicas para recuperar os relatórios completos, validando aprovação e
agregados. Nenhuma amostra ou estatística foi alterada. O manifesto distingue
o RPO da comparação da compilação/probe posteriores de gzip obrigatório.

O patch nativo final também resolve `CR_LF + CR_LF` uma vez na variável local
do worker `cHeaderEnd`. Loop de leitura, trace e `ParseRequestHeader` usam o
mesmo valor; o parser o recebe explicitamente. Linhas repetidas do cabeçalho
`Accept-Encoding` são combinadas antes da negociação, preservando as exclusões.

Um diagnóstico posterior compilou 56 fontes TLPP e passou nos mesmos 14 checks
FWRest, depois alternou cinco requisições medidas mais um aquecimento por
codificação. Todas as respostas de 10000 linhas passaram na validação direta
dos valores. As médias das etapas gzip foram 179,851 ms em FWRest/servidor/rede,
1,511 ms na expansão, 43,158 ms no parsing JSON e 23,194 ms na validação das
linhas; total de 247,808 ms. O total identity foi 271,786 ms. São tempos
decorridos sem processamento do dataset, observação distinta da comparação
M08 acima. `profile-protheus-http.ps1` reproduz esse diagnóstico contra um
endpoint M08 recém-iniciado. A descompressão foi uma parte pequena da amostra;
a etapa da requisição nativa não separa SQL, codificação e rede.

O codec JSON agora resolve UTF-8 uma vez por documento, em vez de por escalar.
A comparação apenas de serialização preservou os 582434 bytes de saída com
DECIMALS 2/18 e FIXED desligado/ligado. Duas rodadas com lotes alternados
observaram médias 33,988/34,648 ms e 36,678/33,283 ms antes/depois do cache.
Os CVs da segunda foram 15,3%/17,7%; essa variação não comprova ganho estável
de latência. `benchmark-harbour-json.ps1` versiona a comparação sem SQL/HTTP.

Não se deduz medição de CPU por etapa ou memória, aceite Linux/TLS direto,
capacidade de produção nem aceleração geral. As respostas continuam
materializadas; a evolução deverá isolar execução/codificação no servidor
e parsing/cópias no chamador.
T01 permanece rascunho de contrato não implementado no [WIP](../WIP.pt-BR.md).

### Exportações recebidas em 2026-10-24

Os seis JSONs posteriores passaram no recálculo independente: 31 séries
selecionadas, 17580 amostras medidas e 62 aquecimentos; nenhuma divergência
em totais, média/mediana/P95, desvio populacional/CV, vazão ou contagens de
linhas/páginas/chamadas. Todos registram gzip obrigatório. As duas cargas
com 1500 iterações mostram estas médias de varredura pelo cliente, em ms:

| Linhas / página | TCP | HTTP gzip | REST Protheus | Redução da média HTTP vs REST |
| --- | ---: | ---: | ---: | ---: |
| 1000 / 100 | 389,741 | 459,361 | 623,639 | 26,34% |
| 10000 / 1000 | 1093,398 | 1423,550 | 1485,433 | 4,17% |

Na carga maior, o P95 HTTP foi 2096,303 ms contra 1910,647 ms do REST;
a menor média não comprova melhora da cauda. As médias internas do addon/
Protheus em job único foram 299,803/385,686 ms e 504,281/1018,630 ms;
esses escopos continuam separados da tabela de varredura pelo cliente.

Frente às observações HTTP antigas arredondadas acima, as médias longas
novas são cerca de 28,0%/44,6% menores. TCP e REST também variaram. Não foram
informadas identidades dos binários/RPO, pooling ou registro de carga
equivalente; a diferença inteira não pode ser atribuída a um patch/invariante
específico. Rodadas curtas de cinco iterações também variaram, sem melhora
monotônica comprovada.

Para repetir a análise das exportações com Python 3:

```powershell
python ./tests/probes/hbbridge.benchmark.report.test.py `
    --directory <pasta-exportacoes> --output <resumo-novo.json>
```

O analisador lê apenas JSON, valida as séries selecionadas bem-sucedidas e
recalcula as estatísticas medidas. Seu controle de corrupção rejeitou uma
média alterada. JSONs brutos/HTML continuam fora do Git; configurações
sanitizadas, hashes dos arquivos e resultados ficam no manifesto HTTP.
