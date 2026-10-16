# Isolamento concorrente de perfis pelo Protheus

[English](README.md) · [Catálogo de testes](../../../../../tests/README.pt-BR.md) · [Aceitação](../../../../../docs/acceptance.pt-BR.md)

`HBBridge.Test.HBBridgeConcurrencyTest` inicia quatro workers `StartJob` em
um processo AppServer: dois usam o client TCP de produção e dois usam o
client HTTP de produção. Cada worker cria e libera seus próprios client,
dataset e objetos JSON. Somente configuração serializada e nomes de chaves
string atravessam a fronteira entre jobs.

O processo pai aguarda os quatro sinais READY antes de liberar seus gates GO.
Cada worker executa duas rodadas pelos aliases MSSQL e SQLite fornecidos
explicitamente, com ordens iniciais opostas. Os SELECTs constantes incluem
IDs e marcadores distintos por worker/etapa. `SERVERPROPERTY('ProductVersion')`
e `sqlite_version()` identificam a execução no banco; o resultado bruto também
deve declarar o driver esperado `mssql` ou `sqlite`. Os schemas contêm
`MSSQL_ONLY` ou `SQLITE_ONLY`, respectivamente.

Cada etapa verifica troca de alias, limpeza dos campos anteriores, duas
páginas com totais COUNT, linhas exatas, snapshots defensivos de linha/header,
SQL inválido, alias desconhecido e recuperação imediata. Nenhuma tabela ERP
ou configuração do SQL Server é modificada. O mutex do ciclo SQL nativo
permanece habilitado; este teste não exige execução SQL paralela.

## Executar contra um host isolado

O launcher nativo M07 recebe um alias MSSQL funcional existente de uma
configuração privada e cria um perfil SQLite isolado:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency -Serve
```

O servidor imprime suas portas TCP e HTTP de loopback após a validação nativa.
Usar esses endpoints, o alias MSSQL funcional explícito, `m07/sqlite` e o
token HTTP exclusivo da fixture `m07-http-test-only`. O perfil nativo
`m07/mssql-clone` é exercitado pela suíte nativa; esta suíte Protheus exige
os dois drivers de bancos diferentes.

Compilar toda a árvore `src/tlpp`, incluindo os dois arquivos `.tlpp` deste
diretório. A entrada pública é:

```tlpp
U_HBBridgeConcurrencyTest(cMSSQLProfile, cSQLiteProfile, cHost, nPort, cURL, cToken, ;
    nTimeoutSeconds, nWorkers, nBudgetSeconds, nLaunchDelayMs, nLaunchStepMs, nLaunchMaxMs)
```

Exemplo com as portas impressas pela fixture:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", nTCPPort, ;
    "http://127.0.0.1:" + cHTTPPort, "m07-http-test-only", 30)
```

Os dois aliases são obrigatórios, distintos e explícitos. Argumentos de
transporte omitidos leem Host, Port, HTTPURL e HTTPToken da seção `[hbBridge]`
do AppServer ativo. O timeout opcional tem default de 30 segundos; é convertido
para milissegundos no TCP e passado em segundos no HTTP. Nenhum perfil SQL
demonstrativo é selecionado.

## Linha de comando do AppServer

Usar o RPO/ambiente licenciado da instalação e um INI privado para CLI conforme
o [guia do teste de falhas](../hbbridge.failure.test/README.pt-BR.md).
Executar no diretório do AppServer em `cmd.exe`, substituindo as portas impressas:

```bat
appserver.exe -ini="hbm07.ini" -run=U_HBBridgeConcurrencyCLI -env=PROTHEUS --mssql-profile=MSSQL/pData --sqlite-profile=m07/sqlite --host=127.0.0.1 --port=<tcp-port> --url=http://127.0.0.1:<http-port> --token=m07-http-test-only --timeout=30 --workers=4 --budget-seconds=120 --launch-delay-ms=300 --launch-step-ms=50 --launch-max-ms=5000
```

