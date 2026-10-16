# Referência de desempenho TCP e HTTP no Protheus

[English](README.md) · [Pacote ativo](../../../../../WIP.pt-BR.md) · [Catálogo de testes](../../../../../tests/README.pt-BR.md)

`HBBridge.Test.HBBridgeBenchmarkTest` mede os clientes TLPP TCP e HTTP reais
usando a mesma massa MSSQL somente de leitura, `m08.constant.v1`. A massa contém
IDs de 1 até a quantidade solicitada, `NAME = hbbridge-<ID>` e `AMOUNT = ID / 4`,
projetado como `DECIMAL(15,2)`. Cinco relações constantes de dígitos permitem
de 1 a 100000 registros sem consultar ou alterar tabelas do ERP. Esse intervalo
pertence à massa, não à capacidade de consultas ou payload do hbBridge.
O perfil é um alias opaco explícito; nenhum banco de demonstração ou do
Protheus é presumido.

Compile todos os fontes deste diretório com toda a árvore `src/tlpp`.
O teste requer um processo hbBridge existente com o perfil MSSQL selecionado
e listeners TCP/HTTP. O benchmark não reinicia serviços nem altera configurações.

## Benchmark visual

Execute `U_HBBridgeBenchmark()` na interface Protheus com FWWebEx e
`FWWebEx.Tools.FWExampleTools` instalados no RPO. A página segue o
[exemplo de tabela HTTP](../hbbridge.http.table.test/README.pt-BR.md) e utiliza
o mesmo núcleo de medição do benchmark de linha de comando. Os gráficos de
média e iteração usam SVG, com os valores exatos nas tabelas, sem biblioteca
adicional de gráficos. FWWebEx é dependência opcional do consumidor visual,
não do núcleo.

O formulário possui cinco campos numéricos: registros por iteração, registros
por página, iterações medidas, aquecimentos e timeout por requisição em segundos.
Perfil, destino TCP, URL HTTP e token HTTP são selecionados no AppServer;
o navegador não fornece SQL, credenciais nem outro destino/perfil.
`U_HBBridgeBenchmark()` lê a seção `[hbBridge]` ativa, incluindo `SQLProfile`.
Parâmetros confiáveis explícitos podem ser fornecidos pelo TLPP:

```tlpp
HBBridge.Examples.HBBridgeBenchmarkExample():Show("MSSQL/pData", ;
    "127.0.0.1", 1512, "http://127.0.0.1:8080", cToken, 30)
```

A página exibe situação completa/parcial, médias TCP e HTTP, quantidades de
registros/chamadas medidas, mínimos/máximos, latência por iteração e observações
de aquecimento separadas. Amostras ausentes ou com falha geram lacunas nos
gráficos; resultados parciais continuam marcados como falha. Séries grandes
usam amostragem na apresentação; o JSON mantém todas as amostras. A memória
continua explicitamente indisponível quando não medida externamente. O tempo
não identifica a política de pooling físico.

`Export JSON` baixa o relatório completo. `Export HTML report` baixa uma
página independente com tabelas e gráficos SVG renderizados, sem formulário de
execução, canal ou scripts. O HTML preserva os gráficos amostrados e a tabela
de aquecimento exibidos; preserve o JSON para obter todas as amostras em formato
processável. Não há exportação CSV.

Cada diálogo mantém apenas uma requisição pendente. O aviso de espera não
cancela o processamento no AppServer nem permite outra rodada. Fechar a página
remove seu receptor; não cancela um benchmark em execução. Identificadores de
instância/requisição rejeitam respostas antigas. Contagens grandes podem manter
o callback síncrono do AppServer executando por bastante tempo; iniciar pelos
padrões.

`U_HBBridgeBenchmarkVisualTest()` é a regressão determinística separada do
controlador, sem executar SQL/HTTP. Os acréscimos visuais e de ciclo de vida
exigem compilação/aceitação próprias; os resultados anteriores do M08 abaixo
mantêm seu escopo original. M09 e D03 continuam pendentes no WIP ativo.

## Medição programática e linha de comando

