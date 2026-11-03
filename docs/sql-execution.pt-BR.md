# Execução SQL e tabelas temporárias do chamador

[English](sql-execution.md) · [Consultas SQL](milestone3-sql.pt-BR.md)

`RPCRDD.Execute` envia SQL pelo perfil SQLite ou MSSQL configurado. O chamador
é responsável pelo SQL e pelas permissões no banco. Pode ser usado via TCP,
HTTP ou registro nativo, inclusive por `HBBridgeDispatch()` em um addon de
confiança. É separado do contrato de resultado tabular de `RPCRDD.Query`.

```json
{"service":"RPCRDD.Execute","params":{"requestVersion":1,"alias":"MSSQL/pData","sql":"INSERT INTO [dbo].[##example] (TESTID, TESTTEXT) SELECT 1, 'example'"}}
```

No Protheus, `HBBridge.SQL.HBBridgeSQLExecutor():Execute(oClient, cProfile,
cSQL)` aceita um cliente TCP ou HTTP existente e retorna um JSONObject; cliente
e resposta pertencem ao chamador. O método não repete a operação.

A resposta contém `success`, `resultVersion: 1`, `outcome`, `affectedRows` e
`connectionReleased` quando houve tentativa de conexão:

| Resultado | Significado |
| --- | --- |
| `notStarted` | Validação, perfil ou conexão falharam antes do envio do SQL. |
| `completed` | O driver informou execução bem-sucedida. Confira `connectionReleased` separadamente. |
| `unknown` | O driver não confirmou a operação enviada. Ela pode ter produzido efeito. |

`affectedRows` é `null` quando indisponível; o RDDSQL SQLite atual informa linhas
do resultado, não linhas afetadas, e seu número é descartado. No MSSQL é usado o
contador ODBC quando disponível. Perda da resposta ou timeout do cliente também
deixam o resultado incerto: não repita automaticamente. O helper TLPP marca como
`unknown` erros de transporte que não informam o resultado da operação.

Esta versão envia uma string SQL sem parâmetros tipados; ainda não oferece
bindings, chave de idempotência, transação distribuída, controle de transação
entre chamadas ou dataset de retorno. Não concatene valores não confiáveis.
Conta do banco, driver e SQL determinam a transação; sucesso não garante
atomicidade geral para lotes ou transações explícitas. Não presuma rollback em
caso de falha. Use credenciais com permissões mínimas e restrinja o acesso ao
listener: o TCP atual não autentica clientes e o serviço aceita SQL sob a
conta configurada. O texto SQL não constitui uma fronteira de autorização.

## Destino do Protheus e exemplo de addon

1. O Protheus cria e mantém sua `FWTemporaryTable`, obtém `GetRealName()` e
   passa ao addon o perfil e o destino efetivos.
2. O [addon de exemplo](../addons/examples/hbbridgetemporaryinsertaddon.hb), de
   confiança, protege o identificador MSSQL e executa seu `INSERT INTO ...
   SELECT` sintético pelo dispatcher. Ele espera `TESTID` e `TESTTEXT`.
3. O Protheus lê a tabela pela própria conexão DBAccess e a exclui após o uso.
   O addon não cria nem possui a tabela.

O addon também aceita `columns` e `select` de chamador confiável. Os exemplos
de browse temporário SX5/SRA usam esse formato; o SQL não é interpretado nem
parametrizado. Veja os [exemplos de browse](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.pt-BR.md#browse-sobre-temporária-do-chamador).

Compile o HRB com `./scripts/build-hbbridge-temporary-addon.ps1`, instale-o no
addon root configurado e execute o diagnóstico descrito em
[diagnósticos SQL](../src/tlpp/tests/protheus/hbbridge.query.test/README.pt-BR.md).
O exemplo não resolve empresa, filial, dicionário ou regra de negócio.

Em 2026-11-02, AppServer Windows isolado e hbBridge local no mesmo servidor e
banco MSSQL confirmaram duas linhas inseridas via TCP diretamente e via addon;
o DBAccess leu as linhas independentemente. A temporária tinha nome qualificado
e global, mantida aberta pelo proprietário durante cada chamada. Observou-se o
fechamento do alias após `Delete()`; a remoção física não foi verificada
separadamente. Outras instalações precisam validar visibilidade, permissões e
vida útil. Evitar transferência e consultas repetidas pode melhorar desempenho,
mas é necessário benchmark para quantificar a diferença.

Em 2026-11-02 às 22:09:42, uma execução manual separada de
`U_HBBridgeTemporaryExecuteCLI` no AppServer de desenvolvimento informou
`MSSQL/pData`, mesmo servidor/banco, `completed`, duas linhas afetadas e duas
linhas observadas independentemente. O alias próprio foi fechado. O relato
valida o caminho direto; a remoção física da temporária não foi verificada
independentemente.

Em 2026-11-03, um log separado de execução manual no AppServer CLI informou
`ADDON.Execute` com o mesmo perfil e servidor/banco, `completed`, duas linhas
afetadas, duas observadas e fechamento do alias próprio. O log informa o fim
da aplicação às 06:50:45; não fornece hashes dos fontes nem confirmação
independente da remoção física da temporária.

## Teste de view MSSQL

Execute `./scripts/test-hbbridge-mssql-view.ps1 -Config '<ini-privado>' -Profile
'<alias>'` para criar uma view de nome exclusivo em `dbo` com `RPCRDD.Execute`,
ler linhas sintéticas com `RPCRDD.Query` e `RPCRDD.QueryTyped` (inclusive um
parâmetro inteiro) e removê-la com `RPCRDD.Execute`. O teste verifica a ausência
após a remoção. São necessárias permissões CREATE VIEW e no esquema; a view é um
objeto real no banco até ser removida, não uma tabela temporária SQL. Se criação
ou limpeza tiver resultado incerto, o teste informa o nome para inspeção. Uma
view cuja criação não foi confirmada não é removida automaticamente.

Em 2026-11-02, o teste passou no MSSQL local com o perfil `MSSQL/pData`:
criação, os dois contratos de consulta e remoção/ausência foram confirmados.
As chamadas usaram o registro nativo de serviços no mesmo processo; este teste
específico não exercitou transporte de rede ou interface do Protheus.
