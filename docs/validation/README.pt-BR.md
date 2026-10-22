# Validação reproduzível

[English](README.md) · [Histórico de homologação](../acceptance.pt-BR.md)

`tmp/` é inteiramente descartável. Logs, executáveis, cópias privadas de RPO,
ponteiros `*-current.txt` e scripts avulsos ali não são dependências do projeto.
`out/` contém entregáveis gerados; `.deps/` é o cache de dependências gerenciado.

| Entrada ou resultado | Local permanente |
| --- | --- |
| Fontes do produto e addons | `src/`, `addons/` |
| Testes, fixtures SQL e probes reproduzíveis | `tests/` e `src/tlpp/tests/` |
| Entradas de compilação/testes/manutenção | `scripts/` |
| Exemplos públicos de configuração e versões fixadas | `config/examples/`, `config/dependencies.json` |
| Escopo aceito, contagens, metodologia e limitações | `docs/acceptance.pt-BR.md` e resumos aqui |
| Licenças, SDK/RPO, credenciais/INI privados e bancos | Pré-requisitos externos explícitos; não versionar cópias |
| Objetos, HRBs gerados, RPOs copiados, logs e relatórios | `tmp/`/`out/` descartáveis; arquivo externo deliberado opcional |

Os resumos JSON mantêm identidades/contagens sanitizadas do momento da medição:

- [Encerramento do pacote 001](package001.windows.mssql.json).
- [Revisão das convenções de fonte](source.standards.windows.json).

Essas identidades descrevem o snapshot datado, não o checkout atual. Menções
históricas a `tmp/...` registram onde a saída foi gravada, sem garantir sua
existência atual nem impedir exclusão. Nova execução gera nova observação/log;
tempos e estado exatos da máquina no passado não são recriados pelo fonte.
Arquivar evidência bruta externamente somente quando esse histórico for
necessário; ela não é pré-requisito de compilação.

## Reproduzir a partir dos fontes

Resolva as [dependências fixadas](../dependencies.pt-BR.md) e use as entradas
mantidas. Cada runner cria suas próprias pastas de trabalho da rodada atual:

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
./scripts/test-harbour-thread-state.ps1
./tests/unit/scripts/clean.artifacts.test.ps1
./scripts/check-doc-links.ps1
./scripts/commit-check.ps1
```

MSSQL exige ainda driver configurado, banco acessível e INI privado preparado
com os exemplos públicos. Informe caminho e alias explícito; nenhuma pasta
de teste anterior é entrada:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config '<ini-privado>' -Profile '<alias>'
./scripts/test-hbbridge-mssql.ps1 -Config '<ini-privado>' -Profile '<alias>' -Integrity
./scripts/test-hbbridge-mssql.ps1 -Config '<ini-privado>' -Profile '<alias>' -Failures `
    -FailureODBCDriver 'ODBC Driver 18 for SQL Server'
./scripts/test-hbbridge-mssql.ps1 -Config '<ini-privado>' -Profile '<alias>' -Concurrency
./scripts/test-hbbridge-mssql.ps1 -Config '<ini-privado>' -Profile '<alias>' -Pooling -ODBCPooling driver
./scripts/test-hbbridge-benchmark-addon.ps1
```

AppServer exige SDK/RPO licenciados e ambiente de testes configurado
explicitamente. Compile `src/tlpp` atual por `build-totvs.cmd`, com os argumentos
documentados de instalação/includes. Use INI dedicado, com portas próprias
e o RPO compilado, e execute o launcher versionado:

```powershell
./scripts/run-protheus-cli.ps1 -AppServerDirectory '<appserver-teste>' `
    -IniFile '<ini-teste-dedicado>' -Program U_HBBridgeJSONTest
```

Outras suítes fechadas: `U_HBBridgeDataSetTest`, `U_HBBridgeHelperTest`,
`U_HBBridgeHTTPTableTest`, `U_HBBridgeBenchmarkVisualTest` e
`U_HBBridgeBenchmarkRESTTest`. O launcher informa saída real e caminho do log,
sem deduzir aprovação de asserções. Algumas procedures retornam -4 ao processo
sem retorno CLI numérico; examine seus resumos completos. Ele não substitui
INI/RPO nem encerra serviço existente. Seu timeout afeta somente o filho
iniciado. Conteúdo do INI e valores dos argumentos não são copiados ao recibo;
saída bruta permanece como temporário local.

Para integridade TCP/HTTP real, inicie o runner MSSQL mantido com `-Integrity
-Serve` em outro terminal e passe os endpoints dessa rodada ativa para
`U_HBBridgeIntegrityCLI` pelo array `-Argument` do launcher. Portas/tokens de
rodadas antigas não são pré-requisitos reutilizáveis. Veja [D03](../dataset.pt-BR.md)
e os READMEs dos testes para contratos completos e cenários manuais de interface.
