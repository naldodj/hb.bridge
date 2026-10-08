# Padrões de nomes, fontes e contribuição

[English](standards.md)

Use quatro espaços nos fontes próprios. Os utilitários Harbour importados e
os cabeçalhos zlib preservam sua formatação e seus avisos. Identificadores são
em inglês. Arquivos ficam em minúsculas; funções, procedures, métodos,
namespaces e classes usam PascalCase, conforme esclarecimento explícito do responsável.
Nomes convencionais Git e o sufixo `.pt-BR` são exceções às minúsculas.

Módulos Harbour próprios, testes e addons usam `.hb`; fontes upstream
importados mantêm `.prg`. Entradas `.prg` externas/do runtime continuam
suportadas. Essa convenção de extensão preserva a linguagem Harbour e os
nomes dos módulos. GitHub Linguist classifica `.hb` e `.prg` como xBase,
e ambos passam pelas regras de arquivo de classe, declarações PascalCase
e indentação de quatro espaços. Ferramentas de manutenção importadas e
fontes de terceiros mantêm suas exceções.

O `hbmk2` compila entradas de fonte `.hb` em arquivos de build `.hbp` e `.hbm`.
Na linha de comando, um caminho `.hb` como primeiro argumento seleciona
execução de script, como no `hbrun`. Na compilação direta, ponha `-hbexe`
antes do caminho para gerar executável, ou `-gh` antes dele para gerar HRB:
`hbmk2 -hbexe module.hb` ou `hbmk2 -gh module.hb`.

| Responsabilidade | Classe / arquivo TLPP | Módulo Harbour |
| --- | --- | --- |
| Cliente | `HBBridgeClient` / `hbbridgeclient.tlpp` | Clientes nativos usam NETIO; não se introduz classe redundante. |
| Cliente HTTP | `HBBridgeHTTPClient` / `hbbridgehttpclient.tlpp` | `transports/http/hbbridgehttp.hb` adapta HTTP ao registro comum. |
| Configuração | `HBBridgeConfig` / `hbbridgeconfig.tlpp` | `host/hbbridgeconfig.hb` e `host/hbbridgeini.hb` configuram o servidor. |
| Tempo | `HBBridgeTime` / `hbbridgetime.tlpp` | `src/c/hbbridgetime.c` implementa o relógio monotônico do servidor. |
| Dataset SQL | `HBBridgeRPCDataSet` / `hbbridgerpcdataset.tlpp` | `services/hbbridgequery.hb` atende consultas SQL. |

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

## Pacotes de trabalho ativos

Os nomes solicitados `WIP.md` e `WIP.pt-BR.md` são exceções explícitas às
minúsculas. [WIP](../WIP.pt-BR.md) contém objetivo, tarefas ordenadas, decisões,
pré-requisitos, progresso, evidências e critérios de conclusão de um pacote
ativo. TODO mantém o roadmap completo; homologação e ChangeLog registram
resultados/histórico. Leia WIP para retomar a próxima tarefa sem reiniciar a análise.

Atualize ambas as versões durante o pacote. Reveja decisões somente por novas
evidências/falhas, mudanças de requisito/dependência ou instruções do usuário,
registrando o motivo. Encerre com evidências atribuíveis, concilie TODO e
preserve o resumo na homologação/ChangeLog antes de renovar os mesmos arquivos
para o próximo pacote delimitado. Commits/publicação independem do encerramento
e não apagam tarefas pendentes. Git mantém as versões anteriores do WIP.

O [build gerenciado](dependencies.pt-BR.md) mantém dependências em `.deps/`.
`.hbcommit/` contém manutenção, sem outro runtime. Execute o
[crivo de commit](../scripts/README.pt-BR.md) antes de cada commit: os três
utilitários Harbour devem passar. A validação não corrige arquivos, aplica
patches de terceiros nem prepara o índice. Preserve as licenças upstream
independentemente da [decisão de licença do produto](licensing.pt-BR.md).
