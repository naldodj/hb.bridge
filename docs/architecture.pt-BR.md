# Execução genérica e responsabilidades da aplicação

[English](architecture.md)

hbBridge estende o Protheus com execução Harbour/C/Zig, acesso a dados,
arquivos, addons e processamento nativo. **As regras Protheus pertencem ao
Protheus.** A ponte não deduz contexto ERP de banco, perfil, sessão RPC ou
prefixo de tabela. Clientes Harbour também usam os mesmos serviços.

| Protheus / aplicação chamadora | Executor hbBridge |
| --- | --- |
| Resolver tenant ID, empresa e filial. | Receber contexto explícito como dados opacos da aplicação. |
| Resolver `xFilial`, compartilhamento e nomes físicos, como resultados de `RetSQLName`. | Executar a consulta preparada no perfil selecionado. |
| Aplicar dicionário, validações, permissões, exclusão lógica, transações e locks. | Aplicar permissões genéricas de serviço/conexão/recurso e devolver resultados. |
| Escolher alias de conexão e dialeto SQL. | Localizar o alias, conectar e executar; paginação genérica pode envolver o SQL recebido. |
| Fornecer entradas de negócio ao addon. | Executar o addon com parâmetros, sem inferir empresa/filial ERP. |

Futuras autorizações por tenant, propriedade de sessão e auditoria podem
validar contexto explícito e autenticado. Não devem inventar filtros
`xFilial`, deduzir compartilhamento nem mapear dicionários Protheus.
Isolamento é segurança do executor; o significado ERP do tenant é resolvido
na aplicação. O modelo futuro de autorização/sessão por tenant ainda não
está implementado.

Para SQL, o chamador Protheus prepara nomes físicos e filtros de negócio antes
de chamar `RPCRDD.Query`. O contrato atual recebe `alias`, `sql` e `page`
opcional; bind de valores e envelope versionado de contexto estão no roadmap.
Prepared statements devem distinguir valores e identificadores: nome de
tabela não é um placeholder de valor. Não interpole valores não confiáveis
apenas porque a ponte aceita SQL.

Um addon pode conter processamento específico, mas recebe os dados de negócio
explicitamente por parâmetros. O núcleo genérico não depende de bancos por
empresa nem dicionários Protheus. `company="T1"` no Echo é dado de teste
devolvido sem interpretação. Consulta ODBC direta não executa automaticamente
fluxos DBAccess ou regras de negócio.

## Múltiplos perfis de banco

Perfis são um mapa por chave, sem banco único fixo. Nomes são opacos e
sensíveis a maiúsculas, incluindo `sqlite_demo`, `mssql/pData` e `oracle/alias`.
Barra no alias não é caminho nem regra de roteamento; o campo separado `driver`
seleciona um conector suportado. No INI, `mssql/pData` usa `[SQL/mssql/pData]`.

A biblioteca TLPP **não tem padrão `sqlite_demo`**. `SQLProfile` no INI do
AppServer é opcional, da instalação, e pode estar vazio. O teste prioriza
argumento explícito, depois esse padrão opcional; sem ambos, retorna
`PROFILE_REQUIRED` antes da rede. Cada `opensql(alias, sql)` ou
`openpage(alias, ...)` escolhe seu perfil; datasets no mesmo cliente podem
usar perfis diferentes. Credenciais e definições de perfil ficam no servidor.

```advpl
oSQLite:opensql("sqlite_demo", cSQLiteSql)
oMssql:opensql("mssql/pData", cResolvedProtheusSql)
```

[databases.ini](../config/examples/databases.ini) exemplifica múltiplos perfis.
O schema estrito implementa somente drivers `sqlite` e `mssql`. `oracle/alias`
é um nome válido, mas não implementa driver Oracle: são necessários conector,
testes de dialeto/tipos e homologação real. Exemplos SQLite selecionam seu
demo explicitamente. Execução genérica não promete acelerar SQL sem medir
planos/índices do banco, materialização e transferência.
