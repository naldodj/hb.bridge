# Configuração por arquivo e linha de comando

O hbBridge aceita INI e JSON. Ambos produzem o mesmo hash interno e passam
pela mesma validação de tipos, capacidades, portas, diretórios e perfis SQL.
O arquivo não precisa listar todos os campos: os omitidos usam os padrões
do produto. A precedência é **padrões < um arquivo INI/JSON < CLI**.

Use `-config` no executável ou `-Config` nos launchers:

```powershell
.\scripts\run-hbbridge.ps1 -Config config/examples/hbbridge.ini
.\examples\sql\run.ps1 -Config config/examples/sqlite.ini
```

JSON continua aceito pelos mesmos comandos, trocando o nome do arquivo.
O launcher mínimo também aceita `-Config`. `-Port` e `-MaxWorkers` só
sobrepõem o arquivo quando informados; seus padrões pertencem ao servidor.

## Arquivo padrão

Sem `-config`, o executável procura **`hbbridge.ini` na sua própria pasta**.
Para o produto canônico, essa pasta é `out/`. Se o arquivo não existir,
usa os padrões do produto e os argumentos CLI. Um arquivo encontrado e
inválido impede o início; não é ignorado. Um `-config` explícito seleciona
outro arquivo em vez de mesclar os dois. Nenhum arquivo é criado pelo leitor.

Os exemplos ficam em [config/examples](../config/examples):
[hbbridge.ini](../config/examples/hbbridge.ini),
[sqlite.ini](../config/examples/sqlite.ini) e
[mssql.ini](../config/examples/mssql.ini), além dos equivalentes JSON.
Ao instalar um INI em outra pasta, ajuste seus caminhos relativos.

## Seções INI

A organização por seções segue o estilo dos arquivos AppServer/DBAccess
locais analisados; as chaves descrevem recursos próprios do hbBridge.

| Seção | Chaves |
| --- | --- |
| `[General]` | `MaxWorkers`, `AddonRoot` |
| `[Protheus]` | `Host`, `Port`, `MaxPayloadBytes`, `MaxWireBytes`, `ReadChunkBytes`, `TimeoutMs` |
| `[NETIO]` | `Host`, `Port`, `Root`, `Password`, `TimeoutMs` |
| `[Admin]` | `Host`, `Port`, `Password` |
| `[HTTP]` | `Enabled`, `Host`, `Port`, `Password`, `TLS`, `Certificate`, `PrivateKey` |
| `[SQL/profile_name]` | `Driver` e `Database` para SQLite; `Driver` e `ConnectionString` para MSSQL/ODBC |

Exemplo mínimo para o teste SQLite:

```ini
[Protheus]
Host=0.0.0.0
Port=1512

[SQL/sqlite_demo]
Driver=sqlite
Database=:memory:
```

NETIO mantém seus padrões `0.0.0.0:2941`; admin permanece desativada sem
senha. Os perfis são os mesmos consumidos por `RPCRDD.Query`. Para MSSQL:

```ini
[SQL/mssql_demo]
Driver=mssql
ConnectionString=DSN=hbBridgeMSSQL;Trusted_Connection=Yes;
```

Um INI com perfil MSSQL habilita o serviço, mas a consulta exige DSN/driver
ODBC disponíveis ao processo. O teste Protheus deve informar o perfil:

```powershell
.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

## Regras de leitura

Seções e chaves INI ignoram maiúsculas/minúsculas; o nome do perfil SQL mantém
sua caixa, como no JSON. Valores de `Driver` são normalizados para minúsculas.
Use `chave=valor`, sem aspas adicionais. Espaços/tabs externos são removidos;
os internos permanecem. Números são decimais canônicos e devem respeitar
a validação compartilhada. Senhas podem ser vazias para manter os padrões.

Comentários começam por `;` ou `#` no início da linha, após espaços.
Não há comentários inline: o texto após o primeiro `=` permanece inteiro,
incluindo `;`, `#` e outros `=`, necessários a strings ODBC e senhas.
São aceitos UTF-8 com BOM opcional, LF e CRLF.

Chaves/seções desconhecidas, repetições, linhas incompletas e `include`
são rejeitados com indicação da linha. O adaptador é estrito porque
`hb_iniReadStr` do Harbour remove comentários `#` inline, lê includes e
tolera certas linhas inválidas/repetições; essas regras não preservariam
todas as strings de conexão esperadas aqui.

Diretórios e arquivos SQLite relativos informados no arquivo são resolvidos
pela pasta desse arquivo. Diretórios relativos na CLI e padrões omitidos
continuam relativos ao diretório de trabalho; os launchers posicionam esse
diretório na raiz do projeto.

## Verificar antes de iniciar

```powershell
.\out\hbbridge.exe --config-info "-config=config/examples/sqlite.ini"
```

Esse comando valida a configuração e retorna metadados JSON de host/porta,
workers e nomes/drivers dos perfis. Não inicia listeners, não abre bancos nem
cria diretórios. Não imprime senhas, strings de conexão ou caminhos de dados.
Ele verifica o arquivo selecionado, não a configuração de um processo ativo.
O launcher SQL usa esse comando para INI, evitando outra implementação do
parser em PowerShell. Para JSON, a preparação anterior permanece compatível.
Em PowerShell, passe o argumento nativo `"-config=..."` entre aspas para
preservar caminhos com `/` e extensão. Os launchers já fazem isso.

INI não altera os limites: payload/rede padrão zero, buffer e prazos
operacionais seguem as mesmas regras do [Marco 2](milestone2-framing.pt-BR.md).
Os arquivos de configuração não implementam criptografia nesta etapa.

