# Diagnósticos SQL

[English](README.md)

`U_HBBridgeTemporaryInsertTest()` cria sua própria `FWTemporaryTable`, obtém o
nome físico por `GetRealName()` e envia ao `RPCRDD.Query` um `INSERT INTO ...
SELECT` MSSQL com duas linhas constantes. Antes de gravar, confere a identidade
do servidor SQL e do banco nas conexões DBAccess e hbBridge. O perfil padrão vem
de `[hbBridge] SQLProfile` do AppServer, usando `FWGetTopInfo()` como fallback;
informe o perfil explicitamente se o alias no hbBridge for diferente. O endpoint
TCP e o perfil configurados precisam estar ativos.

O diagnóstico lê a tabela própria pelo DBAccess e informa separadamente a
resposta do serviço e as linhas observadas. Uma resposta de erro pode ocorrer
após uma gravação: `RPCRDD.Query` espera um resultado tabular e não possui um
contrato de DML. Timeout ou falha de conexão também deixam o resultado incerto;
não repita a gravação automaticamente. O teste não grava em tabelas do ERP e
exclui a temporária própria na limpeza. Visibilidade entre sessões SQL, sucesso
do insert e confirmação da transação são observações da instalação testada,
não premissas.

Execute `U_HBBridgeTemporaryInsertTest(perfil, .T.)` para `RPCRDD.Execute`, ou
`U_HBBridgeTemporaryInsertTest(perfil, .T., .T.)` para o addon de exemplo
instalado. As entradas CLI `U_HBBridgeTemporaryExecuteCLI` e
`U_HBBridgeTemporaryAddonCLI` usam o perfil configurado. Compile o HRB com
`scripts/build-hbbridge-temporary-addon.ps1` e coloque-o no addon root. Veja o
[contrato de execução](../../../../../docs/sql-execution.pt-BR.md).

Em 2026-11-02, um AppServer Windows isolado e um hbBridge local iniciado
separadamente usaram o perfil `MSSQL/pData`. Ambos apontaram para o mesmo SQL
Server e banco. `GetRealName()` retornou uma tabela temporária global
qualificada pelo esquema; o serviço retornou `QUERY_FAILED`, enquanto o DBAccess
leu independentemente as duas linhas esperadas. O alias próprio foi fechado após
`Delete()`. O resultado registra o efeito dessa execução, sem estabelecer um
contrato geral de transação DML ou comprovar a remoção de todo o armazenamento
temporário. Uma execução inicial parou antes de criar a tabela porque o perfil
inferido não estava disponível.
