# Testes

`protheus/HBBridgeConnectionTest.tlpp` e o teste manual do MVP. Com o
servidor em execucao em `127.0.0.1:1512` e o cliente TLPP compilado no
Protheus, execute `U_HBBridgeConnectionTest()`.

O teste chama `Health` e `Echo` pelo cliente `THBBridgeClient`. As chamadas
usam JSON no frame `HBS1`, com compressao e descompressao de strings nos
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
biblioteca Zig demonstrativa do build atual. O repositorio nao inclui uma
suite automatizada nem evidencia de execucao anexada a este teste.

## Proximas verificacoes

- Comparar integralmente os dados recebidos, incluindo acentos, caracteres
  multibyte, valores nulos e estruturas JSON aninhadas.
- Testar dados pouco compressiveis, fragmentacao TCP e envios parciais.
- Testar limites de bytes comprimidos e descomprimidos, truncamento,
  timeout e entradas invalidas.
- Validar a adaptacao do contrato Protheus ao RPC nativo do `hbnetio`;
  `HBS1` nao e seu protocolo de rede.
- Validar acesso a dados reutilizando RDDSQL/SQLMIX e as contribs Harbour
  selecionadas, antes de ampliar a engine Zig.

`hb_Serialize()`/`hb_Deserialize()`, com ou sem `HB_SERIALIZE_COMPRESS`,
podem ter testes proprios para clientes Harbour quando esse caminho for
integrado. O servidor atual nao implementa `HB_SERIALIZED`, e esses testes
nao substituem a verificacao de interoperabilidade com o Protheus.