`HBBridge.Test.HBBridgeBenchmarkTest():Measure(...)` recebe os mesmos argumentos
de `Run(...)` e retorna o relatório `JSONObject` ao chamador, sem imprimir o
resumo. O chamador mantém a propriedade do objeto retornado e o libera com
`FreeObj(@jReport)` após consultar ou exportar os resultados. `Run(...)` mantém
o retorno numérico 0/1 e o resumo no console. O controlador visual utiliza
`Measure`, preservando massa, validações, relógio e estatísticas.

```tlpp
cToken := GetPvProfString("hbBridge", "HTTPToken", "", GetSrvIniName())
nResult := U_HBBridgeBenchmarkTest("MSSQL/pData", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 1000, 100, 5, 2)
```

A ordem dos argumentos é perfil, host TCP, porta TCP, URL HTTP, token HTTP,
timeout por requisição em segundos, registros por iteração, tamanho da página,
iterações medidas e iterações de aquecimento. Apenas o perfil é obrigatório.
Configurações de transporte omitidas usam Host, Port, HTTPURL e HTTPToken da
seção `[hbBridge]` do AppServer ativo. Os padrões numéricos são 30 segundos,
1000 registros, 100 registros por página, cinco iterações medidas e dois
aquecimentos. O tamanho de página aceita 1 a 100000; iterações medidas aceitam
1 a 1000000 e aquecimentos aceitam 0 a 1000000. São contagens do teste,
não limites do produto.

Para um ambiente licenciado de linha de comando do AppServer, use o INI CLI
privado descrito no [guia de falhas](../hbbridge.failure.test/README.pt-BR.md):

```bat
appserver.exe -ini="private-benchmark.ini" -run=U_HBBridgeBenchmarkCLI -env=PROTHEUS --profile=MSSQL/pData --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
```

As flags opcionais `--host`, `--port`, `--url` e `--token` sobrescrevem essas
configurações; prefira o INI privado para credenciais. Flags reconhecidas devem
ser únicas e usar `--nome=valor`. Números exigem inteiros decimais canônicos;
apenas `--warmup` permite zero. O CLI reutiliza o array variádico nativo;
objetos JSON com chaves armazenam amostras e relatórios. Respostas, descrições
de exceção, SQL completo, endpoints e tokens não são registrados.

Cada cenário usa concorrência **1**, primeiro TCP e depois HTTP. Cada um executa
seu próprio aquecimento antes das iterações medidas. Uma iteração abre a
primeira página, busca todas as seguintes com o dataset real, valida todos os
IDs/nomes/valores, ordem das colunas e totais, e fecha o dataset. Ambos os
transportes usam o mesmo SQL e a ordenação `ID ASC`. Cada página corresponde
a uma requisição RPC e também executa o COUNT do produto. Com os padrões,
cada transporte executa 20 requisições de aquecimento e 50 medidas, lendo
2000 registros no aquecimento e 5000 nas medições. A referência não inclui
`StartJob`, barreiras de prontidão ou pausas na criação de workers.

O relógio normalizado `HBBridgeTime`/`TimeCounter` mede a varredura completa,
incluindo rede, processamento JSON/dataset, validação dos valores e fechamento.
A construção dos clientes fica fora do cronômetro da iteração. Regressão do
contador reprova o teste. Amostras de aquecimento ficam visíveis, mas não entram
em total/mínimo/máximo/média medidos. As estatísticas usam apenas iterações
medidas bem-sucedidas; compare rodadas apenas quando o relatório completo tiver
`success=true` e a entrada pública retornar 0. Falha no aquecimento ou na
iteração interrompe aquele cenário; as falhas permanecem no relatório.

O resumo é um registro JSON `hbBridge benchmark summary:` com massa, volume,
iterações, concorrência, ordem dos transportes e amostras por iteração.
A memória é explicitamente `UNAVAILABLE` neste teste TLPP: nenhuma API privada
ou não verificada é usada. Amostragem externa do processo AppServer pode
complementar o relatório; memória do processo inclui runtime compartilhado e
outras atividades, não representa alocações desta thread nem prova ausência
de vazamentos. Preserve versões de AppServer, hbBridge e ODBC, configuração
do host, modo de pooling, origem da medida de memória e intervalo de amostragem.
Pooling físico não é deduzido de consultas bem-sucedidas ou aquecimento.
A ordem fixa dos transportes e os caches compartilhados do servidor/SQL limitam
comparações. A referência não cria meta de velocidade e não aceita a integridade
de texto/FLOAT pendente no D03.

