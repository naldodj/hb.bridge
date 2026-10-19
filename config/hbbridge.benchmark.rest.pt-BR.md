# Configuração do benchmark no REST 2.0 do Protheus

[English](hbbridge.benchmark.rest.md) · [Fragmento INI](hbbridge.benchmark.rest.ini) · [Benchmark](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md)

Reutilizar o serviço **REST 2.0 do Protheus** existente na porta 4323, com
`[HTTPV11] Sockets=HTTPREST` e `[HTTPREST] Security=1`. Rotas WSRESTFul e
annotations TLPP utilizam a autenticação nativa de usuários do Protheus pelo
framework. A rota do benchmark é `POST /rest/hbbridge/benchmark/page`;
o corpo aceita somente `{rows,pageNumber,pageSize}` da massa fixa, sem SQL
nem credenciais.

O fragmento desabilita os listeners separados de `[HTTPSERVER]` e retira
HTTPREST_HBBRIDGE da lista de sockets ativos. `[HTTPURI] Instances=1,1`
mantém um worker REST para a comparação sequencial. Preservar TLS/certificados,
ambiente/RPO, licenciamento, DBAccess e o `PrepareIn` de empresa/filial que
pertencem ao deployment. Manter HTTPJOB na lista de jobs existente. Trata-se
de fragmento para mesclagem, não de outro INI completo; nenhum listener ou
provedor privado de credenciais é adicionado.

`[hbBridge] BenchmarkProtheusURL` informa a URL base do serviço existente,
incluindo `/rest`; protocolo e porta devem corresponder à instalação.
`BenchmarkProtheusCredentialSection` seleciona uma seção já existente no
servidor, neste exemplo `FWWEBEX_PROTHEUS`, contendo `UserName` e `Password`.
O cliente nativo do benchmark monta HTTP Basic com esses valores no AppServer;
ler essa seção não exige classes FWWebEx. Senha, autorização e endpoint não
são informados pelo formulário do navegador nem retornados no relatório.
Não há `BenchmarkProtheusToken` separado; a autenticação HTTP do próprio
hbBridge continua independente.

O handler verifica habilitação de HTTPV11, segurança de HTTPREST, porta do
listener atual e ambiente de HTTPJOB. Inconsistências retornam 503. Essa
proteção verifica o deployment, não a identidade: REST 2.0 valida o usuário
real do Protheus antes de executar o endpoint. O handler também rejeita
cabeçalhos Basic malformados, sem comparar senhas com a configuração local.
A autenticação isolada de `[HTTPSERVER]` tlppCore não fornece autenticação
de usuários do Protheus.

Parâmetros inválidos de requisições autenticadas retornam 400; páginas válidas
retornam 200; falhas de consulta/limpeza retornam envelopes fixos seguros em
inglês com status 500. Compilar todos os fontes TLPP e validar no listener
reutilizado os casos sem credenciais, credenciais incorretas, credenciais
válidas, parâmetros inválidos e recuperação. A autenticação anterior ao
handler e essa rota REST ainda exigem aceite próprio pela rede; verificações
puras do adaptador não comprovam esse aceite.

Consultar a distinção oficial entre
[REST 2.0 e REST tlppCore](https://tdn.totvs.com/display/framework/Entendendo%2Bas%2Bnovidades%2Bdo%2BREST)
e o exemplo documentado de
[cliente FWRest com Basic](https://tdn.totvs.com/display/framework/Exemplo%2Bde%2Bconsumo%2Bcom%2BHTTP%2BBasic).
