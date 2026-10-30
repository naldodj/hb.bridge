# Execução genérica e responsabilidades da aplicação

[English](architecture.md)

O [índice da documentação](README.pt-BR.md) organiza os guias por tarefa.

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

## Núcleo compartilhado e adaptadores de transporte

```text
Protheus / AdvPL / TLPP    Clientes Harbour    HTTP / navegador
          |                     |                   |
      HBBRIDGE/1            NETIO nativo     HTTP / REST / admin web
          |                     |                   |
 Adaptador Protheus        Adaptador hbnetio   Adaptador hbhttpd
          |                     |                   |
          +----------------- hbBridge ---------------+
                              |
                registro comum de serviços/capacidades
                tipos / erros / permissões da chamada
                              |
          +-------------------+-------------------+
          |                   |                   |
    Core Harbour,       dados e arquivos      API C Harbour
    contribs/addons     SQL / VF IO nativo         |
                                              ABI C ↔ Zig
```

Cada adaptador traduz seu transporte para o núcleo comum. Módulos e consultas
não precisam implementar cada protocolo de cliente. Registro e configuração
do host são compartilhados; cada chamada mantém a propriedade de seu contexto,
áreas de trabalho, conexões e módulos. Veja o
[registro e ciclo de vida](milestone1.pt-BR.md), o
[adaptador HTTP](http.pt-BR.md) e a
[fronteira RPC/arquivos nativos](harbour-vfio-trpc.pt-BR.md).

