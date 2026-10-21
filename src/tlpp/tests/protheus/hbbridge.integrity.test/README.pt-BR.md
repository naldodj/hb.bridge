# Integridade textual e numérica MSSQL no Protheus

[English](README.md) · [Contrato do dataset](../../../../../docs/dataset.pt-BR.md) · [Aceite](../../../../../docs/acceptance.pt-BR.md)

`HBBridge.Test.HBBridgeIntegrityTest` exercita os clientes TCP/HTTP do produto
e `HBBridgeRPCDataSet` com a fixture somente leitura `d03.mssql.constants.v1`.
Informar explicitamente um alias de perfil MSSQL configurado. As consultas
usam constantes e não leem nem alteram tabelas de negócio ERP. O teste não
inicia listeners nem modifica os INIs hbBridge/AppServer.

Compilar este diretório com toda a árvore `src/tlpp` atual, incluindo
`HBBridgeJSON`, ambos os clientes e dataset, usando SDK/includes do AppServer de destino. O hbBridge de
destino precisa incluir a implementação atual de transporte/números e o patch
ODBC gerenciado. Veja o [script de compilação](../../../../../scripts/build-totvs.cmd).
A execução AppServer registrada em 2026-10-21 passou em **80 checks, zero
falhas**; seu escopo exato e a rodada fechada separada do helper JSON estão abaixo.

## Preparar um destino MSSQL isolado

Usar um perfil funcional existente na configuração privada hbBridge:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:\tmp\hbbridge.ini -Profile MSSQL/pData -Integrity -Serve
```

`MSSQL/pData` é exemplo de alias opaco; usar exatamente o alias configurado
nesse arquivo. O launcher compila os componentes gerenciados, executa os
checks nativos de integridade e, quando aprovados, mantém seus próprios
listeners TCP/HTTP em loopback. Lê a configuração privada sem alterá-la nem
expor credenciais SQL. Esse host não exige reinício dos serviços existentes.

O diretório da execução informado contém `endpoints.json`: usar `profile`,
`tcpPort`, `httpPort` e `httpToken`, restrito à fixture. Montar a URL HTTP como
`http://127.0.0.1:<httpPort>`. Criar `d03.stop` nesse mesmo diretório para
encerrar o host próprio após o teste; ele também encerra após no máximo dez
minutos. O resultado nativo final é separado do resultado AppServer posterior.

## Executar no Protheus

O wrapper público encaminha para `HBBridgeIntegrityTest():Run()`:

```tlpp
nResult := U_HBBridgeIntegrityTest(cProfile, cHost, nPort, cURL, cToken, nTimeoutSeconds)
```

Os argumentos são perfil MSSQL explícito, host/porta TCP, URL base/token HTTP
e timeout por requisição em segundos. Somente o perfil é obrigatório. Quando
omitidos, host/porta/URL/token usam a configuração cliente `[hbBridge]` do
AppServer; não configuram a conexão SQL. O timeout padrão é 30 segundos e
aceita inteiro positivo até 2147483. Vale por requisição, sem limitar a duração
total do teste.

Para o host isolado, fornecer os valores de seu `endpoints.json`. Para um
destino já configurado:

```tlpp
nResult := U_HBBridgeIntegrityTest("MSSQL/pData")
// Entrada equivalente da classe:
nResult := HBBridge.Test.HBBridgeIntegrityTest():Run("MSSQL/pData")
```

Em ambiente CLI AppServer licenciado, usar INI CLI privado ao lado do
executável. Substituir `TCP_PORT` e `HTTP_PORT` pelas portas do host isolado
e informar o token efetivo da fixture:

```bat
appserver.exe -ini="private-integrity.ini" -run=U_HBBridgeIntegrityCLI -env=PROTHEUS --profile=MSSQL/pData --host=127.0.0.1 --port=TCP_PORT --url=http://127.0.0.1:HTTP_PORT --token=d03-http-test-only --timeout=30
```

O wrapper encaminha o array nativo de argumentos para `RunCLI(aArguments)`.
Flags aceitas: `--profile`, `--host`, `--port`, `--url`, `--token` e `--timeout`,
em entradas únicas `--nome=valor`. Porta/timeout usam notação decimal inteira
canônica. Argumentos inválidos ou checks reprovados retornam 1; aprovação de
todos os checks retorna 0. Preservar o JSON `hbBridge integrity summary:` e a
linha final `hbBridge integrity Protheus OK/FAILED` como evidência runtime.

## Fronteiras verificadas e limites

- Checks do parser distinguem JSON UTF-8 direto de escapes Unicode e verificam
  conversões explícitas CP1252/UTF-8. Echo cobre acentos, euro, texto longo,
  NUL, vazio/null, texto de escape literal e entradas do chamador inalteradas
  pelos dois clientes.