A entrada CLI nativa toma emprestado `Variadic:vArgs`. Flags reconhecidas
devem ser únicas e usar `--nome=valor`. Flags numéricas exigem inteiros decimais
canônicos; o espaçamento de lançamento também aceita `0`. Frações, expoentes,
sinais, zeros iniciais como `00` e sufixos numéricos são rejeitados.
A suíte não imprime argumentos, tokens, SQL, corpos
de resposta ou descrições de exceções. Exit 0 exige todos os checks; exit 1
indica configuração, pré-requisitos, coleta de workers ou assertions falhados.

## Relatório esperado e escopo do ciclo de vida

Uma execução completa bem-sucedida informa **417 checks, zero falhas**:
**83 checks por worker TCP**, **111 por worker HTTP** e **29 checks do pai**.
Cada worker emite 28 chamadas RPC, totalizando 112. Chamadas paginadas executam
sua própria instrução COUNT. O pai exige quatro IDs de thread AppServer
distintos entre si e de sua própria thread, além de intervalos de execução
de workers sobrepostos.

Cada execução usa chaves ready/result/gate próprias por worker, com escopo
UUID, pelas APIs nativas `PutGlbValue`/`GetGlbValue`. Cada chave ready/result
tem um escritor; somente o pai escreve os gates. O worker libera client,
dataset e objetos JSON antes de publicar seu relatório JSON. O pai copia o
relatório antes de confirmar a coleta. ABORT ou gate ausente impede novas
chamadas; pai e worker removem suas chaves, incluindo publicações tardias.
O wrapper público apaga READY por último, após o retorno de Worker. O pai
aguarda essa limpeza final de todos os workers antes de retornar.

O relógio monotônico normalizado mede o orçamento independente
`nBudgetSeconds` (padrão 120 segundos), incluindo inicialização, pausas de
lançamento, prontidão, coleta e limpeza final normal. O mesmo valor é
selecionável por `--budget-seconds`. Relógio regressivo ou worker ausente
reprova a suíte. Relatórios publicados aguardam confirmação por no mínimo
150 segundos ou orçamento da coleta mais 10 segundos. São prazos do teste,
sem modificar limites do produto.

Se a coleta falhar, o coordenador sinaliza ABORT e espera separadamente a
limpeza dos jobs (timeout por chamada mais 10 segundos), antes de apagar suas
chaves. Workers verificam ABORT entre chamadas e param sem registrar chamadas
não executadas como falhas de resposta. Chamadas já em execução mantêm seus
timeouts nativos: não é cancelamento SQL no servidor nem garantia de join nativo.

`StartJob(...,.F.)` retorna NIL e não expõe handle de join. A publicação do
relatório comprova liberação explícita dos recursos TLPP; não comprova término
nativo da thread, cancelamento ou restauração de workarea/conexão do servidor.
A suíte M07 nativa registra restauração e liberação do servidor separadamente.

