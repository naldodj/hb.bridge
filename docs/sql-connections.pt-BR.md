# Reutilização de conexões SQL

[English](sql-connections.md) · [Contrato SQL](milestone3-sql.pt-BR.md) · [Roadmap](../TODO.pt-BR.md)

Observação registrada em 2026-10-12; repriorizada na investigação de carga
M07 em 2026-10-15. O reuso deve preservar o executor genérico, o isolamento
dos perfis e o estado do chamador. O esboço de pool fornecido serve como
referência de desenho; sua implementação não é adotada literalmente.

## Comportamento atual

`SQLQueryLocked()` conecta a cada chamada, abre/lê/fecha sua área de consulta,
executa contagem separada na mesma conexão quando há páginas, desconecta e
restaura a área/conexão padrão do chamador. Um mutex SQL protege todo o ciclo.
Reutilizar a conexão não elimina query/contagem de páginas nem torna as
consultas paralelas sob esse mutex.

O SDDODBC original chama `SQLDriverConnect()` e `SQLDisconnect()` sem
habilitar pooling explicitamente. Conectar/desconectar logicamente não prova
uma nova conexão física: com pooling ODBC ativo, desconectar pode devolver a
conexão para reutilização. Verificar o comportamento real do gerenciador antes
de atribuir latência ao login. Veja
[pooling ODBC Microsoft](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).

O SDDODBC também aloca/libera handles de ambiente e conexão por chamada.
Conferir modo de pooling, duração do ambiente compartilhado e reuso físico.
O wrapper original/padrão `off` ignora retornos ODBC nativos; sucesso de
`RDDI_DISCONNECT` sozinho não comprova liberação completa. O caminho opt-in
verifica rollback, desconexão e liberação de handles, conforme aceite abaixo.

## Alternativas a medir

| Alternativa | Questão a resolver |
| --- | --- |
| Ciclo atual | Quanto custa conexão/autenticação versus query/contagem/leitura/codificação/transporte? |
| Pooling do gerenciador ODBC | Os builds Windows/Linux suportados reutilizam conexões MSSQL físicas mantendo o ciclo lógico? |
| Uma conexão reutilizável por perfil | Reuso sequencial exclusivo traz economia relevante sob o mutex atual? |
| Pool limitado gerenciado pelo host | Qual concorrência medida justifica mais conexões, e quais mudanças de sincronização RDDSQL são seguras? |

Medir consultas curtas repetidas e páginas pequenas, execuções frias/quentes,
tempos e dispersão, sessões/memória/handles, falhas e reconexões. Identificar
banco, driver, autenticação/TLS e carga. Conferir reuso físico separadamente
da consulta cronometrada. Medições anteriores de chamadas completas não
isolam custo de conexão nem indicam percentual esperado de ganho.

## Questões de propriedade e homologação

- Emprestar cada conexão exclusivamente a uma chamada. Separar perfis,
  identidades autenticadas e opções efetivas; invalidar reuso após mudanças
  relevantes de configuração/credenciais. Protheus continua resolvendo seu
  contexto; pooling não deduz regras de empresa/filial/tenant.
- Fechar cursores/statements, concluir ou desfazer transações e restaurar
  estado de sessão/RDD antes de devolver a conexão. Conexão aberta não é
  automaticamente transação aberta; transações, objetos temporários e opções
  `SET` retidos podem afetar o próximo chamador. Não pressupor reset automático
  universal. [Estado de sessão ODBC](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).
- Homologar conexões inválidas, reinício do banco, expiração ociosa, vida
  máxima, alocação/espera limitadas e liberação no shutdown. Reconectar é
  diferente de repetir: não reenviar automaticamente comando de resultado
  desconhecido, especialmente operações com efeitos.
- Verificar afinidade de thread e tabela global/conexão ativa por thread do
  RDDSQL. Workers TCP atuais encerram após a chamada; `THREAD STATIC` sozinho
  não é propriedade de pool persistente. Manter o mutex até homologar um
  desenho de sincronização que permita maior concorrência.
- Avaliar SQLite separadamente. Arquivo tem custos distintos; reter uma
  conexão `:memory:` muda duração/isolamento do banco. Reuso não cria snapshot
  entre query/contagem nem garante a mesma conexão em fluxos de tabela
  temporária/cursor; esses exigem contrato explícito de sessão emprestada.

A duração da conexão SQL é independente da conexão TCP/HTTP Protheus–hbBridge.
Pode-se avaliar reuso do banco sem adotar transporte RPC persistente. Escolher
implementação após medir e homologar isolamento, recuperação e recursos nas
plataformas suportadas.

## Homologação de chamadores concorrentes