- SQL/dataset cobre FLOAT fracionário/negativo, magnitudes pequenas/grandes,
  check numérico de 15 dígitos significativos, escalas DECIMAL declaradas,
  VARCHAR acentuado, Unicode fora de CP1252, par substituto em fronteira de
  blocos ODBC, NUL/vazio/null, EOF e fechamento TCP próprio. NUL também é
  verificado nas cópias defensivas `GetRow()`/`GetRows()`. HTTP verifica status 200.
- Valores TLPP nativos `N` usam tolerâncias explícitas; os checks de magnitude
  pequena/grande normalizam os valores perto de um. Isso não promete preservar
  todos os bits binary64 pelo parser JSON AppServer. Checks do codec nativo têm
  escopo separado. CAST do chamador define escala de negócio; não se deduz SX3.
  `DEC_CREATE()` retorna outro tipo decimal fixo e não é usado para ocultar
  precisão já perdida ao interpretar um número JSON.
- `EXACT_TEXT` projeta `DECIMAL(30,10)` como texto e deve preservar exatamente
  `12345678901234567890.1234567890`. Converter essa string para número nativo
  está fora da asserção e pode perder dígitos.
- `BINARY_HEX` projeta VARBINARY explicitamente como texto hexadecimal e espera
  `0001FF007F`. O teste não envia binário bruto em JSON nem presume encoding
  binário automático. Checks nativos de integridade verificam separadamente
  leitura dos bytes brutos e recusa de transporte `BINARY_JSON_UNSUPPORTED`.

Entradas são texto comum AppServer, CP1252 nestas fixtures. Os clientes
codificam a requisição textual uma vez para UTF-8. O retorno bruto é conferido
em UTF-8; um valor acentuado representável passa depois por uma conversão
`DecodeUTF8(cText, "cp1252")` para a asserção do consumidor. Valores fora de
CP1252 permanecem UTF-8, sem forçar essa conversão. A conversão de parser/canal
deve ter responsável explícito único para evitar duplicidade. Nenhuma dessas
conversões textuais se aplica a binários nem corrige serialização numérica.

## Falha NUL nativa do AppServer e helper de compatibilidade

No AppServer testado, a propriedade direta preserva `A` + `Chr(0)` + `B`, mas
o `ToJSON()` nativo trunca seus bytes de `410042` para `41`. O `FromJSON()`
nativo remove NUL escapado em `"A\u0000B"`, retornando `4142`.
A reprodução independente está registrada na
[issue Protheus 14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
Isso é separado da conversão UTF-8 e não pode ser reparado por `DecodeUTF8()`.

`HBBridge.Client.HBBridgeJSON():Encode()`/`:Parse()` agora preservam NUL em
valores dos dois clientes e nas cópias do dataset. O helper mantém semântica
numérica nativa, não converte codepages e distingue escapes `\u0000` reais
de texto de escape literal. Nomes de propriedade com NUL são recusados
explicitamente. A codificação comum ainda percorre os valores para detectar
NUL antes da serialização nativa, adicionando varredura linear/enumeração de chaves.

A regressão fechada do helper não precisa de SQL nem de destino hbBridge:

```tlpp
nResult := U_HBBridgeJSONTest()
```

Exercita serialização comum, fronteiras/repetição de NUL, objetos/arrays
aninhados, Unicode e outros escapes, preservação de escape literal e das
entradas, além de entradas inválidas/não suportadas. Manter sua contagem e
resultado separados de `U_HBBridgeIntegrityTest()`.

## Aceite registrado

Em **2026-10-21**, Windows AppServer **24.3.1.5**, com RPO privado isolado,
passou na fixture MSSQL pelos clientes TCP/HTTP do produto: **80 checks, zero
falhas**, códigos de saída cliente/servidor 0. Recibo:
`tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`.
SHA-256 do artefato servidor nativo:
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
A rodada fechada separada do helper JSON passou em **31 checks, zero falhas**:
`tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.

As rodadas nativas anteriores de **2026-10-19** passaram em 752 checks genéricos,
73 checks de integridade MSSQL, 92 checks MSSQL existentes, 7 checks de referência
.NET ODBC independentes e 2 checks numéricos Zig, todos sem falhas. Complementam
a evidência AppServer, sem substituí-la. A correção ODBC gerenciada inclui
caracteres suplementares na entrada SQL UTF-8, além da decodificação da saída.

Os resultados homologam D03 na fixture/runtime demonstrados. Não certificam
Linux, outros drivers ODBC, BLOB bruto em JSON nem precisão binary64 nativa
completa no Protheus. Dígitos grandes exatos permanecem projeções SQL textuais
explícitas; CAST do chamador continua como opção para escala de negócio.
Extensões de metadados lógicos permanecem futuras.

Os checks homologam somente o runtime e a fixture registrados. Preservar
SQL Server, driver, identidade de fontes/binário/RPO, configuração cliente,
contagens finais e código de saída nas evidências. Campos de negócio como
`RA_SALARIO`, outras codepages consumidoras, faixas decimais ampliadas e o
fechamento do pacote mantêm seus próprios critérios no [WIP ativo](../../../../../WIP.pt-BR.md).
