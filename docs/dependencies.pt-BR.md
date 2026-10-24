# Dependências gerenciadas de compilação

[English](dependencies.md)

hbBridge resolve seu próprio ambiente de build. PowerShell 7 e Git são os
pré-requisitos de bootstrap; pacotes de runtime Windows/Linux e SDK TOTVS
licenciado continuam externos quando aplicáveis. Não há dependência padrão
do checkout `C:\GitHub\hb_compile` do desenvolvedor nem de Zig global.

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
./scripts/commit-check.ps1
```

## Manifesto e diretórios

[config/dependencies.json](../config/dependencies.json) fixa revisões Git de
hb_compile/Harbour, versão Zig, URLs/checksums oficiais e contribs necessários.
O bootstrap obtém essas revisões em diretórios próprios. Revisão/origem
incompatíveis provocam erro, sem sobrescrever trabalho. A preparação pode
modificar fontes gerenciados; edições locais são preservadas. Checkouts
existentes do desenvolvedor permanecem intactos.

| Local | Finalidade |
| --- | --- |
| `.deps/hb_compile/` | Checkout próprio do orquestrador de compilação. |
| `.deps/harbour/` | Fontes Harbour fixados e próprios do projeto. |
| `.deps/tools/zig/` | Zig fixado, arquivo e executável, com SHA256 verificado. |
| `.deps/hb_compile/out/zig/` | Ferramentas, includes e bibliotecas Harbour Windows. |
| `.deps/hb_compile/out/linux/` | Instalação Harbour nativa Linux. |
| `.deps/http/` | Preparo isolado hbhttpd/hbtcpio e registro de patch/build verificados. |
| `.deps/odbc/` | Preparo isolado SDDODBC e registro de patch/build verificados. |
| `.hbcommit/` | Fontes de manutenção; usam o mesmo `hbrun` compilado. |
| `out/` | Produto/addons gerados, reconstruídos por fontes/scripts mantidos. |
| `tmp/` | Trabalho/logs inteiramente descartáveis, nunca pré-requisitos. |
| `scripts/`, `tests/` | Automação, fixtures e probes reutilizáveis versionados. |
| `docs/validation/` | Resumos históricos sanitizados e comandos de reprodução. |

`.deps/`, resultados de build e identidade local são ignorados pelo Git.
Não se distribui outro runtime `bin/harbour`. Um build concluído grava
`hbbridge-toolchain.json` com hash do manifesto, plataforma e revisões.
A ferramenta completa e inalterada é reaproveitada; `-ForceBuild` recompila.
`-SkipHarbourBuild` só resolve fontes/Zig, sem completar o Harbour.
Atualizar versões fixadas exige manutenção explícita, novo build, regressões
e atualização dos registros de procedência/licença.

## Integração hb_compile

A próxima integração delega resolução seletiva de SDKs externos ao hb_compile,
consumindo ambiente gerado, artefatos de destino/runtime e cache por capacidade.
O resolvedor Windows fixado já suporta OpenSSL; Linux nativo depende de recurso
upstream ou rota WSL/Docker suportada e explícita. Isso permanece pendente;
o fluxo TLS com SDK informado abaixo continua aplicável. Veja a
[análise de dependências](evolution.pt-BR.md#um-único-resolvedor-de-dependências).

[hb_compile](https://github.com/DNATechByNaldoDJ/hb_compile) orquestra compilação
Harbour e preparação de compatibilidade. Windows usa seu runner Zig nativo,
com caminhos próprios de fonte/instalação e seleção de contribs: NETIO, ZIP,
SQLite, SQLRDD/SQLMIX e ODBC. Zig vem da distribuição oficial com checksum.
Bibliotecas GUI não relacionadas e repositórios privados HBDAP não são
dependências implícitas.

HTTP acrescenta **hbhttpd** e **hbtcpio** nativos. O bootstrap chama
[prepare-http.ps1](../scripts/prepare-http.ps1) para compilar essas contribs
de uma cópia isolada. O manifesto fixa o checksum de
[hbhttpd.patch](../config/patches/hbhttpd.patch): acesso ao corpo bruto,
workers configuráveis, prontidão/parada coordenada do listener e rejeição
de Transfer-Encoding não suportado e Content-Length duplicado/não decimal,
além da preservação dos corpos de erro estruturados dos handlers e
enquadramento/Content-Length HTTP por bytes e prazo de envio configurável com
blocos limitados e tratamento de envios parciais/não bloqueantes. Respostas
incompletas encerram antes de registrar acesso ou reutilizar keep-alive. O
checkout Harbour fixado permanece íntegro. `-hblib` é o modo de compilação
de biblioteca do hbmk2, não uma dependência contrib separada.
Os [atributos Git](../.gitattributes) impõem LF em `config/patches/*.patch`,
mantendo checksums do manifesto iguais em clones Windows/Linux.

O aceite MSSQL identificou uma falha de leitura variável do SDDODBC quando a
sondagem Unicode de tamanho com `SQLGetData` retorna `SQL_NO_TOTAL`. O patch
gerenciado [sddodbc.patch](../config/patches/sddodbc.patch) corrige esse caminho,
flags de campos binários e conversão de pares substitutos UTF-16 para codepages
UTF-8, preservando NUL embutido e vazio/nulo entre blocos. Sem teto de payload.
O mesmo patch gerenciado acrescenta timeouts nativos ODBC de login/consulta,
opcionais por perfil, validação C pela capacidade inteira nativa e leitura
exata dos atributos. Atributos explícitos que falham ou mudam são rejeitados;
login é verificado novamente após conectar e toda instrução, inclusive a
contagem separada da página, recebe seu timeout de consulta configurado.
A omissão mantém padrões do driver e zero explícito os desativa. Veja
[configuração e escopo dos timeouts](configuration.pt-BR.md#native-mssql-timeouts).
Isso altera a interface do conector em staging, sem editar o checkout upstream
fixado nem corrigir a perda fracionária de FLOAT bruto registrada em D03.
[prepare-odbc.ps1](../scripts/prepare-odbc.ps1)
verifica o checksum `harbour.odbcPatch` do manifesto e aplica o patch revisado
em `.deps/odbc/stage-<id>/sddodbc`, preservando o checkout de fontes fixado.
Compila somente SDDODBC e instala biblioteca/metadados na instalação Harbour
gerenciada selecionada. Windows usa bibliotecas ODBC nativas; Linux exige
headers e bibliotecas de desenvolvimento unixODBC.

O bootstrap prepara esse conector após Harbour, inclusive quando reaproveita
o toolchain base. O build do produto e os dois launchers de testes Harbour
também o preparam antes de vincular. `.deps/odbc/receipt.json` registra revisão
Harbour, SHA256 do patch e SHA256 da biblioteca instalada; artefatos iguais
e válidos são reaproveitados. `./scripts/prepare-odbc.ps1 -ForceBuild` recompila
somente esse conector em staging. O aceite permanece separado da compilação:
o patch e um build concluído não homologam todos os drivers ou Linux.

HTTP aberto não exige SDK OpenSSL. HTTPS direto é um build opcional com
`HB_HTTP_TLS=1`, **hbssl**, SDK/runtime OpenSSL da arquitetura e
`HB_WITH_OPENSSL` indicando seu diretório de include. A configuração TLS
exige a biblioteca vinculada, certificado e chave privada; somente dispor
dos fontes Harbour não basta. HTTPS e Linux precisam de aceite próprio.
Veja [configuração/rotas HTTP](http.pt-BR.md).
Deixe HB_HTTP_TLS ausente no build HTTP padrão; outros valores não vazios falham.

O runner PowerShell nativo do hb_compile fixado atende Windows. No Linux,
hbBridge chama sua preparação de compatibilidade e compila os mesmos fontes
fixados por GNU make/GCC, instalando no prefixo Linux próprio. Instale antes
PowerShell 7, Git, make, GCC/binutils e headers de desenvolvimento unixODBC.
O bootstrap informa pré-requisitos ausentes, sem alterar silenciosamente o
gerenciador de pacotes. A biblioteca Zig do produto usa Zig gerenciado e
hbmk2 usa o compilador da plataforma. Execução Linux exige homologação
própria; compilar no Windows não comprova funcionamento no Linux.

`scripts/toolchain.ps1` centraliza caminhos e versões. Build/teste/commit usam
seus `hbrun`, `hbmk2`, Zig e compilador. `-HbCompileRoot` e `-ZigPath` permitem
sobrescrita explícita para ferramentas externas mantidas; o padrão é próprio
do projeto. Alterações de compilador/PATH ficam restritas ao script e são
restauradas. O build não encerra servidores: `-OutputDirectory tmp/candidate`
gera um candidato em paralelo à instalação ativa.

## Banco de dados e Protheus

SQLite vem dos contribs selecionados. MSSQL usa SQLMIX/SDDODBC, gerenciador
ODBC e driver SQL Server da arquitetura do processo. Driver/DSN e credenciais
são dados de instalação, sem segredos no Git. No Linux, desenvolvimento
unixODBC é necessário no build e drivers de runtime na implantação. Configure
identidade Windows ou Kerberos Linux para autenticação integrada, ou login
SQL privado. Veja [credenciais](credentials.pt-BR.md) e
[exemplo SQL](../examples/sql/README.pt-BR.md).

Compilar Protheus exige AppServer licenciado, includes, ambiente e RPO da
instalação. [build-totvs.cmd](../scripts/build-totvs.cmd) aceita argumentos ou
`HBBRIDGE_TOTVS_APPSERVER_DIR`, `HBBRIDGE_TOTVS_INCLUDES`,
`HBBRIDGE_TOTVS_ENV`. Caminhos de scripts de parada/início são opcionais e
explícitos. hbBridge não baixa nem presume instalação fixa TOTVS. Compile
`src/tlpp/` inteiro; classes renomeadas precisam ser recompiladas antes do
aceite do cliente atual.

Licenças acompanham os fontes das dependências. Exceções de link Harbour não
se aplicam automaticamente aos utilitários GPL; Zig e zlib mantêm seus termos.
A licença global do projeto permanece em [análise de procedência](licensing.pt-BR.md).

## Possíveis contribuições ao Harbour

Os patches gerenciados são artefatos de integração. Correções genéricas devem
ser propostas separadamente: enquadramento HTTP por bytes, flags binárias ODBC
e leitura variável/tratamento de falhas de leitura. APIs adicionais de
`Ready`, workers e corpo precisam de revisão própria de compatibilidade.
Helpers de timeout com nome hbBridge, capacidade inteira JSON e leitura
estrita de atributos são políticas do projeto; uma interface de timeout no
Harbour deve ser genérica. Evidências Windows/MSSQL atuais não homologam
outros drivers nem plataformas.

`SO_REUSEADDR` incondicional precisa de política separada por plataforma:
Windows pode permitir binds concorrentes com entrega indeterminada. Veja
a [semântica de sockets Microsoft](https://learn.microsoft.com/en-us/windows/win32/winsock/using-so-reuseaddr-and-so-exclusiveaddruse).
Preservar formato/avisos do projeto oficial e seguir o [processo de contribuição Harbour](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/README.md#how-to-participate).
A anotação registra candidatos; nenhuma contribuição foi enviada.
