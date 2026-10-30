# Revisão dos utilitários FWWebEx

[English](fwwebex-tools-review.md) · [Apresentação nativa](native-presentation.pt-BR.md) · [WIP](../WIP.pt-BR.md)

Revisão estática registrada em 2026-10-29 dos utilitários FWWebEx fornecidos e
da sobreposição com hbBridge. Este registro define candidatos e restrições;
não implementa APIs nem adiciona dependência FWWebEx ao núcleo; tampouco
comprova aceitação em execução ou melhoria de desempenho medida.

## Escopo e decisões

Os fontes de referência pertencem a `fw.webex/src/fw.webex/core/tools/` no
repositório FWWebEx. Os sete arquivos solicitados foram revisados:

| Referência | Decisão para hbBridge |
| --- | --- |
| `fw.webex.jsonobject.tools.tlpp` | Primeiro candidato: clone JSON recursivo e restrito, sem reflexão de objetos genéricos. Preservar o codec atual de transporte. |
| `fw.webex.jsonobject.clone.tlpp` | A classe separada apenas encaminha chamadas; preferir uma única API utilitária. |
| `fw.webex.jsonobject.merge.tlpp` | Considerar após definir políticas de profundidade, arrays, NULL e mutação. A classe de encaminhamento não adiciona comportamento. |
| `fw.webex.jsonobject.flatten.tlpp` | Possível recurso de diagnóstico; o formato fornecido é inadequado a contratos genéricos sem perda. |
| `fw.webex.stopwatch.tlpp` | Considerar um pequeno auxiliar de tempo decorrido/fases nomeadas sobre o `HBBridgeTime` existente. |
| `fw.webex.class.base.tlpp` | Não introduzir herança comum no núcleo ou clonagem genérica de recursos. |
| `fw.webex.array.tools.tlpp` | Reaproveitar operações pontuais apenas nas APIs nativas posicionais necessárias; manter registros e consultas por chave. |

## Primeiro candidato: clone defensivo de JSON

`HBBridgeRPCDataSet:Header()`, `FieldInfo()`, `GetRow()` e `GetRows()`, os
snapshots de esquema de `HBBridgeNativeTable` e `TableCopy()` do builder de
apresentação atualmente clonam por `HBBridgeJSON:Encode()` e `Parse()`.
Um clone recursivo direto pode remover essa serialização/parsing adicional e
a string JSON intermediária. O benefício deve ser medido antes de substituir
caminhos aceitos; este registro não afirma ganho de velocidade.

O `CloneJSON()` de referência alcança a cópia recursiva por instâncias
temporárias de `JSONObjectTools` e reflexão/macros de `ClassBase`. hbBridge
precisa apenas de valores JSON: enumerar as chaves de JSONObject uma vez,
copiar contêineres aninhados recursivamente e escalares sem formatação.
Arrays permanecem válidos quando exigidos pela API JSON/nativa; não
substituem registros organizados por chave.

O contrato proposto deve preservar propriedades ausentes versus presentes
com NULL, bytes UTF-8, NUL embutido, strings decimal/int64 exatas e o valor
numérico já mantido pelo SDK. O clone não deve decodificar texto, alterar
SETs, inferir arredondamento ou copiar sockets/conexões. Definir a rejeição
de objetos/blocos nativos não suportados e o comportamento para ciclos ou
recursão excessiva antes de expor a API. O chamador possui o resultado
independente.

As regressões específicas devem cobrir:

- Objetos/arrays vazios e aninhados, arrays mistos e arrays dentro de arrays.
- Chaves ausentes versus NULL; texto vazio, UTF-8 e NUL em todas as posições.
- Strings numéricas exatas, números pequenos/grandes e independência de SETs.
- Mutação de cada contêiner do resultado sem alterar a origem.
- Liberação da origem ou do resultado sem invalidar o outro.
- Falha explícita para valores/ciclos não suportados, liberando alocações parciais.
- Resultados equivalentes e medidas de tempo/alocação frente aos snapshots atuais.

## Restrições de merge e flatten

