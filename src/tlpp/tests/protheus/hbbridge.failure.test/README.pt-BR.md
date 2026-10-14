# Falhas MSSQL controladas e recuperação

[English](README.md) · [Catálogo de testes](../../../../../tests/README.pt-BR.md) · [Homologação](../../../../../docs/acceptance.pt-BR.md)

`HBBridge.Test.HBBridgeFailureTest` exercita o serviço SQL real pelos clientes
TCP e HTTP do Protheus. Verifica SQL inválido, alias desconhecido, conexão
indisponível e, quando informado um perfil explícito de timeout, o timeout
nativo de uma instrução SQL. Cada falha deve retornar erro sanitizado,
nenhum resultado parcial e recuperação imediata com
`SELECT 77 AS RECOVERY_ID`. Os checks do dataset também exigem limpar as
linhas/metadados anteriores, retornar falso em `MoreToRead()` após a falha e
reabrir com sucesso.

## Configurar o hbBridge normal para testes manuais

Os perfis SQL são definidos no **INI lido pelo servidor hbBridge**. No
ambiente local, o comando `out/hbbridge.exe -config="C:/tmp/hbbridge.ini"`
seleciona `C:/tmp/hbbridge.ini`. As seções ficam nesse arquivo:
`[SQL/m06/refused]` e `[SQL/m06/query-timeout]`.

O `appserver.ini` configura o cliente na seção `[hbBridge]`: `Host`, `Port`,
`TimeoutMs`, `HTTPURL`, `HTTPToken`, `HTTPTimeoutSeconds` e `SQLProfile`.
Não é nele que se definem as conexões SQL dos dois perfis. Os testes enviam
os aliases como parâmetros ao servidor escolhido por esses endpoints.

1. Duplique **toda** a seção funcional `[SQL/MSSQL/pData]` no INI privado
   do hbBridge, mantendo suas chaves de conexão, autenticação e TLS. Renomeie
   somente o cabeçalho da cópia para `[SQL/m06/query-timeout]`. Acrescente ou
   atualize na cópia estas chaves, cujos valores são segundos:

   ```ini
   LoginTimeoutSeconds=2
   QueryTimeoutSeconds=1
   ```

   A implementação atual não tem herança de perfis: somente o nome da seção
   e os timeouts mudam; as demais chaves precisam estar presentes na cópia.
   Preserve a seção original para as consultas de baseline/recuperação.

2. Acrescente outra seção para uma conexão local deliberadamente recusada:

   ```ini
   [SQL/m06/refused]
   Driver=mssql
   ODBCDriver=ODBC Driver 18 for SQL Server
   Server=tcp:127.0.0.1,65534
   Database=master
   Authentication=sql
   Username=m06-fictitious-user
   Password=m06-fictitious-secret
   Encrypt=optional
   LoginTimeoutSeconds=1
   QueryTimeoutSeconds=1
   ```

   `65534` é uma porta de exemplo: confirme que não existe listener nessa
   porta local, ou substitua por outra porta sem listener. As credenciais
   dessa seção são fictícias. O driver deve estar instalado. Por exemplo,
   `Get-NetTCPConnection -LocalPort 65534 -State Listen -ErrorAction SilentlyContinue`
   mostra um listener existente; se houver resultado, escolha outra porta.
   O launcher isolado abaixo garante a reserva da porta durante o teste.

3. Reinicie o hbBridge normal usando o arquivo alterado:

   ```powershell
   .\out\hbbridge.exe -config="C:\tmp\hbbridge.ini"
   ```

   O INI é carregado na inicialização. Alterar o arquivo com o processo
   ativo não adiciona os perfis à configuração já carregada.

4. No Protheus, mantenha os endpoints reais desse hbBridge na seção
   `[hbBridge]` do `appserver.ini`. `SQLProfile=MSSQL/pData` continua sendo
   o perfil funcional. `U_HBBridgeTCPAndHTTPFailureTest()` já passa
   `m06/refused` e `m06/query-timeout` aos testes; seus nomes devem coincidir
   exatamente com as seções do INI do servidor.

