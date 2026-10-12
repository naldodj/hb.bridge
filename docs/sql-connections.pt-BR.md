# Reutilização de conexões SQL: análise futura

[English](sql-connections.md) · [Contrato SQL](milestone3-sql.pt-BR.md) · [Roadmap](../TODO.pt-BR.md)

Observação registrada em 2026-10-12 a pedido do responsável. É um item para
análise futura, sem pooling implementado, padrão aprovado ou novas chaves INI.
O pacote WIP mantém suas tarefas e critérios de conclusão atuais.

## Comportamento atual

`SQLQueryLocked()` conecta a cada chamada, abre/lê/fecha sua área de consulta,
executa contagem separada na mesma conexão quando há páginas, desconecta e
restaura a área/conexão padrão do chamador. Um mutex SQL protege todo o ciclo.
Reutilizar a conexão não elimina query/contagem de páginas nem torna as
consultas paralelas sob esse mutex.

O SDDODBC inspecionado chama `SQLDriverConnect()` e `SQLDisconnect()` sem
habilitar pooling explicitamente. Conectar/desconectar logicamente não prova
uma nova conexão física: com pooling ODBC ativo, desconectar pode devolver a
conexão para reutilização. Verificar o comportamento real do gerenciador antes
de atribuir latência ao login. Veja
[pooling ODBC Microsoft](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).

O SDDODBC também aloca/libera handles de ambiente e conexão por chamada.
Conferir modo de pooling, duração do ambiente compartilhado e reuso físico.
Seu wrapper de desconexão ignora retornos ODBC nativos; sucesso de
`RDDI_DISCONNECT` sozinho não comprova liberação completa.

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
