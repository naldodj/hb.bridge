# Padrões de nomes, fontes e contribuição

[English](standards.md)

Use quatro espaços nos fontes próprios. Os utilitários Harbour importados e
os cabeçalhos zlib preservam sua formatação e seus avisos. Identificadores são
em inglês. Arquivos ficam em minúsculas; funções, procedures, métodos,
namespaces e classes usam PascalCase, conforme esclarecimento explícito do responsável.
Nomes convencionais Git e o sufixo `.pt-BR` são exceções às minúsculas.

| Responsabilidade | Classe / arquivo TLPP | Módulo Harbour |
| --- | --- | --- |
| Cliente | `HBBridgeClient` / `hbbridgeclient.tlpp` | Clientes nativos usam NETIO; não se introduz classe redundante. |
| Cliente HTTP | `HBBridgeHTTPClient` / `hbbridgehttpclient.tlpp` | `transports/http/hbbridgehttp.prg` adapta HTTP ao registro comum. |
| Configuração | `HBBridgeConfig` / `hbbridgeconfig.tlpp` | `host/hbbridgeconfig.prg` e `host/hbbridgeini.prg` configuram o servidor. |
| Tempo | `HBBridgeTime` / `hbbridgetime.tlpp` | `src/c/hbbridgetime.c` implementa o relógio monotônico do servidor. |
| Dataset SQL | `HBBridgeRPCDataSet` / `hbbridgerpcdataset.tlpp` | `services/hbbridgequery.prg` atende consultas SQL. |

Os nomes relacionam responsabilidades; os papéis de cliente e servidor são
preservados. Módulos procedurais Harbour não precisam de classes vazias para
imitar TLPP. Futuras classes Harbour também devem estar em arquivo cujo nome
de base seja o nome da classe em minúsculas.

Exemplos: `HBBridge.Client.HBBridgeClient():New()` e
`HBBridge.RDD.HBBridgeRPCDataSet():OpenSQL(...)`. Entradas `U_` mantêm os nomes
publicados. Utilitários públicos Protheus ficam em classes com namespace e
métodos estáticos quando não há estado. Helpers estáticos locais são
permitidos. APIs externas (`JSONObject`, `TimeCounter`, `hb_Serialize`), campos
de protocolo e macros C exigidas pelo compilador mantêm a grafia definida.

Prefira hashes/objetos para dados nomeados. Arrays exigem API nativa ou
contrato concreto, como endereços de socket, argumentos SQLRDD ou blocos do
codec. Explique a justificativa junto ao código.

O produto tem uma implementação em `src/`. Exemplos iniciam esse produto;
testes exercitam os mesmos componentes. `examples/mvp` registra a origem do
exemplo, sem representar outro produto ou contrato.

Use `THREAD STATIC` para estado Harbour mutável pertencente à thread worker;
estado da requisição usa locais/parâmetros ou inicialização explícita. A thread
reutilizada pode conservar valores entre requisições e recargas HRB. Mutexes
do processo e recursos compartilhados continuam em estáticos sincronizados.
Veja a [análise do runtime](evolution.pt-BR.md#estado-da-thread-e-estado-da-requisição).

A documentação inglesa usa o nome de base; a portuguesa acrescenta `.pt-BR`
antes da extensão. Atualize ambas e preserve aceites, limitações e pendências.
Caminhos históricos do changelog descrevem os arquivos existentes na época;
instruções atuais usam os nomes novos.

O [build gerenciado](dependencies.pt-BR.md) mantém dependências em `.deps/`.
`.hbcommit/` contém manutenção, sem outro runtime. Execute o
[crivo de commit](../scripts/README.pt-BR.md) antes de cada commit: os três
utilitários Harbour devem passar. A validação não corrige arquivos, aplica
patches de terceiros nem prepara o índice. Preserve as licenças upstream
independentemente da [decisão de licença do produto](licensing.pt-BR.md).
