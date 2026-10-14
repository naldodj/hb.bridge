# Extensões opcionais de runtime e SQL

[English](extensions-review.md) · [Roadmap](../TODO.pt-BR.md) · [Pacote ativo](../WIP.pt-BR.md)

Análise de 2026-10-12 a partir de `hbBridge_Braimstorming.txt`
e das fontes primárias abaixo. São decisões para extensões futuras, sem novos
serviços ou dependências entregues. A proposta Python/parser SQL também foi
analisada em 2026-10-14. O pacote 001 permanece aberto; a prioridade segue o WIP.

| Referência | Avaliação | Uso proposto |
| --- | --- | --- |
| xHarbour-SQLRDD | Referência útil de RDD; adoção exige necessidade concreta e revisão de fontes/licenças. | Comparar catálogo/índices/tipos/seek com SQLMIX, mantendo metadados explícitos do chamador. |
| Duktape | Motor C opcional viável. Incorporá-lo não homologa isolamento nem prazos. | Módulos JavaScript registrados, entradas explícitas e bindings restritos. |
| CCHarbour | Candidato a addon opcional de agentes, sem substituir o núcleo de serviços. | Ferramentas explícitas, jobs assíncronos e provedor de modelo configurado. |
| sqlparse / harbour_python | Provedor opcional viável; o binding de exemplo exige ajustes de ciclo de vida, compilação e propriedade. | Análise/reescrita SQL com metadados explícitos do chamador; adoção permanece adiada. |

## xHarbour-SQLRDD

