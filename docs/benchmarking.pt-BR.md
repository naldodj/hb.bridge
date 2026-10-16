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