Validação confirmada em 2026-10-16: os 34 fontes TLPP compilaram com zero
erros de fonte, incluindo esta classe/entrada. A finalização do compilador
retornou 0xC0000409 separadamente; os serviços normais foram restaurados.
A execução CLI real no AppServer passou nas duas rotas com saída 0: cinco
varreduras medidas/50 chamadas/5000 linhas por rota, além de dois aquecimentos
cada. Médias por varredura completa: 1118.14 ms TCP e 1491.91 ms HTTP, no servidor
isolado identificado com política ODBC driver. A memória externa cobre o ciclo
combinado do processo, sem separação por transporte.
[Evidências e limites](../../../../../docs/acceptance.pt-BR.md#m08-performance-baseline-on-2026-10-16).

O parser AppServer testado exige INI CLI privado junto ao executável e apenas
o nome no argumento `-ini` entre aspas; rejeita informações de diretório.
O executor nativo disponibiliza destino isolado com `-Route http -ServeSeconds 600`;
usar portas/perfil de `http/endpoints.json` e o token público exclusivo da fixture.
Consultar [metodologia](../../../../../docs/benchmarking.pt-BR.md).

Validação manual adicional registrada às 04:53:47 São Paulo em 2026-10-16:
as duas rotas passaram nas cinco varreduras medidas e dois aquecimentos cada.
Médias por varredura de 1000 linhas: 1039.60 ms TCP e 1122.12 ms HTTP.
Memória indisponível; pool/build/saída do processo não informados nesse resumo.
Preservar seu escopo separado da execução automatizada.
[Evidência manual](../../../../../docs/acceptance.pt-BR.md#m08-manual-protheus-validation-on-2026-10-16).

## Rodada manual extensa e ciclo de vida do componente cliente

A nova rodada manual de 2026-10-16, identificador
`93A0CC16D629E74FAA54843567C86E58`, iniciou às 07:09:41 São Paulo com 100000
registros, páginas de 10000, 500 iterações medidas, dois aquecimentos e timeout
de 30 segundos por requisição. Essa rodada usou a mitigação temporária com
socket estático no módulo. TCP completou as 500 varreduras medidas:
5000 chamadas e 50000000 registros, com média de 7747.32 ms por varredura.
HTTP completou 135 varreduras medidas/1350 chamadas/13500000 registros.
Sua iteração medida 136 falhou na primeira requisição após 30020.8344 ms,
sem ler registros/páginas, com `QUERY_FAILED`. O benchmark completo está
**FAILED**.

A duração é compatível com o prazo configurado, mas esse relatório anterior
não contém status HTTP nem código do serviço. Não comprova falha no SQL nem
a origem da demora. Essa rodada não contém novo erro fatal de componentes do
terminal. Registro preservado:
`tmp/protheus-benchmark-large-static-20261016-93a0cc16.log`, SHA-256
`AC62382489B97B9CC00B41C1010A8AC5D9C60A6A3D24BEBDB444A403C4FCC986`.

O cliente TCP atual mantém um `TSocketClient` criado sob demanda por instância
de `HBBridgeClient`; reutiliza o componente nativo, abrindo/fechando uma conexão
TCP a cada requisição. Oferece `Close()` explícito e idempotente; o núcleo de
medição fecha o cliente que criou. Essa implementação substitui a mitigação
estática temporária e a criação anterior de um componente por chamada. O
[teste específico do ciclo de vida](../hbbridge.client.lifecycle.test/README.pt-BR.md)
executa 6000 pequenas requisições Health, sem repetir a carga SQL extensa.
Sua aceitação é separada; reutilizar o componente não comprova ausência de
vazamentos no alocador/registro nativo do terminal. Relatórios novos preservam
diagnósticos seguros de fase/iteração/página da falha, status HTTP e código do
serviço quando disponíveis.
