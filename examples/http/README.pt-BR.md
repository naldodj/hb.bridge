# Consumo HTTP do hbBridge em TLPP

[English](README.md)

O [cliente HTTP](../../src/tlpp/hbbridgehttpclient.tlpp) disponibiliza
`HBBridge.Client.HBBridgeHTTPClient` usando o `FWRest` nativo do Protheus.
O [teste Protheus](../../src/tlpp/tests/protheus/hbbridgehttptest.tlpp)
exercita os mesmos serviços hbBridge usados pelo Harbour e pelo cliente TCP.
HTTP usa JSON UTF-8 e autenticação bearer; não usa o frame TCP
`HBBRIDGE/1` nem gzip. Consulte [o contrato HTTP](../../docs/http.pt-BR.md).

## Configurar e iniciar o servidor

HTTP vem desabilitado. Faça uma cópia privada de
[sqlite.ini](../../config/examples/sqlite.ini), mantendo sua seção SQL,
e acrescente:

```ini
[HTTP]
Enabled=true
Host=127.0.0.1
Port=8080
Password=<service-secret>
TLS=false
```

Substitua o marcador por seu próprio segredo. Este exemplo não precisa da
seção `[Admin]`: a autenticação bearer dos serviços é separada da administração
web. Compile o produto atual e inicie pela raiz do repositório, informando
o caminho da configuração privada:

```powershell
./scripts/build-hbbridge.ps1
./scripts/run-hbbridge.ps1 -Config tmp/http.ini
```

O caminho `tmp/http.ini` acima pressupõe que você salvou a cópia privada ali.
Pare uma instância anterior antes de reutilizar suas portas. Para uso remoto,
utilize destino HTTPS com instalação TLS ou proxy reverso homologado;
HTTP simples em loopback atende ao exemplo local.

## Configurar o cliente Protheus

Acrescente estas chaves à seção `[hbBridge]` existente no INI do AppServer
ativo, ou crie a seção se estiver ausente. Não duplique a seção.

```ini
[hbBridge]
HTTPURL=http://127.0.0.1:8080
HTTPToken=<service-secret>
HTTPTimeoutSeconds=30
SQLProfile=sqlite_demo
```

`HTTPToken` deve coincidir com `[HTTP] Password` no servidor; não existe
segredo padrão. Argumentos omitidos do construtor/teste leem essas configurações.
Argumentos explícitos prevalecem. A URL padrão é `http://127.0.0.1:8080`, e
o timeout padrão é 30 **segundos**, independente do `TimeoutMs` do TCP.
O timeout configura a operação HTTP nativa; não é um prazo monotônico para
toda a chamada, serialização JSON e processamento local.

`SQLProfile=sqlite_demo` seleciona apenas o perfil deste exemplo. Você pode
informar outro alias opaco, como `mssql/pData`, se estiver configurado no
servidor. A biblioteca não exige um perfil SQL fixo. O Protheus fornece
explicitamente SQL, nomes físicos de tabelas e regras de tenant, empresa e filial.

## Compilar e executar o exemplo

Compile toda a árvore `src/tlpp/`, incluindo cliente e teste, com
a configuração do SDK TOTVS definida pelo operador:

```powershell
$env:HBBRIDGE_TOTVS_APPSERVER_DIR = '<your-appserver-directory>'
$env:HBBRIDGE_TOTVS_INCLUDES = '<your-totvs-includes>'
$env:HBBRIDGE_TOTVS_ENV = 'PROTHEUS'
./scripts/build-totvs.cmd
```

