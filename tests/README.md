# Testes

[protheus/hbbridgeconnectiontest.tlpp](protheus/hbbridgeconnectiontest.tlpp) e o teste manual do MVP. Com o
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

[harbour/server_mt.prg](harbour/server_mt.prg), com entrada `MTTests`, contem
verificacoes automatizadas de concorrencia, clientes ociosos, erros, limite de
workers e parada. Inclui `Echo` e resposta de erro com `HBBRIDGE/1` e `HBS1`,
conferindo que o servidor responde com a assinatura recebida. Atualize o servidor
antes do cliente TLPP; aceitar respostas antigas nao torna um servidor antigo
capaz de receber a nova assinatura.

Os cenarios de addons sao condicionais e emitem `SKIP` quando os HRBs de teste
nao existem. Seu preparo ainda precisa alinhar as chamadas do teste (sem extensao)
aos nomes dos arquivos `.hrb` preparados para o loader. O helper de conexao tambem usa
`0.0.0.0` como destino: ajustar para `127.0.0.1` antes de homologar a suite em
Windows/Linux. A presenca desses testes nao significa que todos os cenarios
foram executados ou aprovados no ambiente alvo.

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