O [topconn.prg](https://github.com/xHarbour-org/xharbour/blob/main/xHarbourBuilder/xHarbour-SQLRDD/samples/topconn.prg)
informado é um exemplo de compatibilidade SQLRDD com catálogo/índices e
navegação xBase. Não demonstra conexão hbBridge ao protocolo de rede do
DBAccess. Seu cabeçalho também reserva direitos; conferir os termos de cada
fonte antes de importar código da [árvore SQLRDD](https://github.com/xHarbour-org/xharbour/tree/main/xHarbourBuilder/xHarbour-SQLRDD).

Manter SQLMIX/SDDODBC/SDDSQLITE3 como rota implementada. Um conector opcional
deve justificar uma capacidade ausente e passar por testes de tipos/nulos/
codificação, seek, bloqueios, liberação e Windows/Linux. Protheus continua
resolvendo SX3/TOP_FIELD, tabelas físicas, empresa/filial/tenant e exclusão.
Compatibilidade de API RDD e descoberta de catálogo não comprovam semântica
de negócio DBAccess. DBF nativo/NETIO permanece outra rota.

## Duktape

[Duktape](https://github.com/svaarala/duktape) é incorporável por fontes C,
usa licença MIT e implementa principalmente ES5/5.1, com recursos posteriores
parciais. Fixar uma distribuição publicada; master está recebendo mudanças
incompatíveis para 3.x. Node.js não é necessário para executar o motor
incorporado da distribuição.

O addon proposto recebe ID/versão de módulo configurado e parâmetros JSON/
nativos, com permissão no registro e retorno definido. Preferir módulos
implantados a fonte arbitrário recebido pela rede. Protheus mantém a regra e
fornece seu contexto; hbBridge executa o módulo informado genericamente.
Definir representação de decimais explicitamente: números JavaScript não
substituem o contrato numérico exato ainda pendente.

O [guia de sandboxing](https://duktape.org/guide.html#sandboxing) considera
bindings C confiáveis e descreve suporte incompleto em 2.x. Portanto, um heap
separado não basta para anunciar sandbox seguro. Nosso aceite deve verificar
orçamentos de alocação, verificações de tempo, cancelamento, restrição de
bindings de arquivo/rede/processo, reset de estado e liberação. Timeout do
script não interrompe sozinho um binding bloqueante; scripts não confiáveis
podem exigir processo worker separado. Nenhum motor/serviço foi adicionado.

## CCHarbour

[CCHarbour](https://github.com/FiveTechSoft/CCHarbour) descreve um assistente
Harbour incorporável com subagentes em background e executável console de
aproximadamente 2 MB. Esse tamanho é uma afirmação upstream sobre seu binário,
não sobre hbBridge, pesos de modelo ou memória total. O backend padrão é uma
API remota; [Ollama local é experimental](https://github.com/FiveTechSoft/CCHarbour/blob/master/README.md#running-locally-with-ollama-experimental)
e depende de compatibilidade de modelo/tool calls e hardware. A
[licença MIT](https://github.com/FiveTechSoft/CCHarbour/blob/master/LICENSE)
não define sozinha as licenças de todas as dependências transitivas.

Integração proposta: addon opcional com ferramentas autorizadas e contratos
job/status/cancel, entradas explícitas e segredos do provedor provisionados
separadamente. Estado pertence à requisição/job; recursos compartilhados são
sincronizados. SQL continua serializado pelo mutex; threads em background não
comprovam execução paralela no banco.

A configuração de modelo local deve controlar endpoints, ferramentas, logs e
eventual fallback remoto. Saída do modelo não autoriza executar SQL, escrever
dados ERP nem iniciar processos. Começar com ferramentas sintéticas somente
de leitura; contexto ERP e mutações continuam governados pelo chamador
Protheus. É um desenho de integração, sem agente instalado nem garantia de
privacidade, desempenho ou tamanho de binário.

## Parser SQL Python opcional: análise em 2026-10-14

[sqlparse 0.6.0](https://pypi.org/project/sqlparse/0.6.0/) exige Python 3.10
ou superior e usa licença BSD. É um parser de tokens/agrupamentos que não valida
SQL. Sua [API de navegação de identificadores](https://sqlparse.readthedocs.io/en/stable/analyzing.html)
reconhece aliases e curingas; associação ao catálogo, expansão ordenada de
`SELECT *` e precisão de expressões ainda exigiriam uma camada semântica própria.
Reconhecer um token não determina o campo de origem nem um CAST seguro.

[harbour_python](https://github.com/FiveTechSoft/harbour_python) foi analisado no
commit `70f828e412ec8b9b7076d83e1541975e46fb7d9d`. Seu
[exemplo de compilação](https://github.com/FiveTechSoft/harbour_python/blob/70f828e412ec8b9b7076d83e1541975e46fb7d9d/test64.hbp)
usa caminhos Windows/Python 3.11; não fornece build Linux. O
[binding C](https://github.com/FiveTechSoft/harbour_python/blob/70f828e412ec8b9b7076d83e1541975e46fb7d9d/python.c)
transfere ponteiros de objetos Python e não oferece conversão automática de
hashes nem gestão do ciclo de vida dos workers. Não foi identificado LICENSE
ou autorização de reutilização nos arquivos analisados; copiar esse binding
não pressupõe permissão. Um adaptador próprio pela API documentada do CPython
permanece alternativa.

O provedor proposto `ParseSQL` receberia JSON UTF-8 com SQL, dialeto,
mapeamentos explícitos de tabelas/aliases e metadados dos campos, retornando
SQL reescrito e diagnósticos. Protheus fornece definições SX3/TamSX3 e eventual
lista ordenada de colunas para expandir curingas; hbBridge não descobre contexto
ERP. Começar com projeções sem ambiguidades e manter CAST manual nas reescritas
não suportadas. Entrada/saída JSON evita uma camada geral de conversão de tipos
Harbour/Python, mas ainda exige erros tratados e Unicode com tamanho explícito.

Incorporar o interpretador exige inicialização com proprietário definido,
tratamento de GIL/estado de thread por worker e finalização após encerrar os
workers; `THREAD STATIC` não gerencia o interpretador. Consultar
[inicialização/threads CPython](https://docs.python.org/3.11/c-api/init.html) e
[incorporação/configuração de build](https://docs.python.org/3.11/extending/embedding.html).
Python deve permanecer opcional na inicialização: um vínculo obrigatório no
executável principal pode exigir sua DLL mesmo com o provedor desativado.
Avaliar carregamento adiado ou processo provedor separado, com aceites próprios
Windows/Linux e de desempenho. Esta análise não implementou dependência Python,
serviço parser nem reescrita.

## Ordem de entrega

Concluir dataset/tipos/codificação e os aceites de segurança relevantes do
pacote atual. Depois avaliar separadamente fontes SQLRDD, um pacote Duktape
restrito, um pacote opcional de jobs CCHarbour e o parser SQL adiado. Registrar fontes fixadas,
dependências, procedência/licenças, serviços expostos e testes atribuíveis
antes de anunciar capacidades. Esta análise não instala projetos nem altera
os critérios de conclusão do WIP.
