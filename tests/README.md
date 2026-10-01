# Testes

[integration/protheus/hbbridgeconnectiontest.tlpp](integration/protheus/hbbridgeconnectiontest.tlpp) e o teste manual do MVP. Com o
servidor escutando em `0.0.0.0:1512`, configure o cliente local para
`127.0.0.1:1512`. Com o cliente TLPP compilado no Protheus, execute `U_HBBridgeConnectionTest()`.

O teste chama `Health`, `Echo` e `ADDON.examples\sample_addon.prg` (macro
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitada) pelo cliente `THBBridgeClient`.
As chamadas usam JSON no frame `HBBRIDGE/1`, com compressao e descompressao de strings nos
dois sentidos: `GzStrComp`/`GzStrDecomp` no Protheus e
`hb_ZUncompress`/`hb_gzCompress` no Harbour. O frame completo e comprimido;
o tamanho declarado no cabecalho corresponde aos bytes do JSON
descomprimido.

O teste verifica o indicador `success`, a mensagem devolvida pelo `Echo` e
o comprimento de `largePayload`, que contem 200.000 caracteres `X`. Esse
dado e altamente compressivel: a verificacao demonstra o retorno de um
payload logico grande, mas nao comprova o tratamento de um fluxo binario
comprimido fragmentado em varios blocos TCP. Tambem nao compara o conteudo
integral de `largePayload`.

O resultado aparece no console do Protheus. `Health` ainda depende da
biblioteca Zig demonstrativa do build atual. Compilar e executar o teste TLPP
no AppServer alvo continua necessario para homologar a interoperabilidade.

## Regressoes Harbour existentes

[integration/harbour/server_mt.prg](integration/harbour/server_mt.prg), com entrada `MTTests`, contem
verificacoes automatizadas de concorrencia, clientes ociosos, erros, limite de
workers e parada. Inclui `Echo` e resposta de erro com `HBBRIDGE/1` e `HBS1`,
conferindo que o servidor responde com a assinatura recebida. Atualize o servidor
antes do cliente TLPP; aceitar respostas antigas nao torna um servidor antigo
capaz de receber a nova assinatura.

A suite tambem exercita `Health` pela ponte C/Zig e a compilacao em memoria
do addon PRG de exemplo. Os clientes de teste usam `127.0.0.1` e as chamadas
das fixtures apontam explicitamente para os arquivos `.hrb` preparados.

Na raiz do projeto, com Zig no PATH e Harbour compilado com Zig:

```powershell
.\scripts\test-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

O [runner](../scripts/test-hbbridge.ps1) compila a biblioteca Zig, prepara as
fixtures em uma pasta exclusiva sob `tmp/` e compila
[server_mt.hbp](integration/harbour/server_mt.hbp). Esse projeto compartilha
[hbbridge.hbm](../hbbridge.hbm) com o produto, sem copiar os fontes do servidor.
O runner executa os testes com os addons isolados, registra `results.log` e
devolve o codigo de saida da suite. Nao substitui nem encerra `out/hbBridge.exe`.
Executada manualmente sem fixtures, a suite ainda informa `SKIP`; o runner
prepara ambas antes da execucao e a validacao registrada nao teve skips.

Validacao de 2026-10-01: **74 verificacoes, zero falhas**, incluindo HRBs de erro
e isolamento concorrente. A [comparacao com o MVP](../docs/reorganizacao.md)
explica as correcoes de preparo da suite e a referencia anterior com 72 checks.
O teste TLPP real depende do AppServer e nao foi executado nessa validacao.

`unit/` e `contract/` reservam as proximas suites. As verificacoes existentes de
assinatura continuam nesta integracao ate a extracao do contrato comum.

## Proximas verificacoes

- Validar chamadas sequenciais persistentes antes de pool e multiplexacao;
  verificar fragmentacao/coalescencia, desconexao e ausencia de reenvio indevido.
- Testar isolamento por chamada e propriedade/expiracao dos recursos de sessao,
  incluindo uso por tenant incorreto e limpeza apos falha.
- Homologar TLS/JWT no AppServer real; manter gRPC/Smartlink e AMQP como provas
  opcionais com criterios em [Transportes, sessoes e seguranca](../docs/transportes-sessoes-seguranca.md).
- Comparar integralmente os dados recebidos, incluindo acentos, caracteres
  multibyte, valores nulos e estruturas JSON aninhadas.
- Testar dados pouco compressiveis, fragmentacao TCP e envios parciais.
- Testar limites de bytes comprimidos e descomprimidos, truncamento,
  timeout e entradas invalidas.
- Validar a adaptacao do contrato Protheus ao RPC nativo do `hbnetio`;
  `HBBRIDGE/1`/`HBS1` nao e seu protocolo de rede.
- Validar acesso a dados reutilizando RDDSQL/SQLMIX e as contribs Harbour
  selecionadas, antes de ampliar a engine Zig.

`hb_Serialize()`/`hb_Deserialize()`, com ou sem `HB_SERIALIZE_COMPRESS`,
podem ter testes proprios para clientes Harbour quando esse caminho for
integrado. O servidor atual nao implementa `HB_SERIALIZED`, e esses testes
nao substituem a verificacao de interoperabilidade com o Protheus.