O `MergeJSON()` fornecido substitui valores no primeiro nível; não combina
recursivamente as propriedades dos objetos já existentes no destino. Seu
ramo de objeto testa `vValue[j]` fora do loop de arrays em vez de `vValue`.
Arrays dentro de arrays são atribuídos por referência. Esses pontos
justificam adaptar a ideia, sem copiar a implementação como deep merge aceito.

Um merge futuro deve definir se altera o destino, combina objetos
recursivamente, substitui ou combina arrays, trata NULL como valor ou
exclusão e como resolve tipos incompatíveis. A validação de configuração/
esquema continua necessária; o merge não pode contornar a verificação de
propriedades permitidas.

Flatten concatena chaves por pontos e colchetes sem contrato de escape.
Por exemplo, a chave literal `a.b` colide com `a`/`b` aninhados. UnFlatten
interpreta strings como `__$O:0` e `__$A:0` como contêineres; assim, texto
comum pode mudar de tipo. Valores de arrays aninhados também podem continuar
compartilhados. Manter esse recurso fora do contrato RPC/HTTP. Um formato
reversível futuro exige caminhos com escape, metadados distintos de
contêineres, tratamento de colisões e testes de ida e volta, incluindo
contêineres vazios e texto literal dos marcadores.

`ToJSObjectString()` gera código JavaScript: emite chaves sem aspas, não
escapa strings comuns de arrays e pode inserir funções por um token
reservado. Isso pertence à construção confiável de UI, não ao transporte
JSON. Preservar `HBBridgeJSON` como fronteira Encode/Parse.

## Medição de tempo, reflexão e arrays nativos

A ideia útil de StopWatch é medir tempo decorrido com fases nomeadas. Um
auxiliar hbBridge deve delegar a leitura do relógio a `HBBridgeTime`, manter
estado por instância e registrar resultados explícitos das operações
separadamente das durações. Não deve substituir os orçamentos das requisições
ou as regras atuais de amostragem, aquecimento, validação e falha do benchmark.

A implementação fornecida também exige adaptação:

- `StartWithDate()` armazena tempo baseado em época, enquanto `Stop()` comum
  e as consultas durante a execução usam `TimeCounter()` normalizado. Misturar
  esses modos subtrai valores de domínios de relógio distintos.
- Subtrair a soma das durações filhas da duração pai desconta repetidamente
  fases sobrepostas; limitar a zero não comprova tempo exclusivo.
- `SuccessRate` é inferido por durações que excedem um limite de timeout;
  isso não comprova sucesso ou falha das operações.
- O contador estático mutável de IDs não deve virar estado compartilhado sem
  sincronização ao ser portado. Usar estado por instância/worker ou UUID
  conforme a necessidade.

`ClassBase` adiciona enumeração de membros, macros e construção genérica de
objetos. Seu clone de dados complexos preserva deliberadamente os objetos
que não cumprem seu protocolo de clonagem. Isso não garante posse independente
de recursos arbitrários. Cópias explícitas dos contratos de valores hbBridge
são mais adequadas que clonar clientes, datasets, sockets, conexões ou objetos
de interface.

`ArrayTools:Clone()` copia subarrays recursivamente, mas preserva referências
a JSON/objetos. `MergeUnique()` repete buscas lineares por `Contains()`,
podendo produzir custo quadrático de comparações conforme o resultado cresce.
`MergeDeep()` chama `Merge()` para subarrays nas mesmas posições, e não
`MergeDeep()` recursivamente; seu comportamento não deve ser apresentado como
merge posicional recursivo. Considerar apenas necessidades pequenas e
demonstradas de arrays nativos, preservando JSON/hashes para registros,
metadados e verificações de presença por chave quando adequados.

## Proveniência e próximo passo

Vários cabeçalhos de referência declaram domínio público e identificam as
origens DNA-Tech ou `naldodj-hb-flatten-json`. O repositório FWWebEx também
contém sua licença MIT. Preservar os avisos aplicáveis e a proveniência caso
código seja copiado futuramente; nenhum fonte foi copiado nesta revisão.

O próximo candidato de implementação é o clone JSON restrito com as
regressões indicadas. Fases de tempo seguem apenas para uma necessidade
concreta de diagnóstico; merge/flatten e operações genéricas de arrays
permanecem adiados. Prosseguir com a apresentação ativa pelo
[WIP](../WIP.pt-BR.md).
