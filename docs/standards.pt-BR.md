# Padrões de nomes, fontes e contribuição

[English](standards.md)

Use quatro espaços nos fontes próprios. Os utilitários Harbour importados e
os cabeçalhos zlib preservam sua formatação e seus avisos. Identificadores são
em inglês. Arquivos ficam em minúsculas; funções, procedures, métodos,
namespaces e classes usam PascalCase.
Nomes convencionais Git e o sufixo `.pt-BR` são exceções às minúsculas.

Agrupe declarações de variáveis por tipo de dado, com uma linha em branco
entre grupos, e ordene os grupos alfabeticamente pelo prefixo do tipo: por
exemplo `a` (array), `c` (caractere), `d` (data), `j` (JSON), `l` (lógico),
`n` (numérico), `o` (objeto), `x` (variante). Os nomes completos dentro do
grupo não precisam de ordem alfabética. Preserve dependências de
inicialização; separe declaração e atribuição quando a ordem alterar o
comportamento. Aplique agrupamento por tipo equivalente nas linguagens
com outras convenções de declaração.

Resolva constantes e cálculos invariantes antes do loop: por exemplo
`cNul := Chr(0)` e `nLength := Len(cText)` quando `cText` não muda.
Calcule valores variáveis uma vez por iteração quando útil. Não antecipe
relógios, E/S, verificações de estado mutável nem tamanhos de contêineres que
crescem/diminuem durante a iteração. O valor armazenado precisa continuar
válido durante todo o loop.

Na conversão numérica comum para texto em TLPP, use `tlpp.ToStr(nValue)` em vez
de `AllTrim(Str(nValue))`. Formatação com largura, escala decimal ou máscara
exigida continua explícita; a conversão genérica não pode substituir esse
contrato silenciosamente. Escreva condições por alias como `(cAlias)->(!Eof())`,
mantendo a negação dentro da expressão da área selecionada.

Os fontes separam palavras minúsculas por pontos, como
`hbbridge.rpc.dataset.tlpp`. Remover os pontos deve produzir o nome da classe
`HBBridgeRPCDataSet` em minúsculas. Isso não muda os namespaces.
Erros, logs e rótulos próprios usam inglês; textos externos e fixtures
intencionais de acentos/codificação preservam seu idioma. A documentação
portuguesa permanece nos arquivos pareados `.pt-BR`.

Redija documentação de forma impessoal. Registre decisões e resultados como
"Validação confirmada" ou "Validação registrada", com datas e artefatos.
Descreva execuções manuais no AppServer e verificações automatizadas locais
pelo método e pelas evidências, preservando escopo, limitações e aceites pendentes.

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
| Cliente | `HBBridgeClient` / `hbbridge.client.tlpp` | Clientes nativos usam NETIO; não se introduz classe redundante. |
| Cliente HTTP | `HBBridgeHTTPClient` / `hbbridge.http.client.tlpp` | `transports/http/hbbridge.http.hb` adapta HTTP ao registro comum. |
| Configuração | `HBBridgeConfig` / `hbbridge.config.tlpp` | `host/hbbridge.config.hb` e `host/hbbridge.ini.hb` configuram o servidor. |
| Tempo | `HBBridgeTime` / `hbbridge.time.tlpp` | `src/c/hbbridge.time.c` implementa o relógio monotônico do servidor. |
| Dataset SQL | `HBBridgeRPCDataSet` / `hbbridge.rpc.dataset.tlpp` | `services/hbbridge.query.hb` atende consultas SQL. |

Os nomes relacionam responsabilidades; os papéis de cliente e servidor são
preservados. Módulos procedurais Harbour não precisam de classes vazias para
imitar TLPP. Futuras classes Harbour também devem estar em arquivo cujo nome
de base, removidos os pontos, seja o nome da classe em minúsculas.

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

## SETs do runtime e contratos numéricos

Preserve os padrões nativos de apresentação do Harbour (`DECIMALS 2`, `FIXED OFF`);
aumentar `SET DECIMALS` não corrige a serialização. O núcleo genérico não
estabelece escala monetária nem acrescenta seção arbitrária de SETs ao INI.
Um requisito funcional precisa identificar cada configuração, seu escopo e
sua restauração antes de introduzir parametrização. Escala lógica e
arredondamento SQL continuam decisões explícitas do chamador.

| Questão | Política |
| --- | --- |
| `SET DECIMALS` / `SET FIXED` | Contexto de apresentação/operação, nunca precisão numérica JSON. Preserve o valor nativo finito com `HBBridgeJSONEncode/Decode`, inclusive na ABI JSON dos addons. |
| Configuração temporária do addon | Salve o valor anterior e restaure em `ALWAYS`, inclusive nos erros. Reutilização de workers e `THREAD STATIC` não reiniciam SETs entre chamadas. |
| Texto JSON/codepage | Adaptadores TCP/HTTP selecionam UTF8EX na execução e restauram a codepage anterior do worker em toda saída. Configurações e credenciais mantêm os bytes originais. |
| Configurações de negócio/DBF | Não deduza `DELETED`, `EXACT`, formato de data, epoch, locks ou regras do ERP a partir de alias SQL. Chamador/addon define o comportamento necessário explicitamente e responde pelas mudanças temporárias. |

Ponto flutuante binário continua aproximado. O codec evita arredondamento
adicional na serialização; não transforma aritmética de ponto flutuante em
decimal exato. CAST/arredondamento SQL explícito e decimal exato textual
mantêm seus papéis documentados. Regressões verificam a ABI do addon com
`DECIMALS 2/18` e `FIXED OFF/ON`, restaurando o contexto anterior do teste.

A documentação inglesa usa o nome de base; a portuguesa acrescenta `.pt-BR`
antes da extensão. Atualize ambas e preserve aceites, limitações e pendências.
Caminhos históricos do changelog descrevem os arquivos existentes na época;
instruções atuais usam os nomes novos.

## Arquivos gerados e reprodução

`tmp/` é descartável por inteiro, incluindo logs, RPOs copiados, fixtures geradas
e ponteiros. Comandos mantidos não exigem rodadas anteriores em tmp. Programas/
probes reutilizáveis pertencem a `src/`, `addons/`, `scripts/` ou `tests/`;
exemplos públicos ficam em `config/examples/`. `out/` contém entregáveis gerados
e `.deps/` contém dependências resolvidas por entradas fixadas. Não versionar
fontes nem evidência permanente em tmp/out.

Manter resumos sanitizados, identidades dos fontes/dependências, comandos e
pré-requisitos externos na [documentação de validação](validation/README.pt-BR.md).
Nova execução gera novo log, sem recriar exatamente estado/tempos históricos.
Arquivos históricos brutos opcionais são externos, nunca pré-requisitos.
Caminhos tmp datados na homologação/ChangeLog descrevem saídas passadas, sem
exigir sua existência atual. Exclusões explícitas da limpeza são escolhas
operacionais temporárias, sem autorizar dependências ocultas.

TLPP usa `#include "totvs.ch"` por padrão. Acrescentar `tlpp-core.th`,
`tlpp-rest.th` ou outros headers somente por símbolos/macros utilizados, como
anotações REST nativas. Namespace/classe por si só não exige includes adicionais.

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