Esse procedimento usa o executável normal e seus endpoints. A modalidade
`-Failures -Serve` a seguir cria outro host de teste, com perfis em memória
e portas próprias, sem acrescentar essas seções ao INI privado.

## Preparar o host isolado

Use um perfil MSSQL funcional de um arquivo de configuração privado:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData `
    -Failures -FailureODBCDriver 'ODBC Driver 18 for SQL Server' -Serve
```

`MSSQL/pData` é um alias explícito de exemplo; substitua pelo alias funcional
configurado. O driver ODBC informado deve estar instalado na arquitetura
do processo de teste. O runner lê o arquivo privado sem alterá-lo nem copiar
credenciais para o repositório. Cria os seguintes perfis em memória:

| Perfil | Finalidade |
| --- | --- |
| Alias funcional explícito | Conexão MSSQL real, timeout de login de 2 segundos e de instrução de 5 segundos. |
| `m06/refused` | Porta de loopback reservada sem escuta, credenciais fictícias e timeouts de login/instrução de 1 segundo. |
| `m06/query-timeout` | Conexão funcional com timeout de instrução de 1 segundo. |

O host usa portas de teste separadas em loopback para TCP, NETIO e HTTP.
As portas TCP/HTTP são exibidas após a aprovação dos checks nativos;
use essas portas nas chamadas Protheus. O token HTTP
`m06-http-test-only` pertence apenas à fixture. Nenhuma tabela ERP nem
serviço SQL Server é alterado.

A fixture executa primeiro os 46 checks nativos e permanece disponível por
**600 segundos**, ou até Esc/Ctrl+Q. Esse é o tempo de vida do host de teste,
não um limite do produto. Omita `-Serve` para validar a rota nativa e liberar
os recursos em seguida. Saída 2 indica falha de pré-requisito; saída 1,
falha de checks/runtime; saída 0 sucede checks aprovados e limpeza.

## Compilar os fontes Protheus

Compile toda a árvore `src/tlpp`, incluindo os dois arquivos deste diretório.
Para a instalação local licenciada do AppServer, execute em um prompt de
comando administrativo, a partir da raiz do projeto:

```bat
C:\totvs\stop-totvs.bat
scripts\build-totvs.cmd "C:\totvs\protheus1212410\protheus\bin\appserver" "C:\totvs\includes;F:\GitHub\hb.bridge\includes" "PROTHEUS"
C:\totvs\start-totvs.bat
```

Ajuste os caminhos de instalação/includes para outra máquina. Restaure o
AppServer após a tentativa de compilação, inclusive quando ela falhar.
O ciclo stop/build/start se refere ao runtime TOTVS local; não para MSSQL.
Inicie a fixture hbBridge isolada depois da compilação para aproveitar a
janela de 600 segundos nas chamadas de teste.

## Chamadas diretas

As assinaturas publicadas dos testes são:

```tlpp
U_HBBridgeFailureTest(cWorkingProfile, cUnavailableProfile, cHost, nPort, nTimeout, cTimeoutProfile)
U_HBBridgeHTTPFailureTest(cWorkingProfile, cUnavailableProfile, cURL, cToken, nTimeoutSeconds, cTimeoutProfile)
```

`nTimeout` usa milissegundos no TCP; `nTimeoutSeconds` usa segundos no HTTP.
Configurações de transporte omitidas usam a seção `[hbBridge]` do AppServer
ativo. Os aliases funcional e indisponível são obrigatórios e distintos.
O perfil final de timeout é opcional e também deve ser distinto. No host
isolado, use as portas exibidas e inclua o alias de timeout:

```tlpp
U_HBBridgeFailureTest("MSSQL/pData", "m06/refused", "127.0.0.1", nTCPPort, 7000, "m06/query-timeout")
U_HBBridgeHTTPFailureTest("MSSQL/pData", "m06/refused", "http://127.0.0.1:" + cHTTPPort, "m06-http-test-only", 7, "m06/query-timeout")
```