M07 passou em 458 checks nativos (8 workers/192 chamadas) e 417 checks
AppServer CLI (4 jobs/112 chamadas) em 2026-10-14. Perfis, schemas, valores e
limpeza própria permaneceram isolados sob o mutex do ciclo atual. Homologa
chamadores concorrentes, sem remover sincronização nem provar liberação
física de conexões. Não define estratégia de pooling.
[Escopo e evidências](acceptance.pt-BR.md#sql-concurrency-and-release-on-2026-10-14).
M08 ainda fornece medições de tempo/memória necessárias à análise de reuso.

## Pressão sobre portas observada em 2026-10-15

O arquivo mais recente contém erro ODBC **10048/08001** e timeout de login
do DBAccess, seguido da proposta `HBBridgeSQLPool`; não é um relatório OK.
DBAccess é outro processo. Uma captura local encontrou 15264 conexões em
`TIME_WAIT`, e a faixa IPv4 dinâmica é 49152–65535. As contagens variam e
não medem vazamento de handles.

O log System do Windows também contém **Tcpip 4227** às **07:35:03 e
08:41:55 São Paulo**: falha de conexão de saída porque o endpoint local
selecionado havia conectado recentemente ao mesmo destino. Isso estabelece
um sintoma de pressão sobre reuso de portas no host durante a investigação;
a atribuição por processo e sua contribuição para cada falha HTTP ainda
precisam ser medidas. A Microsoft distingue essa evidência da quantidade
isolada de `TIME_WAIT` no
[diagnóstico de esgotamento de portas](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/tcp-ip-port-exhaustion-troubleshooting).

Aumentar backlog HTTP ou prazos das chamadas não fez passar o caso de 140
workers. Nenhuma configuração TCP do registro ou faixa de portas do Windows
foi alterada. Reuso SQL reduz criação de conexões com o banco; as conexões
HTTP/TCP Protheus–hbBridge têm outro ciclo e também precisam de medição.
[Evidências das rodadas](acceptance.pt-BR.md#sql-concurrency-follow-up-on-2026-10-15).

## Adaptação do esboço fornecido

| Comportamento do esboço | Adaptação necessária ao hbBridge |
| --- | --- |
| Remover o mutex do ciclo SQL | Mantê-lo; o SDDODBC fixado não declara `MT_AWARE`, e o RDDSQL também serializa operações do driver. |
| Repetir `Acquire()` indefinidamente e conectar/pingar sob o lock do pool | Manter timeouts nativos finitos e falhas visíveis; não adicionar repetição sem prazo nem reenviar comandos. |
| Devolver handle ausente em `inUse` | Exigir propriedade exata; devolução duplicada ou alheia não pode disponibilizar o mesmo handle duas vezes. |
| Destruir handles emprestados ou ignorar erro ao fechar cursor | Aguardar trabalho ativo, verificar limpeza e nunca emprestar conexão com reader pendente. |
| Restaurar somente conexão padrão anterior positiva | Preservar também zero; `RDDI_CONNECTION` nativo ignora atribuição de zero. Reter handles RDDSQL exige outro desenho de propriedade. |
| Usar `SELECT 1` como teste de sessão limpa | Verificar isolamento de transações, objetos temporários, banco e opções da sessão; disponibilidade não limpa estado. |
| Trocar construção MSSQL por concatenação ODBC genérica | Preservar validação de autenticação/TLS, exclusividade entre campos/string e comportamento de tipos/codificação/paginação. |
| Anunciar Oracle/PostgreSQL/MySQL imediatamente | Homologar cada driver/dialeto; preservar a duração dos bancos SQLite. |

A adaptação implementada usa **pooling físico no gerenciador ODBC nativo**,
preservando conectar/desconectar lógico por chamada no RDDSQL e o mutex SQL.
`HBBridgeSQLPool` controla leases em hashes com ID único, perfil e thread
proprietária. Rejeita devoluções obsoletas/duplicadas/alheias e recusa destruir
leases ativos. Configurar não recria o singleton. Evita cache compartilhado
de handles RDDSQL e mantém a restauração do
chamador cuja conexão anterior era zero. Pool gerenciado pela aplicação
permanece outra opção se o reuso nativo não atender às medições necessárias.

A política de pooling pertence ao processo, é explícita e fica fixa no
primeiro uso ODBC. `off` preserva o padrão atual; `driver` solicita pool por
driver, sem significar o recurso distinto `SQL_CP_DRIVER_AWARE`. Combinar
opções de conexão exatamente não comprova sessão limpa. O caminho Windows
ODBC 3.8 passou em 61 checks por modo: após dois empréstimos de aquecimento
registrados, 13 leases medidos reutilizaram uma conexão TCP física em
`driver`, contra 13 em `off`. SET/contexto, temporárias, transação e banco
selecionado foram limpos antes do próximo chamador na conexão reutilizada;
passaram timeouts, estado do chamador e liberação da âncora. Não mede latência.
Linux mantém `off` até homologar seu gerenciador/isolamento. Veja as
[evidências nativas](acceptance.pt-BR.md#odbc-physical-reuse-on-2026-10-15) e
[configuração](configuration.pt-BR.md) para opções e evidências atuais.

O pool nativo mantém uma referência de ambiente compatível entre conexões
lógicas, com DBC âncora sem conexão, credenciais ou socket de rede. A versão
anterior solicitava pooling mas liberava o ambiente a cada chamada e mediu
13 conexões físicas para 13 chamadas. Preservar o ambiente compartilhado
permitiu reuso real; a âncora própria é liberada ao sair do processo ou na
limpeza explícita do pool nativo, após fechar os leases lógicos. O início
frio usou duas conexões físicas; o reuso estabilizado fica separado, sem
afirmar uma única conexão física em todo o processo.

O resumo manual posterior do Protheus informa 500 workers/58449 checks sem
falhas, com pausas explícitas de lançamento. Não fornece modo do pool ou hash
do binário, portanto fica separado do aceite de reuso físico. Atividade de
banco do StartJob/framework também exige medição separada das conexões SQL
e RPC do hbBridge. [Escopo manual](acceptance.pt-BR.md#manual-protheus-concurrency-on-2026-10-15).