Consulte [a compilação TOTVS](../../scripts/README.pt-BR.md) para
scripts de serviço e logs de compilação. Execute
[U_HBBridgeHTTPTest no WebApp](https://localhost:4321/webapp/?p=U_HBBridgeHTTPTest&e=PROTHEUS)
após alinhar o INI do AppServer ativo, ou invoque com valores explícitos:

```advpl
U_HBBridgeHTTPTest("http://127.0.0.1:8080", "<service-secret>", 30, "sqlite_demo")
```

Os argumentos são URL, token do serviço, timeout em segundos, perfil SQL e
módulo addon. O perfil SQL omitido usa `[hbBridge] SQLProfile`; quarto argumento
explicitamente vazio pula SQL. O addon padrão é
`examples/hbbridgesampleaddon.hb` no **servidor**, e quinto argumento
explicitamente vazio pula sua execução. Para serviços sem essas fixtures:

```advpl
U_HBBridgeHTTPTest("http://127.0.0.1:8080", "<service-secret>", 30, "", "")
```

## Reutilizar o cliente em um método

Dentro de um método TLPP, use objetos para os parâmetros e o resultado:

```advpl
    local oClient := HBBridge.Client.HBBridgeHTTPClient():New() as object
    local jParams := JSONObject():New() as json
    local jResponse as json

    jParams["message"] := "Protheus HTTP example"
    jResponse := oClient:CallService("Echo", jParams)
    ConOut("HTTP status: " + CValToChar(oClient:StatusCode()))
    ConOut(jResponse:ToJSON())

    FreeObj(@jResponse)
    FreeObj(@jParams)
    FreeObj(@oClient)
```

`Health()` faz GET `/api/v1/health`; `Services()` faz GET
`/api/v1/services`. `CallService()` envia o envelope service/params/version
por POST para `/api/v1/rpc`. Examine `success`, `code` e `error` do resultado
junto com `StatusCode()`. Os casos 403 e 404 homologados preservaram o
erro JSON estruturado do servidor. No 401, a LIB Protheus testada informou
`FWRest:cInternalError` como `UNAUTHORIZED`, enquanto `GetHTTPCode()` retornou
zero. O cliente normaliza essa condição para status 401 e falha local
`UNAUTHORIZED`; esse tratamento não preserva o JSON do servidor para o 401.

O cliente usa `FWRest:SetChkStatus(.F.)` para examinar o código HTTP
diretamente, conforme [a documentação TOTVS do FWRest](https://tdn.totvs.com/display/framework/FWRest).
Apenas a API nativa de cabeçalhos exige array; parâmetros e resultados
usam `JSONObject`. O `FWRest` fornece o enquadramento HTTP e o content length.

Forneça textos dos parâmetros na codificação do AppServer. O cliente aplica
`EncodeUTF8()` uma vez ao request completo serializado; não pré-codifique
valores individuais dos parâmetros. O JSON da resposta é interpretado sem
recodificar todo o corpo, preservando os textos UTF-8 recebidos. Use
`DecodeUTF8()` em um campo textual específico ao compará-lo com texto local
do AppServer ou exibi-lo nessa codificação. O Echo homologado decodifica
somente o campo acentuado para comparação; não comprova todas as combinações
de Unicode e codepage.

O mesmo cliente pode atender ao dataset paginado existente:

```advpl
    local oClient := HBBridge.Client.HBBridgeHTTPClient():New() as object
    local oDataSet := HBBridge.RDD.HBBridgeRPCDataSet():New(oClient) as object

    if oDataSet:OpenPage("sqlite_demo", "SELECT 1 AS ID", 1, 10, "ID")
        ConOut("ID: " + CValToChar(oDataSet:FieldGet("ID")))
    else
        ConOut(oDataSet:ErrorCode() + ": " + oDataSet:ErrorMessage())
    endif

    oDataSet:Close()
    FreeObj(@oDataSet)
    FreeObj(@oClient)
```

`NextPage()` e `HasNextPage()` mantêm o contrato do dataset existente.
A query acima é um SELECT de constante, sem escrita em tabelas Protheus.

## Homologação do operador

Em **2026-10-07**, o operador compilou/ajustou os fontes e executou
`U_HBBridgeHTTPTest` no AppServer, thread **25672**. O programa iniciou às
15:16:12 e o teste ocorreu de **15:16:14 a 15:16:15**. Todas as **13 verificações**
retornaram verdadeiro: Health por GET/POST, descoberta de serviços, Echo de
200.000 bytes com comparação do acento, addon, serviço inexistente (404),
administração proibida (403), token inválido (401 normalizado), recuperação
após falha e duas páginas de query com seus valores.

A saída fornecida não identifica o alias SQL nem o SGBD. Ela confirma a
paginação no perfil selecionado e não comprova homologação MSSQL.
Cobertura ampla de Unicode/codepages, HTTPS e configurações alternativas do
cliente continuam pendentes. Consulte [o registro de homologação](../../docs/acceptance.pt-BR.md).

Após informar recompilação posterior à migração Harbour `.hb`, o operador
repetiu todas as **13 verificações com sucesso** na mesma data: thread
**27296**, teste **16:10:44–16:10:45**, e thread **25456**, teste
**16:15:03–16:15:04**. Horários de São Paulo; ambas as execuções duraram um
segundo, com Health HTTP 200, addon e valores paginados aprovados. São relatos
do operador, sem execução AppServer pelo agente nem log do compilador fornecido.
O teste Query acompanhante identifica `sqlite_demo`; os relatos HTTP não
identificam seu próprio SGBD nem o argumento real do módulo. Homologação MSSQL
continua separada; a [matriz](../../docs/acceptance.pt-BR.md) registra o escopo exato.
