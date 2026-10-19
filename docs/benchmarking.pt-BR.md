# Referência de desempenho MSSQL

[English](benchmarking.md) · [WIP](../WIP.pt-BR.md) · [Aceite](acceptance.pt-BR.md)

M08 registra uma referência reproduzível da implementação existente. Não
impõe um limiar de velocidade nem determina a capacidade de produção.
O mutex do ciclo SQL permanece habilitado. Começar com um cliente; M07 mantém
as evidências separadas de concorrência e liberação.

## Carga comum

Usar a fixture somente de leitura `m08.constant.v1` com um perfil MSSQL
configurado e explícito. Ela gera linhas numeradas com nome ASCII e valor
decimal com CAST explícito, sem ler nem escrever tabelas do ERP. Todas as
rotas usam o mesmo SQL, projeção, ordenação, quantidade de linhas e tamanho
de página. A capacidade de 100000 linhas do gerador pertence à fixture;
não é limite de payload do servidor.

Os parâmetros iniciais são 1000 linhas, páginas de 100, duas varreduras de
aquecimento e cinco medidas, com concorrência um. Cada varredura lê todo o
dataset paginado e valida linhas, valores e totais das páginas. Cada página
usa o contrato Query existente, incluindo sua instrução COUNT separada.
Tempos e contagens de chamadas de aquecimento são preservados separadamente
e excluídos do agregado medido. O aquecimento continua executando SQL e
gerando tráfego; apenas suas medições ficam separadas.

As rotas nativas executam em processos filhos separados: serviço Harbour
direto, TCP e HTTP. O consumidor TLPP mede os clientes TCP e HTTP reais do
Protheus. Identificar a implementação/linguagem do cliente ao comparar os
resultados. Um cliente nativo no mesmo processo e um cliente AppServer têm
fronteiras de processo diferentes e devem manter suas próprias medições.

Executar as políticas ODBC `off` e `driver` em processos novos ao comparar
pooling físico. Registrar a política efetiva. A política Windows opcional e
seu aceite de isolamento estão em [conexões SQL](sql-connections.pt-BR.md).
A política de um servidor externo existente precisa ser identificada
separadamente; um argumento do cliente não a altera.

## Tempo e memória

O intervalo cronometrado cobre uma varredura completa do dataset, incluindo
chamadas do cliente, processamento do servidor, paginação e validação das
respostas. Preparação, compilação, inicialização do servidor e aquecimento
ficam fora desse intervalo. Preservar durações individuais, mínimo, máximo,
média aritmética e total, além de linhas, páginas e chamadas de serviço.
Latência de uma requisição, duração apenas do SQL e duração completa do
processo são métricas diferentes.

O relógio nativo é `HBBridgeMonotonicMs()`. No Windows, a origem
`GetTickCount64` tem resolução de ticks nativos, normalmente próxima de
10–16 ms. Uma média fracionária derivada de vários intervalos não melhora
a resolução desse relógio. TLPP usa o wrapper existente de `TimeCounter()`
normalizado e registra runtime/plataforma; isso não adiciona aceite de wrap
do relógio.

Informar working set do processo pelo SO e private bytes no Windows em bytes,
identificando intervalo solicitado, quantidade de amostras e fase. Os tempos
do CSV registram o espaçamento real, incluindo o custo de amostragem. Um
máximo amostrado pode perder um pico breve. O pico vitalício do SO inclui
preparação e aquecimento e deve ficar separado do máximo amostrado durante
a medição. A memória pertence a todo o processo observado; não representa
alocações de uma query, cliente, ODBC, Harbour, C ou Zig. As fixtures nativas
TCP/HTTP incluem servidor isolado e cliente no mesmo processo. AppServer e
servidor hbBridge externo exigem observações de processo separadas.

Uma métrica indisponível é registrada como indisponível, nunca como zero.
Não é necessária uma API TLPP de memória sem documentação. Essas medições
não provam ausência de vazamentos; isso exige cargas comparáveis repetidas
e análise separada do ciclo de vida.

## Reprodução e evidências

O executor nativo resolve a toolchain gerenciada e produz uma pasta isolada
de artefatos:

```powershell
./scripts/benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -ODBCPooling off
./scripts/benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -ODBCPooling driver
```

`-Rows`, `-PageSize`, `-Iterations` e `-Warmup` alteram as quantidades da fixture;
`-Route local|tcp|http|all` seleciona os clientes nativos. `-SocketTimeoutMs`
controla o prazo dos sockets da fixture. `-SampleIntervalMs` solicita o
espaçamento entre amostras; `-ProcessTimeoutSeconds` limita cada processo filho
próprio, incluindo preparação e encerramento. São controles do executor,
sem alterar capacidades do produto.