As primitivas suportadas estão documentadas em [TOTVS StartJob](https://tdn.totvs.com/display/tec/StartJob),
no [exemplo oficial de workers](https://tdn-homolog.totvs.com/display/tec/Exemplo%2Bde%2BFila)
e nos [snippets do editor TOTVS](https://github.com/totvs/advpl-vscode/blob/master/snippets/advpl.json).
Confirmada a validação AppServer CLI em 2026-10-14: 417 checks, zero falhas,
112 chamadas, saída 0 e encerramento limpo após confirmação dos quatro jobs.
[Evidências](../../../../../docs/acceptance.pt-BR.md#sql-concurrency-and-release-on-2026-10-14).
Essa execução precedeu a configuração de espaçamento descrita abaixo; não
homologa a execução desta revisão.

## Reproduzir o espaçamento de lançamento

Os argumentos 10, 11 e 12 são `nLaunchDelayMs`, `nLaunchStepMs` e
`nLaunchMaxMs`. No CLI, correspondem a `--launch-delay-ms`,
`--launch-step-ms` e `--launch-max-ms`. Cada um aceita inteiro entre
0 e a capacidade nativa do argumento de `Sleep`, 2147483647 milissegundos.
Os padrões preservam a rampa de lançamento: 300, 50 e 5000 milissegundos.

Após iniciar o worker `i`, o pai pausa por
`Min(nLaunchDelayMs + i * nLaunchStepMs, nLaunchMaxMs)`, inclusive após o
último lançamento. Todos os workers ainda precisam informar READY antes
da liberação de qualquer GO. O espaçamento distribui a criação dos jobs;
a barreira libera o trabalho SQL/HTTP em conjunto. Não reduz a quantidade
de solicitações simultâneas dos workers nem comprova solução para a criação
frequente de conexões físicas. Os jobs usam o `GetEnvServer()` corrente.

Antes de iniciar qualquer job, o pai calcula a soma da rampa limitada,
sem percorrer os workers. Pausas planejadas iguais ou superiores ao
orçamento total são rejeitadas. São registrados os parâmetros e a soma
exata das pausas aceitas; uma soma rejeitada aparece como no mínimo o
orçamento, sem transbordar a aritmética numérica. A estimativa exclui o
custo de `StartJob` e do escalonamento, que também consomem esse prazo.
O lançamento para se o orçamento expirar; uma chamada nativa `StartJob`
em execução não pode ser interrompida por essa verificação.

| Workers | Pausas planejadas com os padrões |
| --- | --- |
| 4 | 1700 ms |
| 130 | 431450 ms |
| 140 | 481450 ms |

Informar zero nos três argumentos para um controle sem pausas. Para
reproduzir a rampa padrão com 140 workers, reservar prazo maior que seus
481450 ms de pausas, acrescido de inicialização, consultas e limpeza:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 140, 900, 300, 50, 5000)
```

Esta revisão ainda exige compilação e validação em execução. Os valores
descrevem uma configuração reproduzível do teste, sem homologar capacidade
do produto.

## Aumentar a carga

Informar quantidade de workers no argumento 8 e orçamento total do teste,
em segundos, no argumento 9. Após compilar esta versão não é necessário
editar a constante/recompilar a cada carga:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 140, 300, 0, 0, 0)
```

No CLI: `--timeout=30 --workers=140 --budget-seconds=300 --launch-delay-ms=0
--launch-step-ms=0 --launch-max-ms=0`. São prazos distintos:
30 segundos por chamada de rede, 300 segundos para a rodada completa,
incluindo lançamento. Manter a rampa padrão nesse orçamento de 300 segundos
é rejeitado antes de iniciar jobs.
Aumentar somente o primeiro para 150 mantém a coleta omitida em 120 segundos,
podendo encerrar o teste enquanto chamadas ainda executam. O padrão continua
4 jobs; mínimo 4 para cobrir dois TCP/dois HTTP.

Os dois primeiros workers usam TCP; os demais, HTTP. Cada um emite até 28
chamadas, com 83 assertivas TCP ou 111 HTTP. O pai tem `6 * workers + 5`
checks, contados pelas chaves JSON reais. Rodadas completas de 4/40/100/140
jobs informam 417/4629/11649/16329 checks. O resumo anterior subcontava as
assertivas do pai quando a constante era aumentada.

Logs manuais de 4/40/100 jobs reportam zero falhas. A rodada anterior de 140
falhou em 833 assertivas HTTP da etapa 4 e 136 checks do pai indicando esses
workers com falhas. A nova rodada em 2026-10-15 usou timeout 150 por chamada e
coleta 120; coletou 83 relatos e falhou em 894 checks. São rodadas de carga
falhas, sem comprovar limite do produto ou homologar 140 jobs.

Diagnósticos de etapa/jobs pendentes distinguem início, prontidão, coleta e
liberação. Operações finais falhas informam status HTTP, código reconhecido e
tempo, sem tokens, SQL ou texto bruto de exceção. `[General] MaxWorkers` no
hbBridge governa capacidade dos listeners, separada dos jobs AppServer. O
mutex do ciclo SQL permanece. Veja o
[complemento de homologação](../../../../../docs/acceptance.pt-BR.md#sql-concurrency-follow-up-on-2026-10-15).

Resumos manuais posteriores com pausas explícitas informam zero falhas em
5/15/20/30/150/500 jobs: **83934 checks** no total, incluindo **58449** com
500 jobs. Todos os relatos esperados foram coletados. O trecho fornecido não
contém logs individuais, identidade do binário ou modo do pool nativo;
homologa a configuração exercitada independentemente do reuso físico.
[Evidências manuais](../../../../../docs/acceptance.pt-BR.md#manual-protheus-concurrency-on-2026-10-15).