Os casos completos de timeout esperam **38 checks TCP** e **51 checks HTTP**,
com zero falhas e 21 chamadas ao serviço por transporte. Omitir o perfil
final executa **29 checks TCP** e **39 checks HTTP**, com 16 chamadas em cada
um, sem homologar o timeout nativo de instrução. As falhas do serviço HTTP
devem retornar status 500, seguido de status 200 na recuperação.

A fixture de timeout executa a instrução com duração limitada
`WAITFOR DELAY '00:00:04'; SELECT 77 AS RECOVERY_ID`. A chamada direta ao
serviço deve falhar após pelo menos 500 ms e antes de 4000 ms. Mantenha o
timeout de transporte do cliente em pelo menos 7 segundos para que um prazo
do transporte não substitua o timeout SQL nativo de 1 segundo.

## Chamadas pela linha de comando

A entrada compilada `U_HBBridgeFailureCLI` recebe argumentos nomeados pelo
`-run` do AppServer. Um `hbm06.ini` privado separado pode preservar as seções
de ambiente, RPO, licença e banco da instalação, omitindo `OnStart` e
listeners HTTP. Sua configuração nativa de drivers deve incluir
`[Drivers] Active=TCP` e `[TCP] TYPE=TCPIP`, com `PORT` definido para uma
porta livre. Assim o `appserver.ini` permanente é preservado. Execute em
`cmd.exe` a partir do diretório do AppServer, substituindo as portas de teste:

```bat
appserver.exe -ini="hbm06.ini" -run=U_HBBridgeFailureCLI -env=PROTHEUS --transport=tcp --working-profile=MSSQL/pData --unavailable-profile=m06/refused --timeout-profile=m06/query-timeout --host=127.0.0.1 --port=<tcp-port> --timeout=7
appserver.exe -ini="hbm06.ini" -run=U_HBBridgeFailureCLI -env=PROTHEUS --transport=http --working-profile=MSSQL/pData --unavailable-profile=m06/refused --timeout-profile=m06/query-timeout --url=http://127.0.0.1:<http-port> --token=m06-http-test-only --timeout=7
```

Preserve as aspas no valor de `-ini`: o parser AppServer testado removeu a
extensão do arquivo quando o valor não estava entre aspas. As configurações
nativas de `Drivers` continuam obrigatórias nesse runtime mesmo usando
somente `-run`.

`--timeout` usa segundos nos dois transportes CLI e tem padrão 7. O transporte
tem padrão `tcp`; `--timeout-profile` pode ser omitido. Flags reconhecidas
devem ser únicas e não vazias; porta/timeout devem ser números decimais
inteiros positivos. Argumentos do próprio AppServer são ignorados.
Retorno 0 indica todos os checks aprovados; retorno 1 indica argumentos
inválidos, falha do baseline ou checks reprovados. Use o relatório final
`controlled failure checks` do console para registrar o resultado real.

`RunCLI()` utiliza o array nativo `Variadic:vArgs` sem copiá-lo; esse array é
exigido pela interface AppServer. Casos/configurações/resultados permanecem
em `JSONObject`. Arrays temporários de nomes são exigidos pela API nativa
`JSONObject:GetNames()`.

## Escopo e evidências

Em **2026-10-14**, a validação nativa MSSQL real passou em **46 checks, zero
falhas e nenhum skip**, cobrindo chamadas diretas ao núcleo, NETIO, TCP e
HTTP: `tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`.
A regressão padrão gerenciada passou em **636 checks, zero falhas e nenhum
skip**: `tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`.
O relatório do compilador às **08:23:38 de São Paulo**, thread **32272**,
registrou **30 fontes compilados com sucesso e zero erros**, incluindo esta
classe e entrada, atualizando o `custom.rpo` real: `tmp/totvs-compile.log`.
Rodadas automatizadas posteriores via CLI AppServer executaram o RPO
compilado contra o host isolado MSSQL real, incluindo o perfil opcional de
timeout:

