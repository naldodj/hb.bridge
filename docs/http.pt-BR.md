# Serviços HTTP e administração web

[English](http.md)

O hbBridge usa o **hbhttpd** do Harbour no mesmo executável do NETIO e do
adaptador TCP Protheus. O [adaptador HTTP](../src/hb/transports/http/hbbridgehttp.prg)
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
não pertence ao HTTP. O primeiro adaptador não implementa gzip de requisição,
negociação de compressão de resposta nem decodificação de corpo chunked.
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
        "alias": "mssql/pData",
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

[Os testes HTTP](../tests/integration/harbour/hbbridgehttptest.prg) cobrem
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
HTTP aberto; HTTPS direto, Linux e Unicode MSSQL ainda não foram homologados.

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