Para um destino AppServer isolado, usar `-Route http -ServeSeconds 600`.
Após as medições nativas, `endpoints.json` na pasta `http/` da execução
contém portas dinâmicas de loopback, perfil/backend selecionado, política
de pooling e token público exclusivo da fixture `m08-http-test-only`.
O host permanece disponível pelos segundos solicitados ou até a criação
de `m08.stop` nessa pasta `http/`. O executor imprime o resultado final após
o encerramento. A fase de memória `serving` fica separada do tempo nativo;
suas amostras podem incluir tráfego de clientes externos. Nenhum INI privado
é alterado.

Usar o [exemplo TLPP](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md)
para a entrada AppServer e as instruções de compilação. Credenciais privadas
continuam na configuração do servidor; os executores não imprimem strings
de conexão, tokens, erros nativos brutos ou conteúdo do INI privado.

Preservar os relatórios JSON gerados e logs sanitizados. Identificar hashes
do executável e dos fontes próprios, revisões/patches das dependências
fixadas, SO, arquitetura, runtime, versão do backend, SQL/hash da fixture,
política de pooling e parâmetros da carga. Inventário de drivers instalados
não comprova o driver usado por uma conexão; registrar essa distinção.
Informar outros trabalhos em execução e plano de energia quando puderem
afetar a comparação. Não deduzir medições ausentes dos resumos de M07.

Execuções reais e limitações pendentes ficam no [aceite](acceptance.pt-BR.md).

## Consumidor visual AppServer e análise de falhas

`U_HBBridgeBenchmark()` abre o formulário FWWebEx opcional com cinco parâmetros
numéricos. Invoca `HBBridgeBenchmarkTest.Measure()` por controlador correlacionado;
o CLI usa o mesmo núcleo. Perfil e credenciais/endpoints vêm de configuração
TLPP/INI confiável. A página apresenta médias e varreduras medidas em gráficos,
separa aquecimento e exporta JSON/HTML de resultados sem CDN de gráficos.
Veja o [guia](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md).

A execução é síncrona. Timeout vale por requisição, não pelo benchmark inteiro.
Esperar ou fechar a página não cancela o trabalho nativo. Cenários falhos mantêm
amostras e estatísticas parciais; falhas não viram pontos com latência zero nem
iterações aprovadas.

Novos relatórios incluem fase/iteração da falha e `serviceCode`, `httpStatus`
e `failedPage` por amostra. TCP não tem status HTTP; dados ausentes não
identificam causa. Texto nativo de exceções, SQL e credenciais são excluídos.
Preservar linha compacta de falha e resumo completo. Uma falha de 30 segundos
no resumo antigo sem esses campos mede duração, sem comprovar timeout SQL.