## Listener HTTP

`[HTTP]` é opcional e desativado por padrão, com bind em loopback
`127.0.0.1:8080`. Ative-o explicitamente com senha de serviço própria;
admin usa o adminPassword existente e precisa de senha diferente. JSON
usa as chaves `http*` equivalentes. HTTPS exige build hbssl/OpenSSL,
certificado e chave privada. Rotas, autorização, comportamento HTTP nativo
e dependências de build estão no [guia HTTP](http.pt-BR.md).

## Cliente Protheus no INI do AppServer

Adicione a seção abaixo ao arquivo usado pelo AppServer. O
[template](../config/examples/protheus-appserver.ini) contém essa mesma seção.

```ini
[hbBridge]
Host=127.0.0.1
Port=1512
TimeoutMs=30000
MaxPayloadBytes=0
MaxWireBytes=0
ReadChunkBytes=65536
; Padrão opcional da instalação; cada consulta pode escolher outro alias.
SQLProfile=
HTTPURL=http://127.0.0.1:8080
HTTPToken=
HTTPTimeoutSeconds=30
```

`Host`/`Port` indicam o endpoint Protheus do servidor hbBridge. Use seu IP
ou DNS; `0.0.0.0` serve ao bind do servidor, não é destino do cliente.
`SQLProfile` seleciona um alias declarado no INI/JSON do hbBridge; a conexão
ODBC e as credenciais do banco permanecem naquele servidor.
É opcional e vazio por padrão. Cada consulta/dataset pode informar outro
alias, como `mssql/pData`; `sqlite_demo` pertence somente ao exemplo SQLite.
Sem perfil explícito nem configuração, o teste retorna `PROFILE_REQUIRED`
antes do acesso à rede. Aliases são opacos e preservam maiúsculas/minúsculas;
não resolvem tenant, empresa, filial/xFilial ou tabelas físicas do Protheus.
Veja [arquitetura](architecture.pt-BR.md).

`TimeoutMs` mantém o prazo positivo do cliente. Payload/rede em `0` não
acrescentam tetos de aplicação; valores positivos ativam políticas locais.
`ReadChunkBytes` dimensiona uma chamada de socket, respeitando a capacidade
nativa de inteiro assinado de 32 bits. `MAXSTRINGSIZE` e a memória do AppServer
continuam condicionando a transferência; descoberta/negociação e blocos
ainda serão implementados. Nenhum valor é derivado automaticamente de
`MAXSTRINGSIZE` nesta entrega.

`HBBridgeHTTPClient` lê separadamente `HTTPURL`, o `HTTPToken` obrigatório e
`HTTPTimeoutSeconds` (inteiro positivo, padrão 30 segundos). O token coincide
com `[HTTP] Password` no servidor; não é credencial de banco/administração.
Argumentos omitidos leem o INI ativo; argumentos explícitos prevalecem.
O timeout HTTP nativo difere de `TimeoutMs` TCP; não aplica frame TCP, gzip
nem budgets do socket. Veja o [exemplo TLPP](../examples/http/README.pt-BR.md).

A classe estática [HBBridgeConfig](../src/tlpp/hbbridgeconfig.tlpp), no namespace
`HBBridge.Client`, usa `GetSrvIniName()` para selecionar inclusive um nome
de INI customizado e `GetPvProfString()` para ler a seção. A seleção nativa
do arquivo é descrita no [TDN](https://tdn.totvs.com/display/tec/GetSrvIniName).
A precedência cliente é **padrões < seção INI < argumentos explícitos**;
seção/chaves ausentes mantêm os padrões. Números inválidos, portas fora da
faixa e valores obrigatórios vazios são recusados com `INVALID_CONFIGURATION` antes de
abrir o socket. Um argumento explícito válido pode substituir um valor INI
inválido da mesma chave.

```tlpp
// Uses [hbBridge] from the INI of this AppServer.
oClient := HBBridge.Client.HBBridgeClient():New()
// Overrides Host/Port; the other settings still come from the INI.
oClient := HBBridge.Client.HBBridgeClient():New("bridge.example.local", 1512)
```

Cada novo cliente guarda uma cópia dos valores lidos; objetos existentes
mantêm sua configuração. Os testes `U_HBBridgeConnectionTest()` e
`U_HBBridgeQueryTest()` sem argumentos seguem a seção, incluindo o alias
SQL. `U_HBBridgeConfigTest()` verifica resolução/precedência e erros sem
executar SQL. O launcher do servidor não altera o INI do AppServer.

A seção foi acrescentada ao `appserver.ini` local com cópia anterior em
`tmp`, preservando os bytes já existentes. A compilação via
`scripts/build-totvs.cmd` não começou porque a parada dos processos TOTVS
falhou naquela tentativa do agente. Posteriormente, o operador informou
sucesso nos três testes na sessão de 2026-10-04: configuração com 13 checks
verdadeiros, incluindo `activeAppServerIni`; relógio Windows/Health/ADDON/Echo;
e SQLite paginado com 29 checks verdadeiros. O aceite da configuração
cliente está registrado em [homologação](acceptance.pt-BR.md).

Não foram informados argumentos da chamada, valores efetivos de Host/Port,
horário/thread, hash dos artefatos nem log de compilação dessa rodada.
O check do INI ativo confirma a leitura válida; destino diferente dos
padrões e chamada sem argumentos precisam ser identificados em rodada
própria. As 412 verificações Harbour daquela rodada permanecem um resultado
independente. A validação gerenciada posterior teve 416 checks em 2026-10-04;
renomes de classes e os 16 checks revisados ainda exigem novo aceite Protheus.
