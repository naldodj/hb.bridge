# Probe gzip do FWRest

[English](README.md) · [Contrato HTTP](../../../../../docs/http.pt-BR.md)

`U_HBBridgeHTTPGzipProbe` compara o resultado intacto do FWRest instalado com
resposta UTF-8 conhecida e depois diagnostica descompressão nativa. Cobre
identity, gzip, blocos HTTP de sete bytes, CRC corrompido e recuperação.
O cliente HTTP hbBridge real também verifica gzip/identity, NUL interno,
falha/recuperação de descompressão e configuração de encoding inválida.
Os checks de gzip obrigatório cobrem resposta aceita, rejeição de fallback
identity, 406 vazio e opções contraditórias do construtor.

Usar o executor isolado com SDK licenciado, INI e includes externos:

```powershell
./scripts/test-protheus-http-gzip.ps1 `
    -AppServerDirectory <diretorio-AppServer> -IniFile <INI-externo> `
    -IncludeDirectory <includes-fornecedor> -CompileAll
```

Copia SDK/RPO base para diretório descartável novo, cria INI, custom RPO e
fixture HTTP próprios em loopback e compila os três fontes necessários (todo
o TLPP do projeto com `-CompileAll`). Não altera configuração instalada,
interrompe AppServer existente nem depende de artefato tmp anterior. O INI
externo deve fornecer SourcePath do ambiente escolhido e LicenseClient.
Python 3 é pré-requisito explícito desta fixture, sem dependência no produto.

Aceitar apenas compilação completa e marcador final de 14 checks/zero falhas,
com saída 0. Logs brutos ficam no scratch privado; INI/SDK não são versionados.
A fixture é deliberadamente repetitiva: sua taxa de compressão não prevê
resultados SQL ou desempenho em produção. Gzip nativo e falhas do socket
hbBridge têm [checks HTTP separados](../../../../../tests/README.pt-BR.md).

A rodada Windows de 2026-10-24 compilou os 55 fontes TLPP com zero erros e
passou nos 14 checks, saída 0. Confirma o comportamento do FWRest instalado
e o contrato do cliente; tempos SQL reais têm
[escopo datado separado](../../../../../docs/http.pt-BR.md#http-review-on-2026-10-24).

Para diagnosticar as etapas, iniciar uma fixture MSSQL M08 nova em modo serve:

```powershell
./scripts/profile-protheus-http.ps1 `
    -AppServerDirectory <diretorio-AppServer> -IniFile <INI-externo> `
    -IncludeDirectory <includes-TOTVS> -EndpointsFile <endpoints.json-novo>
```

O runner cria seu SDK/RPO, compila o probe e compara cinco requisições medidas
identity/gzip mais um aquecimento por codificação. Mede FWRest incluindo
servidor/rede, descompressão, parsing JSON e validação direta das 10000 linhas;
custo do dataset e estatísticas M08 completas ficam fora desse diagnóstico.
O benchmark real continua exigindo gzip.