O cliente TCP reutiliza um componente nativo por instância; conexões continuam
por requisição. Clientes próprios do benchmark chamam `Close()` ao terminar.
A regressão de ciclo envia 6000 Health no mesmo cliente por padrão e verifica
independência/recuperação. Seu resultado é separado de desempenho SQL,
contadores do alocador/registro do terminal e da
[rodada ampliada](acceptance.pt-BR.md#m08-large-protheus-follow-up-on-2026-10-16).

## Comparação Protheus e execução dentro de addon

O exemplo visual ampliado mede quatro varreduras completas no cliente:
hbBridge TCP, hbBridge HTTP, Protheus StartJob e REST nativo TLPP. Todos usam
a fixture MSSQL constante, SELECT paginado mais COUNT, o mesmo tamanho de
página e checks do dataset. StartJob cria worker síncrono por página e inclui
sua inicialização; é um job dentro do AppServer, sem transporte TCP. REST TLPP
usa o pool configurado e DBAccess. Seu endpoint aceita somente
`{rows,pageNumber,pageSize}`, sem SQL externo nem credenciais de banco.
Protheus usa o banco do seu ambiente; o alias hbBridge não seleciona nem altera
esse ambiente. Verificar que ambos apontam para o mesmo banco MSSQL.

Um cenário adicional em addon consome todas as páginas no hbBridge pelo mesmo
registro `RPCRDD.Query` com verificação de permissões. Retorna apenas checks e
medições, separando aquecimentos. `hbbridgeAddon.samples.*.elapsedMs` mede
varredura, SQL e validação de hashes/valores no servidor; exclui carga do HRB
e rede. `hbbridgeAddon.callElapsedMs` mede uma chamada completa, incluindo
carga do HRB, todos os aquecimentos/iterações e transporte. A página apresenta
esses escopos separadamente. A diferença de transferência e trabalho no cliente
permite comparar onde executar; a média do servidor não substitui as quatro
barras de tempo total das varreduras no cliente.

Compilar/instalar o HRB opcional com
`scripts/build-hbbridge-benchmark-addon.ps1`; saída padrão
`addons/examples/hbbridgebenchmarkaddon.hrb`. Instalar sob `addonRoot` do
servidor ativo e recompilar hbBridge para o contexto nativo opcional do addon.
Nenhuma credencial SQL é enviada: o host fornece seu registro local como segundo
argumento nativo opcional. Addons existentes preservam primeiro argumento JSON
e contrato de retorno. O contexto pertence à chamada, não deve ser retido nem
serializado; chamadas internas continuam sujeitas às permissões.

A [configuração REST privada](../config/hbbridge.benchmark.rest.pt-BR.md) inclui
`BenchmarkProtheusURL`, `BenchmarkProtheusCredentialSection`, `BenchmarkAddonModule` e
`BenchmarkAddonTimeoutSeconds` em `[hbBridge]`. O exemplo visual habilita todas
as comparações; o CLI habilita com `--compare-protheus=1 --with-addon=1`.
Sem essas flags, o CLI mantém a referência de duas rotas. REST 2.0 valida
Basic com `UserName`/`Password` da seção privada referenciada, sem bearer
adicional do benchmark. Autorização e módulo ficam na configuração confiável.
O visual captura `cEmpAnt`/`cFilAnt` já selecionadas no Protheus e as passa
ao StartJob. No CLI, informar `--company=99 --branch=01`, ou chaves privadas
`BenchmarkProtheusCompany`/`BenchmarkProtheusBranch`. Somente o job prepara
e fecha seu ambiente com `RpcSetEnv()`/`RpcClearEnv()`. `FWGetTopInfo()` fornece
a configuração DBAccess necessária. REST mantém sua sessão preparada pelo
framework; contexto ERP não é enviado ao addon nem inferido pelo hbBridge.

O timeout do addon vale pela RPC completa, não por página SQL; dimensionar pela
carga inteira solicitada. StartJob verifica o prazo após retornar, sem interrupção
pelo executor. Timeout do cliente não comprova encerramento do worker. Spinner
e tempo decorrido indicam requisição pendente, sem percentual real ou cancelamento.

## Comparação visual e pacotes homologados em 2026-10-19

V01/V02 concluídas no escopo AppServer manual e evidências focadas registrados.
Três rodadas passaram nas cinco rotas: 75 amostras medidas e 30 aquecimentos;
auditoria dos pares JSON/HTML passou em 684 checks. Veja
[resultados, hashes e limites](acceptance.pt-BR.md#v01-v02-benchmark-acceptance-on-2026-10-19). D03 é a próxima
tarefa; M09 permanece aberta.

Quando o addon executa tudo e retorna métricas, uma comparação adicional de
pacotes usa sua RPC completa frente à soma dos intervalos das mesmas sete
varreduras cliente, incluindo dois aquecimentos dos dois lados. Nas três
rodadas: 17.677854 s em RPCs do addon frente a 26.260709 s REST Protheus
(32.68% menos tempo). Essa métrica difere das médias de 15 amostras sem
aquecimento. Addon devolve métricas; clientes recebem e conferem páginas.
Somas cliente excluem orquestração entre iterações; RPCs incluem a orquestração
interna. Cada pacote substitui 70 chamadas externas de página por uma RPC e
70 dispatches locais. O resíduo entre RPC e tempo interno foi 4.375-9.622 ms,
menos de 0.17% observado, incluindo efeitos de HRB/JSON/transporte/relógios.
Não é medição isolada da rede nem estimativa para devolver todo o dataset.

O CLI TCP/HTTP manual passou separadamente com dez linhas e sem aquecimento.
[Escopo e esclarecimento da carga/timeout](acceptance.pt-BR.md#m08-manual-cli-validation-on-2026-10-19)
o distinguem das falhas de inicialização StartJob CLI isolada e da carga
ampliada com prazo inadequadamente dimensionado.


## Processadores C/Zig futuros e referência PostgreSQL/2610

Os dois benchmarks adicionais solicitados mantêm SQL no hbBridge, fornecem
JSON dos resultados a C ou Zig e devolvem métricas. Estão previstos controle
Harbour com o mesmo JSON e intervalos separados de SQL/serialização/parsing/
processamento/RPC. O ambiente Docker Protheus 12.1.2610/PostgreSQL indicado é
referência futura de compatibilidade, com aceite próprio de conector, dialeto,
SDK, codificação e implantação. Veja [desenho e plano](benchmark-evolution.pt-BR.md).
São tarefas futuras; D03 e checks finais M09 mantêm a prioridade ativa.
