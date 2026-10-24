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

A rota AppServer `http` atual exige respostas gzip explicitamente com
`Accept-Encoding: gzip, identity;q=0`. Sobrepõe a preferência do INI do cliente
geral e registra `httpRequireGzip=true` e `httpAcceptEncoding` no relatório.
Gzip ausente falha com `HTTP_COMPRESSION_REQUIRED`; desativar compressão no
servidor produz 406 em vez de uma medição silenciosamente descompactada.
Relatórios históricos identity mantêm seu escopo original. Clientes comuns
continuam aceitando identity negociado quando gzip obrigatório não é pedido.
Veja o [contrato HTTP e comparação datada](http.pt-BR.md#http-review-on-2026-10-24).

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

## Seleção de rotas e estatísticas medidas

O benchmark AppServer pode executar qualquer subconjunto não vazio de `tcp`,
`http`, `protheusStartJob`, `protheusRest`, `hbbridgeAddon` e `protheusServer`. A seleção controla
execução real, criação dos clientes e validação das dependências; não é filtro
de gráfico. As rotas selecionadas mantêm essa ordem fixa, com concorrência um.
Uma rota ignorada não possui medição aprovada nem deve ser contada como sucesso.
Os campos adicionais `routeSelectionVersion=1`, mapa booleano `selectedRoutes`
e `routeStates` registram seleção e estados `skipped`, `notStarted`, `completed`
ou `failed`. Mapas novos possuem as seis chaves booleanas. O mapa anterior de
cinco chaves é aceito, normalizando `protheusServer` ausente para `false`.
Chamadas sem seleção preservam TCP/HTTP e as opções anteriores de comparação/
addon; não habilitam automaticamente a nova rota inteiramente no servidor.

O CLI aceita `--routes=http` ou uma lista como `--routes=tcp,http`. Usar os
nomes exatos acima. Seleções vazias, nomes desconhecidos e rotas repetidas são
rejeitados antes da execução. `--routes` explícito é suficiente para selecionar
rotas Protheus/addon e substitui a seleção padrão anterior. Sem ele,
`--compare-protheus=1` e `--with-addon=1` mantêm seu comportamento anterior.
Uma rodada apenas do addon usa sua RPC TCP e configuração;
não executa HTTP nem a varredura Query no cliente. Uma seleção apenas Protheus
não exige destino TCP/HTTP hbBridge. Cada rota valida suas próprias entradas.

O formulário visual expõe somente capacidades habilitadas pela configuração
TLPP confiável. Oferece seleção individual e predefinições, sem permitir ao
navegador alterar perfil, destinos, módulo, contexto ERP ou credenciais.
Capacidades indisponíveis não podem ser ativadas alterando a requisição no
navegador. Console, resultados e JSON preservam a seleção para não confundir
um teste isolado com uma comparação completa aprovada.

As quatro rotas cliente preservam o escopo de varredura completa do dataset
por iteração. `protheusStartJob` cria um job síncrono por página.
`protheusServer` cria um único job síncrono para todos os aquecimentos e
iterações medidas, prepara/libera somente seu próprio ambiente Protheus e
executa o mesmo SELECT paginado mais COUNT pelo DBAccess.
`samples.*.elapsedMs` cobre SQL/varredura/checks internos; `callElapsedMs`
inclui preparação do job/ambiente, todas as varreduras e retorno das métricas.
A página mostra esse escopo ao lado do addon, em painel separado. Comparar
escopos internos equivalentes ou chamadas completas equivalentes; nenhuma
média interna participa do ranking das quatro rotas cliente.

O controlador aceita os cinco parâmetros numéricos originais, os seis da
versão com `routes` e os sete atuais incluindo `timeoutPolicy`. A página atual
envia mapa de seis rotas e política explícita. Perfil, SQL, destinos, contexto
ERP e credenciais continuam fora das entradas do navegador.

### Timeout automático e manual por chamada

O visual inicia com estimativa automática e teto operacional editável de
**900 segundos**. Defaults confiáveis podem fornecer `timeoutMaximumSeconds`.
O CLI habilita a mesma política com `--timeout=auto --timeout-max=900`.
Para política manual explícita, usar, por exemplo,
`--timeout=120 --timeout-max=900`. Os dois modos exigem teto inteiro de 1 a
2147483 segundos; valores manuais acima dele são rejeitados sem alteração
silenciosa. Editar Call timeout no visual seleciona o modo manual. Tetos
inferiores a 30 segundos continuam sendo respeitados.

Com quantidades inteiras válidas, `pages = Max(1, Ceiling(rows/pageSize))`.
Quando `hbbridgeAddon` ou `protheusServer` está selecionado, a estimativa sem
teto é `30 + Ceiling((iterations + warmup) * pages)` segundos; caso contrário,
é 30. O timeout automático efetivo é `Min(maximumSeconds, estimate)`.
É uma base de 30 segundos mais um segundo estimado por página no servidor,
sem representar previsão medida de vazão nem garantia de conclusão. A página
informa teto atingido e estimativa sem teto; o controlador recalcula o valor
com entradas validadas. A política não tem uma fronteira de 254/255 iterações.

A entrada `timeoutPolicy` é exatamente
`{mode: "auto"|"manual", maximumSeconds: N}`. O relatório registra
`timeoutSeconds` efetivo no nível principal e `timeoutPolicy` resolvida com
`success`, `mode`, `maximumSeconds`, `timeoutSeconds`, `estimatedSeconds`,
`ceilingReached`, `method` e `scope`. HTML concluído e exportações leem essa
política do relatório, nunca os controles da próxima rodada. Relatórios
antigos sem política a apresentam como indisponível. Rotas cliente aplicam o
prazo por página; rotas inteiramente no servidor o aplicam à chamada única
completa. A política explícita também define o prazo da RPC completa do addon,
sem substituição silenciosa pelo antigo padrão separado de 600 segundos.
Chamadas antigas sem política preservam `BenchmarkAddonTimeoutSeconds`.

StartJob síncrono só verifica o tempo após retornar da chamada bloqueante.
Timeout do cliente, aviso de espera ou fechamento da página não comprovam
cancelamento do SQL/worker. O timeout do processo executor é outro escopo;
precisa comportar carga escolhida e preparação.

As estatísticas derivadas por rota usam somente amostras medidas de varredura
aprovadas: `sampleCount`, `medianMs`, `p95Ms` por nearest-rank, `stdDevMs`
populacional, `cvPct`, `throughputRowsSec` e `throughputCallsSec`.
`statisticsMethod` registra o método. Aquecimentos e falhas ficam separados.
A mediana usa a média dos dois valores centrais quando a contagem é par;
P95 seleciona a posição ordenada `Ceiling(0.95 * count)`. O desvio padrão
divide pela quantidade de amostras; CV divide esse desvio pela média e
multiplica por 100. Métricas sem denominador válido ficam indisponíveis,
não zeradas. Vazão de linhas/chamadas divide as quantidades medidas e validadas
pelo tempo somado das varreduras; não representa vazão bruta do banco ou rede.

`HBBridgeBenchmarkStats.Apply()` verifica contagem concluída, totais de
linhas/chamadas e agregados de duração existentes frente às amostras antes
de adicionar estatísticas. Comparações de duração em ponto flutuante usam
tolerância absoluta/relativa `1e-9`. Totais inconsistentes falham explicitamente,
sem correção silenciosa. Falha de uma rota não impede que outras rotas
selecionadas e independentes preservem seu próprio resultado de execução.

Cinco amostras medidas representam uma observação pequena: nesse caso P95
nearest-rank coincide com o máximo observado e não estima cauda de latência
em produção. Estatísticas parciais aprovadas não tornam comparável uma rota
com falha. Comparar rotas cliente completas e aprovadas com a mesma carga e
escopo temporal. Estatísticas internas do servidor Protheus e do addon ficam
separadas de seus StartJob/RPC completos e das barras de varreduras cliente. Tempo de renderização no navegador e tamanho
do payload não são medidos pelo teste nem inferidos do tempo decorrido.

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
as capacidades de comparação; o formulário seleciona as rotas de cada rodada.
O CLI habilita com `--compare-protheus=1 --with-addon=1` ou `--routes` explícito.
Sem essas flags, o CLI mantém a referência de duas rotas. REST 2.0 valida
Basic com `UserName`/`Password` da seção privada referenciada, sem bearer
adicional do benchmark. Autorização e módulo ficam na configuração confiável.
O visual captura `cEmpAnt`/`cFilAnt` já selecionadas no Protheus e as passa
ao StartJob. No CLI, informar `--company=99 --branch=01`, ou chaves privadas
`BenchmarkProtheusCompany`/`BenchmarkProtheusBranch`. Somente o job prepara
e fecha seu ambiente com `RpcSetEnv()`/`RpcClearEnv()`. `FWGetTopInfo()` fornece
a configuração DBAccess necessária. REST mantém sua sessão preparada pelo
framework; contexto ERP não é enviado ao addon nem inferido pelo hbBridge.

O timeout no servidor vale pela RPC ou StartJob completo, não por página SQL;
dimensionar a política explícita pela carga inteira solicitada. StartJob verifica o prazo após retornar, sem interrupção
pelo executor. Timeout do cliente não comprova encerramento do worker. Spinner
e tempo decorrido indicam requisição pendente, sem percentual real ou cancelamento.

## Validação da manutenção e investigação da fronteira de iterações

Os novos controles/estatísticas exigem aceite próprio; os resultados de cinco
rotas datados de 2026-10-19 abaixo preservam seu escopo original de fontes/carga.
Compilação isolada completa aprovada para 54 fontes TLPP: zero erros e saída 0.
O AppServer CLI com RPO isolado aprovou 82 checks de controle, 81 visuais/do
controlador e 43 de contrato REST após a compilação final. O teste real de correção `protheusServer` MSSQL passou com
`MSSQL/pData`, empresa/filial 99/01, 10 linhas, página de 5, duas varreduras
medidas e um aquecimento: 20 linhas medidas, quatro chamadas de página e duas
amostras. Média interna de 78.94645 ms; StartJob completo de 8329.1636 ms.
São escopos distintos intencionais; duas amostras pequenas comprovam correção,
sem estabelecer referência de desempenho. Após corrigir a precisão, os 54
fontes TLPP foram recompilados com sucesso, zero erros/saída 0; somente
artefatos da revisão correspondente comprovam esse check.

Após corrigir o codec, a suíte nativa completa passou 752 checks e a de addon
passou 93 checks: valores racionais/muito
pequenos/grandes em parâmetros/retornos sob SET DECIMALS 2, espaços JSON
aceitos, conteúdo inválido após JSON rejeitado, ida/volta TCP de `1/3` e
agregados exatos em 254/255/256/500 iterações sem pausas com SQL simulado.
Esse mock comprova seu escopo de transporte/fixture, sem homologar carga MSSQL.
O cliente TLPP real também passou os checks pós-correção em 255/500 abaixo. O Chromium real
mais recente passou nas três suítes principais: 69 asserções de DOM, 30 de
rotas opcionais/servidor/timeout/layout e proteção sem canal. Cobre estimativas em
254/255/500, teto/modo manual, mapas antigos, política própria do relatório,
falhas visíveis, exports e séries grandes. Fixtures de navegador não homologam
SQL/StartJob reais.

### Diagnóstico de precisão JSON do addon em 2026-10-23

Na rodada fornecida `D24377B51C174447AA3C185DF76A876F`, o validador registra
255 amostras medidas concluídas e dois aquecimentos, ambos os conjuntos de
amostras válidos e todos os checks de fixture/perfil/carga aprovados. Somente
`statisticsValid` é falso. A chamada completa retornou após 87925.5106 ms
(87.9255 segundos), abaixo do prazo explícito de 900 segundos. Essa falha
fornecida rejeita integridade dos agregados; não comprova limite de 255
iterações nem prazo completo expirado. A reprodução posterior de 500
iterações com cliente TLPP real/SQL simulado também concluiu as amostras e
falhou na validação dos agregados.

Reprodução nativa determinística identifica perda interna de precisão JSON:
com `SET DECIMALS TO 2`, `hb_jsonEncode()` serializa a média `1 / 3` como
`0.33`. A ABI addon/host nativo usava esse encoder antes do codec externo D03,
que já não conseguiria recuperar a média original. A validação estrita de
amostras/totais/média rejeita corretamente o agregado arredondado. A correção
usa os existentes `HBBridgeJSONEncode()`/`HBBridgeJSONDecode()` no addon de
benchmark e na passagem nativa comum, preservando ABI JSON e validação
estrita, sem aumentar tolerâncias. Recompilar host e HRB juntos para incluir
o codec que preserva precisão dos dois lados.
Defaults de apresentação continuam `DECIMALS 2` / `FIXED OFF`; a precisão JSON
independe dessas opções. Veja a [política SET runtime](standards.pt-BR.md)
para alterações temporárias do addon e restauração.

É um caso distinto do FLOAT original de D03: SDDODBC preservava `123.4567`,
mas associava metadado de formatação com zero decimais, e o encoder JSON
nativo emitia `123`. O codec C/Zig compartilhado preserva o valor numérico
recebido apesar dessas opções de formatação. A correção posterior do addon
reutiliza esse codec numa fronteira interna que ainda usava o encoder nativo;
não introduz regra de escala de negócio do Protheus. Veja
[FLOAT e escala de negócio explícita](dataset.pt-BR.md).

O contorno local `hb_idleSleep(1.5)` é removido: acrescenta 1.5 segundo por
varredura executada fora da amostra e altera ritmo/duração completos, sem
corrigir aritmética JSON. Rodadas anteriores com pausa preservam essa
limitação. Testes Windows TCP nativos com 254/255/256/500, SQL simulado e sem
pausas passaram com agregados exatos após a correção; a suíte de precisão/ABI/SET
passou 93 checks, incluindo SET DECIMALS 2/18 × FIXED off/on e restauração
das configurações do chamador. O cliente Protheus TLPP real depois passou 255 varreduras
medidas mais dois aquecimentos e 500 mais zero aquecimentos, usando host/HRB
Harbour TCP reais e serviço Query simulado. A validação estrita de agregados
passou nas duas rodadas. As médias preservaram
`15/255 = 0.0588235294117647` e `94/500 = 0.188`, em vez do arredondamento
nativo para `0.06` e `0.19`. Chamadas completas da fixture de aproximadamente
56.95 e 209.58 ms são evidência de correção no mock/resolução do relógio, sem
representar vazão SQL ou alegação de desempenho. A suíte nativa 752 e a
compilação final de 54 fontes TLPP também passaram após a correção.

A validação MSSQL real de 2026-10-23 também passou: cliente Protheus TLPP
real pelo host/HRB TCP isolado, perfil `MSSQL/pData`, 1000 linhas, página de
100, 255 varreduras medidas e dois aquecimentos, agregados estritos aprovados
e saída 0. A média exata foi `240937/255 = 944.850980392157` ms;
chamada completa de 243648.6517 ms abaixo de 900 segundos. Essa rodada usou
pooling físico ODBC **off**, perfil privado explícito e nenhuma pausa
artificial. Seu tempo comprova correção nesse escopo, sem comparar com
pooling/cache/carga da implantação original nem alegar ganho de desempenho.
A tentativa automática separada com 500 iterações excedeu o prazo do executor;
o cliente foi fechado antes de o worker nativo retornar. Não fornece resumo
AppServer aprovado nem homologa falha de codec/SQL. A rodada manual posterior
com 1500 iterações abaixo preserva seu escopo próprio.

Não deduzir aceite Linux/amplo de plataformas. Recompilar hbBridge, HRB de
benchmark e TLPP atuais juntos antes de repetir o caso na implantação normal.
Manter homologação manual FWWebEx e validação equivalente da implantação/
desempenho separadas. T01 do pacote 002 permanece planejada.

## Rodada FWWebEx fornecida e revisão visual em 2026-10-23

A rodada JSON/HTML fornecida `41C06CC62E8CBC4F8F20C1D597D64FDB` informa sucesso
com 1500 varreduras medidas e dois aquecimentos, 1000 linhas/página100 no
perfil `MSSQL/pData`. TCP, HTTP, REST Protheus, addon Harbour e servidor
Protheus em um job terminaram; StartJob por página foi explicitamente ignorado.
As cinco rotas registram 1500 amostras medidas concluídas e 1500000 linhas
medidas. Recálculo independente de totais compensados, mediana, P95 nearest-rank
e desvio padrão populacional coincide com os agregados em tolerância relativa
`1e-9`. Os arquivos fornecidos não identificam hashes dos fontes compilados/RPO
nem pooling físico efetivo; essa evidência manual fica separada das fixtures.

| Rota | Média por varredura medida (ms) | Chamada completa no servidor (ms) |
| --- | ---: | ---: |
| Cliente hbBridge TCP | 419.780244 | Escopo diferente: chamadas por página |
| Cliente hbBridge HTTP | 625.264503 | Escopo diferente: chamadas por página |
| Cliente REST Protheus | 754.723923 | Escopo diferente: chamadas por página |
| Addon Harbour, interno | 372.073333 | 558809.079800 |
| Servidor Protheus em um job, interno | 540.832381 | 815965.000300 |

A RPC completa do addon inclui soma medida de 558110 ms, aquecimentos de
562 ms e outros trabalhos da chamada; Protheus inclui soma medida de
811248.5717015 ms, aquecimentos de 989.5229 ms e trabalho do job/ambiente/
resultado. Essas chamadas completas não são uma iteração. Diferenças restantes
não constituem cronômetros isolados da rede.

A página revisada reúne ambas as rotas internas em cards alinhados, gráficos
por iteração compartilhados e tabela estatística única. RPC inteira do addon,
StartJob inteiro e duração total do benchmark ficam em seção de totais separada,
com contagens de medidas/aquecimentos e trabalho incluído. Escopos/rankings de
cliente e processamento interno continuam separados. Exports seguros mantêm a
mesma organização. O HTML real do projeto foi renderizado com o JSON fornecido,
bloqueando requisições HTTP/WebSocket externas; o HTML externo não foi executado.
Checks Chromium cobrem alinhamento, separação de escopos e export standalone;
prévia adicional com screenshot do relatório somente para leitura passou.

O executor de fixture agora respeita `[SQL] ODBCPooling` privado e imprime
`odbcPooling` nos metadados ready. A rodada automática 255 anterior usou pooling
off; esse registro histórico continua válido. Registrar o valor ready efetivo
de cada nova rodada, sem presumir equivalência com o relatório manual fornecido.
Confirmar o layout FWWebEx ativo revisado após recompilar TLPP; comparações de
desempenho exigem implantação/carga equivalentes e fontes/pooling/cache
identificados. T01 permanece planejada.

## Comparação visual e pacotes homologados em 2026-10-19

V01/V02 concluídas no escopo AppServer manual e evidências focadas registrados.
Três rodadas passaram nas cinco rotas: 75 amostras medidas e 30 aquecimentos;
auditoria dos pares JSON/HTML passou em 684 checks. Veja
[resultados, hashes e limites](acceptance.pt-BR.md#v01-v02-benchmark-acceptance-on-2026-10-19).
D03/M09 estavam pendentes naquele aceite; seu fechamento posterior no pacote
001 e o pacote atual estão no [WIP](../WIP.pt-BR.md).

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
Continuam como tarefas futuras; seguir o pacote atual e sua manutenção
preparatória no [WIP](../WIP.pt-BR.md).
