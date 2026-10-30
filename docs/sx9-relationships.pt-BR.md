# Metadados de relacionamento SX9 para exemplos de JOIN

[English](sx9-relationships.md) · [Metadados do dicionário](sx3-metadata.pt-BR.md) · [WIP](../WIP.pt-BR.md)

A SX9 pode orientar os exemplos de JOIN no lado Protheus. É um dicionário de
relacionamentos, não uma chave estrangeira imposta pelo hbBridge nem uma
consulta SQL completa. Protheus continua resolvendo tabelas físicas, empresa/
filial, compartilhamento, predicados, parâmetros e metadados de apresentação.
O servidor recebe SQL e bindings explícitos.

## Observação local somente leitura em 2026-10-29

Foram consultados apenas catálogo e dicionários pelo perfil MSSQL local
existente. Não foram lidos valores de funcionários, dependentes ou centros de
custo nem alteradas tabelas, configurações ou credenciais.

Os pares solicitados foram encontrados em `dbo.SX9990`; `dbo.SX9` também
existe, mas não retornou esses pares. É uma observação local, não uma regra
de nomenclatura. O acesso ao dicionário em produção deve usar o contexto
Protheus preparado.

| Domínio | X9_IDENT | Contradomínio | Expressão do domínio | Expressão do contradomínio | Cardinalidade declarada |
| --- | --- | --- | --- | --- | --- |
| SRA | 106 | SRB | RA_MAT | RB_MAT | 1:N |
| CTT | 293 | SRA | CTT_CUSTO | RA_CC | 1:N |

Os dois registros contêm `X9_ENABLE=S`, `X9_USEFIL=S`, `X9_CONDSQL` vazio,
`X9_VINFIL=2` e `X9_CHVFOR=2`. Preservar esses últimos códigos como metadados
informados; esta revisão não lhes atribui significados novos. A cardinalidade
é declarada pelo dicionário, não uma medição de unicidade dos dados de negócio.

Partindo da SRA, a primeira relação é de saída e a relação com CTT é de
entrada: um centro de custo pode corresponder a vários funcionários, logo
o percurso SRA para CTT inverte o 1:N armazenado para N:1. Um leitor que
filtra somente `X9_DOM='SRA'` não encontra esse relacionamento.

As definições correspondentes em `SX2990` informam `SRA990`, `SRB990` e
`CTT990`, com `X2_MODO/X2_MODOUN/X2_MODOEMP=E/E/E`, tamanho de filial 2 e
tamanhos de unidade/empresa 0. Esses valores descrevem somente o dicionário
inspecionado. Resolver cada alias pelo Protheus na execução, sem fixar o
sufixo, igualar campos de filial indiscriminadamente ou deduzir o
compartilhamento pelos registros retornados.

A [explicação oficial TOTVS de relacionamento/compartilhamento](https://tdn-homolog.totvs.com/pages/releaseview.action?pageId=844959467)
identifica os campos de domínio/contradomínio e cardinalidade e descreve os
níveis empresa, unidade de negócio e filial. Um
[exemplo oficial de relacionamento SX9](https://tdn-homolog.totvs.com/display/public/PROT/DT%2BGCPA600%2BRelacionamento%2BSX9)
também registra expressões, `X9_IDENT`, ativação e uso de filial.

## Reaproveitamento do exemplo SX9Tools

O `dna.tech.sx9.tools.tlpp` fornecido é uma referência útil de leitura:
posiciona pelo domínio da SX9 e lê as expressões originais. As funcionalidades
de exclusão, atualização e execução de blocos ficam fora dessa necessidade
de apresentação somente leitura e não devem ser importadas para hbBridge.

Adaptações necessárias para um snapshot de relacionamentos:

- Incluir relações de saída e entrada, preservando a direção original e
  registrando separadamente a direção do percurso.
- Preservar `X9_IDENT` da SX9. O leitor fornecido atualmente atribui
  `cX9_EXPCDOM` à propriedade `X9_IDENT`; isso não é a identificação da relação.
- Registrar cardinalidade, estado ativo/excluído, flags de filial e condições,
  além das duas tabelas e expressões.
- Preservar área do chamador e índice/posição da SX9. Usar índices nativos
  verificados quando apropriado, sem presumir sua ordem física.
- Preferir snapshot em `JSONObject`, com identidade pela tupla domínio/
  identificador/contradomínio. Não compilar texto do dicionário em macros
  executáveis apenas para inspecionar ou descrever a relação.

Um helper proposto `HBBridge.Protheus.HBBridgeSX9Metadata` atenderia a esse
snapshot. Esta análise não o implementa. Ele deve permanecer independente
da posse de conexões SQL e do registro genérico de serviços Harbour.

## Da relação candidata ao SQL explícito

Para os dois pares simples observados, a igualdade dos campos é um ponto
de partida coerente: `SRA.RA_MAT=SRB.RB_MAT` e
`SRA.RA_CC=CTT.CTT_CUSTO`. O exemplo Protheus ainda resolve os predicados de
filial de cada alias, aplica exclusão lógica e escolhe INNER ou LEFT JOIN.
A SX9 isoladamente não escolhe o tipo de JOIN nem garante registro relacionado.

O texto da expressão nem sempre é uma lista de campos. Chaves compostas,
funções AdvPL, literais e condições contextuais exigem tratamento explícito.
Não dividir expressões arbitrárias em `+` para convertê-las silenciosamente
em igualdade ou concatenação SQL. Começar pelos pares de campos simples
validados; preservar expressões não suportadas para resolução pelo chamador.
Aplicar o mesmo cuidado a `X9_CONDSQL`, sem executar fragmentos não analisados.

O `U_HBBridgeBrowseDataTestSRAWithCast` existente ilustra um ajuste relevante
para o próximo exemplo: declara LEFT JOIN, mas testa `CTT.D_E_L_E_T_=' '`
no WHERE. Isso rejeita registros sem correspondência e se comporta como
inner join para eles. Colocar a exclusão lógica da direita no ON quando a
intenção for LEFT JOIN. Resolver compartilhamento CTT pelo Protheus em vez
do CASE atual sobre cada `CTT_FILIAL` retornado. Nenhum fonte foi alterado
nesta análise.

Em SRA/SRB, as linhas podem se multiplicar conforme o relacionamento.
Usar aliases projetados únicos e ordem determinística com a identidade do
lado relacionado; contar linhas resultantes, salvo agregado explícito por
funcionário. Preservar NULL do LEFT JOIN no dataset e escolher qualquer
substituição para apresentação nativa explicitamente no Protheus. Continuar
obtendo tipo, tamanho e decimais na SX3 de cada campo de origem projetado.

A próxima implementação continua delimitada aos exemplos de campos
selecionados/JOIN do WIP, sem parser SQL automático nem regras ERP no servidor.