A implantação de referência utiliza **um executável hbBridge**, atualmente
operado em console, com `hbnetio` vinculado estaticamente por `-lhbnetio`.
O host coordena inicialização, filtro, administração e encerramento por
`netio_Listen`, `netio_Accept`, `netio_RPCFilter` e `netio_Server`, mantendo
as threads para aguardar seu término. O wrapper upstream `netio_MTServer`
destaca suas threads. Veja as
[APIs hbnetio](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

Uma DLL poderá atender extensões com atualização independente quando uma ABI
estável e o ciclo de carregamento justificarem essa escolha. Um processo
separado poderá isolar alguma carga específica. Nenhuma dessas opções é
necessária para incorporar NETIO. Conectores de banco e drivers ODBC instalados
continuam como dependências dos perfis/builds escolhidos.

`HBBRIDGE/1` pertence ao endpoint Protheus; clientes Harbour usam o endpoint
NETIO nativo separado. Alterar a porta do cliente TLPP de 1512 para 2941 não
o torna cliente NETIO. Compartilhar porta exigiria multiplexação explícita e
homologação de interoperabilidade. Binds como `0.0.0.0` são endereços do
listener, não destinos de clientes; clientes locais usam `127.0.0.1`.
Padrões, administração separada e HTTP opcional estão em
[configuração](configuration.pt-BR.md).

## Operação em console e futuros serviços do sistema

A operação em console está implementada. Instalação como serviço Windows e
integração supervisionada no Linux continuam previstas; deverão reutilizar
o mesmo host e ciclo de recursos, sem criar uma segunda implementação do
produto. A [integração upstream hbnetio/hbwin](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/_winsvc.prg)
é a referência Windows. Linux exige inicialização supervisionada, sinais,
encerramento e recuperação.

Utilizar caminhos absolutos estáveis na instalação e coordenar rollback de
inicialização, interrupção de novas admissões e limpeza de trabalho em curso.
Futuros recursos de cursor/stream também exigirão proprietário e fechamento
explícitos. Os workers existentes ainda precisam que handlers/addons retornem;
o host em console não oferece cancelamento forçado de execução. A operação
como serviço não deverá depender de depuração interativa. Veja
[depuração](debugging.pt-BR.md) e [roadmap](../TODO.pt-BR.md).

## Múltiplos perfis de banco

Perfis são um mapa por chave, sem banco único fixo. Nomes são opacos e
sensíveis a maiúsculas, incluindo `sqlite_demo`, `MSSQL/pData` e `oracle/alias`.
Barra no alias não é caminho nem regra de roteamento; o campo separado `driver`
seleciona um conector suportado. No INI, `MSSQL/pData` usa `[SQL/MSSQL/pData]`.

A biblioteca TLPP **não tem padrão `sqlite_demo`**. `SQLProfile` no INI do
AppServer é opcional, da instalação, e pode estar vazio. O teste prioriza
argumento explícito, depois esse padrão opcional; sem ambos, retorna
`PROFILE_REQUIRED` antes da rede. Cada dataset seleciona seu perfil com `SetAliasProfile(alias)` antes de
`OpenSQL(sql[, page])` ou `OpenPage(sql, number, size, orderBy)`. Datasets no
mesmo cliente podem usar perfis diferentes. Credenciais e definições de perfil ficam no servidor.

```advpl
oSQLite:SetAliasProfile("sqlite_demo")
oSQLite:OpenSQL(cSQLiteSql)
oMssql:SetAliasProfile("MSSQL/pData")
oMssql:OpenSQL(cResolvedProtheusSql)
```

[databases.ini](../config/examples/databases.ini) exemplifica múltiplos perfis.
O schema estrito implementa somente drivers `sqlite` e `mssql`. `oracle/alias`
é um nome válido, mas não implementa driver Oracle: são necessários conector,
testes de dialeto/tipos e homologação real. Exemplos SQLite selecionam seu
demo explicitamente. Execução genérica não promete acelerar SQL sem medir
planos/índices do banco, materialização e transferência.

## Bases para extensões

O mapa abaixo registra caminhos pretendidos de extensão, sem afirmar que
todas as capacidades estejam entregues. O registro expõe os serviços
disponíveis; contribs opcionais exigem decisões explícitas de dependência,
build e homologação.

| Capacidade | Base e escopo |
| --- | --- |
| Rotinas xBase | Core/contribs Harbour e addons PRG/HB/HRB; o serviço existente está descrito no [Marco 1](milestone1.pt-BR.md). |
| Processamento de dados | SQLMIX/conectores para consultas/páginas SQL implementadas; DBF via NETIO permanece uma integração planejada separada. |
| Arquivos e conteúdo | VF IO/NETIO nativos, compressão e ZIP; fachada de arquivos TLPP e transferência lógica em blocos permanecem previstas. |
| Integração externa | `hbcurl`, `hbexpat` e outras contribs opcionais por serviços da aplicação; não constituem um serviço universal API/XML pré-instalado. |
| HTTP e operação web | Adaptador existente `hbhttpd`/`hbtcpio` e status autenticado; TLS direto utiliza `hbssl`/OpenSSL opcional e homologação própria. Alterações administrativas permanecem previstas. |
| Processamento nativo | API C Harbour e bibliotecas C/Zig; novas transformações especializadas precisam de implementação e medição. |
| Operações longas | Threads, recursos nativos de stream NETIO e futura camada de jobs com submissão, progresso, resultados e cancelamento cooperativo. |

Referências: [hbcurl](https://github.com/harbour/core/tree/master/contrib/hbcurl),
[hbexpat](https://github.com/harbour/core/tree/master/contrib/hbexpat),
[hbziparc](https://github.com/harbour/core/tree/master/contrib/hbziparc).
[Dependências](dependencies.pt-BR.md), [evolução](evolution.pt-BR.md) e
[TODO](../TODO.pt-BR.md) mantêm os limites de implementação e pré-requisitos.

## Estado da telemetria

O [módulo Syslog](../src/hb/telemetry/hbbridge.syslog.hb) está vinculado e pode
enviar UDP para `127.0.0.1:514`. O fluxo ativo do host/RPC não chama suas
funções de abertura/escrita/fechamento. Integração ao ciclo de vida e aceite
com coletor permanecem futuros; código vinculado não comprova telemetria ativa.