| Transporte | Horário de São Paulo em 2026-10-14 | Thread | Resultado | Log |
| --- | --- | --- | --- | --- |
| TCP | 08:28:56–08:29:12 | 29120 | 38 checks, zero falhas; saída 0 | `tmp/m06-protheus-tcp-clean-output-20261014.log` |
| HTTP | 08:28:13–08:28:29 | 21392 | 51 checks, zero falhas; saída 0 | `tmp/m06-protheus-http-output-20261014.log` |

São checks do runtime Protheus real via `-run`, sem homologação manual de
SmartClient/WebApp ou interface gráfica. O dataset real verifica estado
limpo e `MoreToRead()` falso após a falha; o mock de dataset separado,
homologado com 67 checks, verifica as contagens e a ausência de novas tentativas.

O timeout ODBC se aplica a cada instrução nativa, incluindo consulta/contagem;
o timeout de login é um atributo separado da conexão. Essas opções não
implementam um prazo compartilhado da requisição, cancelamento explícito
no servidor nem cancelamento SQL por desconexão do cliente. O teste não
homologa bloqueios prolongados de rede, parada/reinício do servidor,
integridade arbitrária UTF-8/FLOAT nem inferência de escala de negócio.
A integridade ampliada permanece no [WIP](../../../../../WIP.pt-BR.md).

## Perfis da fixture ausentes

Sete falhas por transporte podem ocorrer quando faltam `m06/refused` e
`m06/query-timeout` no host comum: retorna `PROFILE_NOT_FOUND` em vez da
falha de conexão/consulta esperada. Usar `-Failures -Serve` e os endpoints
informados pelo launcher. Seus perfis existem somente naquele processo.
O teste informa esse pré-requisito e não imprime parâmetros/tokens.
`U_HBBridgeTCPAndHTTPFailureTest()` usa endpoints e perfil SQL do INI ativo
do AppServer (com fallback nativo `FWGetTopInfo()`); não cria fixtures no
servidor. Para usá-lo no host isolado, configurar seu cliente com os endpoints
informados ou usar os wrappers explícitos acima.

Após o ajuste de diagnóstico/logs, a recompilação em 2026-10-14 às 13:09:29
São Paulo registrou 30 fontes/zero erros de fonte. As novas rodadas CLI
TCP 38 e HTTP 51 checks passaram com saída 0; logs:
`tmp/m06-protheus-tcp-updated-output-20261014.log` e
`tmp/m06-protheus-http-updated-output-20261014.log`. O compilador ainda
encerra com 0xC0000409 após seu relatório concluído de build; os processos
CLI posteriores executam o RPO compilado e encerram normalmente. As rodadas
anteriores no host comum (TCP 38/7 e HTTP 51/7) são falhas históricas de
pré-requisito; a rodada manual confirmada abaixo as resolve. Veja o [registro](../../../../../docs/acceptance.pt-BR.md#sql-native-timeouts-and-appserver-recovery-on-2026-10-14).

## Validação manual confirmada

Em 2026-10-14 às **14:30:50 São Paulo**, `U_HBBridgeTCPAndHTTPFailureTest`,
thread **13796**, aprovou todos os **38 checks TCP e 51 HTTP**, sem falhas
reportadas. Homologados os casos manuais listados de falha/recuperação,
resolvendo as sete falhas anteriores por transporte. Evidência:
`tmp/protheus-failure-manual-20261014-143050.log`. Veja o
[registro manual](../../../../../docs/acceptance.pt-BR.md#manual-protheus-failure-recovery-on-2026-10-14).
Diagnósticos nativos de handshake permanecem registrados sem causa/resolução
comprovada; a rodada não homologa TLS/HTTPS sem falhas, duração precisa, forma
de acionamento por interface gráfica, concorrência nem integridade UTF-8/FLOAT ampliada.
