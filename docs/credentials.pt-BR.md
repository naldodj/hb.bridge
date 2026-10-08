# Credenciais no Windows, Linux e Protheus

[English](credentials.md)

A configuração atual aceita campos MSSQL estruturados ou `connectionString`
ODBC. Autenticação SQL usa `Username`/`Password` em texto aberto no arquivo
privado do servidor; autenticação integrada omite esses campos.
Armazenamento cifrado continua como proposta de arquitetura: **ainda não
implementa** senha cifrada, editor de credenciais nem provedor de chaves.
Não coloque `encrypted_secret` no arquivo
esperando decifração. Protheus envia o alias do perfil e a consulta, sem
credenciais de banco. As credenciais pertencem à instalação do servidor hbBridge.

## Todos os consumidores de credenciais: estado atual e proteção prevista

A preocupação apresentada em 2026-10-08 vale para todas as credenciais,
inclusive o cliente AppServer. Manter um arquivo fora do Git não cifra seu
conteúdo. O inventário abaixo foi conferido nos fontes públicos do host e
TLPP; nenhum valor de configuração privada foi consultado nesta análise.

| Consumidor | Armazenamento/uso atual | Escopo do desenho de armazenamento cifrado |
| --- | --- | --- |
| Perfil SQL no hbBridge | `Username`/`Password` em `[SQL/<alias>]`, ou `UID/PWD` na string ODBC; autenticação integrada dispensa a senha SQL. | Resolver o segredo SQL somente no hbBridge. Protheus não recebe senha SQL e seleciona apenas o alias instalado. |
| Cliente/servidor NETIO nativo | `[NETIO] Password` no hbBridge; clientes Harbour passam o mesmo segredo utilizável a `netio_Connect()`. | Proteger a cópia local de cada consumidor com seu próprio provedor. A fachada NETIO Protheus e sua configuração de segredo ainda não foram implementadas. |
| Administração | `[Admin] Password` protege o endpoint administrativo NETIO e a autenticação Basic do administrador web. | Proteger o segredo instalado e separar acesso administrativo do acesso aos serviços. Os dois endpoints administrativos atuais compartilham essa chave. |
| Serviço HTTP | `[HTTP] Password` no hbBridge; `[hbBridge] HTTPToken` no INI ativo do AppServer, ou argumento explícito do construtor, no Protheus. | Proteger as duas instalações. O cliente TLPP atual lê o token diretamente, sem decifração, e o envia como autenticação Bearer. |
| Cliente TCP HBBRIDGE/1 | A configuração TLPP atual não tem segredo de autenticação; o transporte TCP comum não possui camada de autenticação por credencial/TLS. | Definir autenticação e transporte protegido separadamente; cifrar o INI não os acrescenta ao protocolo. |
| Chave privada HTTPS | `PrivateKey` identifica um arquivo PEM no servidor quando build/configuração TLS estão disponíveis. | Proteger esse arquivo e seus backups separadamente; o caminho do certificado não é um provedor de cifragem da chave privada. |

Referências da implementação: [mapeamento INI do host](../src/hb/host/hbbridgeini.hb),
[validação do host](../src/hb/host/hbbridgeconfig.hb),
[adaptador NETIO](../src/hb/transports/netio/hbbridgenetio.hb),
[autorização HTTP](../src/hb/transports/http/hbbridgehttp.hb),
[cliente HTTP TLPP](../src/tlpp/hbbridgehttpclient.tlpp) e
[configuração TCP TLPP](../src/tlpp/hbbridgeconfig.tlpp).

O contrato comum previsto é uma referência de credencial resolvida localmente
pelo consumidor, ou texto cifrado autenticado e versionado cuja chave mestra
fica fora do INI e do repositório. Cada instalação/identidade de serviço possui
sua chave e seu procedimento de provisionamento. O token do AppServer e sua
contraparte no hbBridge podem representar o mesmo segredo de serviço, mas suas
cópias locais cifradas não devem exigir uma chave universal de decifração.
Também separar credenciais por finalidade: SQL, serviço NETIO, administração
e serviço HTTP. A validação atual exige somente a separação HTTP serviço/admin.

Usar provedor de arquivo portável Windows/Linux, com permissões restritas à
identidade do serviço consumidor; cofres do SO e OpenBao continuam adaptadores
opcionais. [DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)
é uma integração Windows opcional, sem ser o único backend multiplataforma.
O AppServer exige seu próprio adaptador TLPP suportado e provisionamento
protegido. A API criptográfica TOTVS exata, cifra suportada, acesso à chave e
comportamento sob identidades de serviço AppServer Windows/Linux ainda precisam
ser verificados. A cifra Zig candidata abaixo não comprova que TLPP consegue
decifrá-la; exports Harbour `HB_FUNC` não se tornam funções nativas AppServer.
Não inicializar o acesso retornando senhas SQL, NETIO ou chaves mestras por
serviço RPC de segredos. Provisionar cada consumidor localmente ou por canal
administrativo explicitamente autenticado.

Login SQL e NETIO nativo exigem segredo utilizável ao conectar; um hash
irreversível não substitui esses parâmetros. NETIO usa a senha como chave
da cifragem do fluxo. Um verificador exclusivamente HTTP futuro pode ter
necessidades diferentes, mas exige redesenho explícito da autorização; o
adaptador HTTP atual compara a credencial recebida com o valor configurado.
Base64, chave fixa da aplicação ou hash inserido no campo `Password` atual
não constituem suporte a credencial cifrada.

Proteção em arquivos e proteção em trânsito têm homologações separadas.
A [documentação Harbour NETIO fixada](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbnetio/readme.txt)
descreve ZLIB/Blowfish; o adaptador nativo usa esse fluxo, sem handshake TLS
com certificado. Não anunciá-lo como TLS moderno com validação de certificado/
hostname. Segredos HTTP Bearer/Basic exigem transporte protegido; aceite em
HTTP local não homologa HTTPS. A
[especificação Bearer](https://www.rfc-editor.org/rfc/rfc6750#section-5.2)
exige proteção do token no armazenamento e em trânsito. TLS ODBC SQL, proteção
do transporte NETIO e HTTPS AppServer/hbBridge exigem testes separados.

Antes de homologar credenciais cifradas, verificar os dois consumidores no
Windows e Linux, sob suas identidades reais de serviço: nenhum segredo em texto
aberto nos INIs, nenhuma chave fixa nos fontes/binários, falha em adulteração/
chave incorreta/provedor ausente, permissões/backups separados, atualização
manual atômica e migração explícita. Exercitar SQL, NETIO serviço/admin e HTTP
serviço/admin, incluindo o cliente TLPP, e verificar ausência de segredos em
diagnósticos, descoberta, logs e exceções. Falta de decifração deve falhar
explicitamente, sem enviar o texto cifrado como senha nem recorrer
silenciosamente à cópia em texto aberto. São critérios futuros; esta análise
não acrescenta criptografia ao runtime.

Na instalação Protheus atual do operador, senhas de banco raramente mudam,
e uma mudança exige coordenação manual do acesso ao banco e das configurações
ODBC e DBAccess. Essa restrição define o desenho inicial: armazenar e resolver
com segurança uma credencial SQL estável. Rotação automática da senha SQL
fica fora desse escopo. O hbBridge deve permitir futura atualização manual
ou migração da própria credencial, sem alterar automaticamente credenciais
externas ODBC/DBAccess. É uma necessidade operacional desta instalação,
sem afirmar que toda instalação Protheus segue essa política.

INI é portável. Criptografia exige uma chave gerenciada separadamente;
distribuir texto cifrado e uma chave fixa na mesma instalação apenas esconde
a senha de uma inspeção casual. Credential Manager/DPAPI podem ser provedores
opcionais, mas não a única solução para um produto Windows e Linux.

| Opção | Vantagem | Restrição |
| --- | --- | --- |
| Autenticação integrada | Nenhuma senha SQL no hbBridge. | Windows usa a identidade do processo; Linux exige Kerberos e renovação para serviços. |
| Credenciais SQL estruturadas ou string ODBC em INI restrito | Configuração suportada para o aceite atual. | `Username`/`Password` ou `UID/PWD` ficam em texto aberto e acompanham cópias e backups. |
| Senha cifrada no INI, chave externa | Mesmo envelope e fluxo nos dois sistemas. | Permissões, backup, troca opcional da chave mestra de criptografia e acesso do serviço exigem procedimento próprio; comprometer o processo ainda expõe credenciais utilizáveis. |
| Cofre do SO | Controles administrativos existentes. | Provisionamento, identidade e migração específicos; backend opcional. |
| Gerenciador externo de segredos | Armazenamento seguro e auditoria centralizados. | Dependência adicional; backend opcional para leitura de credenciais SQL estáveis. |

Proposta para armazenamento cifrado: parâmetros públicos de conexão e um envelope de senha cifrada,
autenticado e versionado no `hbbridge.ini`, com chave mestra fora desse INI.
O primeiro provedor portável pode ser um arquivo de chave restrito à identidade
do serviço; cofres Windows/Linux podem seguir. O arquivo registra provedor e
identificador da chave, sem chave fixa nem senha mestra embutida. Autenticação
integrada continua disponível onde a instalação puder configurá-la.

## Contrato proposto, ainda não aceito pelo parser

Estes nomes permitem revisar o desenho; o parser estrito atual rejeita as
seções/campos adicionais até a implementação:

```ini
[SQL/protheus]
Driver=mssql
ConnectionString=Driver={ODBC Driver 18 for SQL Server};Server=tcp:sql.example,1433;Database=protheus;Encrypt=Yes;TrustServerCertificate=No;
Credential=protheus

[Credential/protheus]
User=hbbridge_reader
KeyId=primary
Password=enc:v1:<authenticated-envelope>

[Key/primary]
Provider=file
Location=/etc/hbbridge/keys/primary.key
```

O caminho Windows depende da instalação. Com `Credential`, a string pública
não fornece também `UID/PWD`. A validação deve rejeitar credenciais ambíguas
e campos ODBC duplicados. Usuário/senha devem usar o escape ODBC, incluindo
ponto e vírgula e chaves de fechamento. O servidor resolve o segredo logo
antes da conexão; nunca o retorna por `--config-info`, descoberta RPC, erros
SQL ou INI do AppServer.

Use cifra autenticada padrão disponível no Zig fixado, como
XChaCha20-Poly1305, com chave/nonce aleatórios, versão do envelope, algoritmo
e ID da chave. Vincule a identidade do perfil/credencial como dados autenticados
para impedir sua troca entre registros. Base64 apenas codifica. Não invente
cifra nem reutilize nonce fixo. Antes do aceite, teste adulteração, chave
incorreta, truncamento, senhas não ASCII e suporte à troca opcional da chave
mestra de criptografia. Verifique APIs de entropia e limpeza de memória no Zig
fixado; não presuma APIs de outra versão. Se o operador decidir trocar essa
chave mestra, a mesma senha SQL será cifrada novamente; isso não muda a senha
no banco nem exige rotação da senha SQL.

## Provedor OpenBao opcional: análise da RFC em 2026-10-07

A RFC do operador em `hbridge.news.txt` é viável como **provedor de credenciais**
opcional para ler credenciais SQL estáveis do KV v2 OpenBao, junto da
autenticação integrada, INI cifrado com chave externa e provedores do SO.
Entra no pacote 003 do [WIP](../WIP.pt-BR.md). OpenBao, mecanismo de segredos
de banco, credenciais dinâmicas e plugin MSSQL não são pré-requisitos do
provedor inicial de credenciais nem do aceite MSSQL do pacote 001. Nenhum
adaptador OpenBao, serviço RPC de segredos ou campo de provedor de credenciais
no parser foi implementado.

O fluxo SQL permanece `alias/query Protheus -> perfil autorizado hbBridge ->
provedor de credenciais -> ODBC -> resultado`. Protheus resolve contexto de
negócio e envia parâmetros; hbBridge resolve somente a referência técnica de
credencial instalada. Endereço/mount/path/autenticação do cofre pertencem à
configuração servidor. Evitar um serviço irrestrito `ReadSecret(path)`. Devolver
segredos ao Protheus exigiria caso de uso, permissões e transporte protegido
com escopo próprio; não é necessário para o SQL executado pelo servidor.

A ABI C do Zig e `HB_FUNC` Harbour podem implementar o provedor interno.
Não registram função chamável no AppServer: a chamada TLPP direta
`HB_BAO_READ(...)` da RFC deve usar a fronteira cliente/serviço já existente.
Comparar adaptador nativo com [OpenBao Agent/Proxy](https://openbao.org/docs/agent-and-proxy/)
para autenticação/renovação; ambas as opções exigem runtime identificado e
homologação Windows/Linux.

[KV v2](https://openbao.org/docs/api/secret/kv/kv-v2/) oferece armazenamento
versionado e API `/<mount>/data/<path>` configurada, com envelope `data.data`.
O mount precisa realmente usar v2. Armazenamento KV não rotaciona senha SQL nem
fornece lease de credencial de banco. O provedor lê o segredo instalado;
administradores podem atualizá-lo explicitamente após uma mudança manual
coordenada da credencial. O hbBridge não altera a senha no banco, não grava
segredos KV nem atualiza configurações externas ODBC/DBAccess automaticamente.

Emissão dinâmica/rotação de senha SQL é um projeto futuro separado, somente
se solicitado explicitamente. Exigiria homologação própria de mecanismo/plugin
de banco e [ciclo de leases](https://openbao.org/docs/concepts/lease/).
A análise da RFC em 2026-10-07 registrou `database-mssql` sob suporte comunitário,
fora dos plugins nativos, conforme a [política de plugins](https://openbao.org/community/policies/plugins/);
esse registro serve à avaliação futura, sem ser pré-requisito do KV v2.

[AppRole](https://openbao.org/docs/auth/approle/) ainda exige entrega protegida
de SecretID/token. Usar identidade do serviço e políticas restritas; variável
de ambiente não torna a credencial efêmera por si só. [Response wrapping](https://openbao.org/docs/concepts/response-wrapping/)
é uma opção de entrega, com TTL, caminho de criação esperado, uso único e novo
provisionamento após reinício. Validar CA/hostname HTTPS; impedir envio de token
em redirecionamento não autorizado. Configurar prazo do provedor e comportamento
na indisponibilidade do cofre, sem trocar credencial silenciosamente. Cache KV
exige política explícita de atualização e invalidação quando o administrador
atualizar a credencial armazenada. Renovar ou substituir tokens de autenticação
OpenBao conforme seu TTL e invalidar o acesso na revogação. A renovação do token
mantém acesso à mesma credencial SQL armazenada; não muda a senha no banco.
Provisionamento inicial da autenticação, ciclo do token e troca opcional da
chave mestra de criptografia continuam sendo procedimentos separados, mesmo
com senhas SQL estáveis.

O código da RFC é conceitual e usa APIs de uma versão anterior do Zig. O
cliente HTTP do **0.16.0** fixado exige instância `Io` e APIs atuais de
requisição/resposta; allocator, ArrayList e JSON também diferem. Buffer de
4096 bytes e teto de leitura de 1 MiB são valores do esboço, não capacidades
do hbBridge. Definir propriedade dos buffers, política configurável e erros
estruturados sanitizados antes da implementação, incluindo tamanho necessário
quando faltar capacidade no destino.

Para o provedor OpenBao, buscar **ausência de persistência local das senhas de
destino gerenciada pela aplicação**; o provedor INI cifrado mantém texto cifrado.
Isso não significa ausência de texto aberto em toda memória. TLS, JSON, Harbour e ODBC
podem copiá-lo. Liberar alocação não a apaga; usar API de limpeza segura do Zig
fixado nos buffers mutáveis próprios e auditar cópias/comportamento do driver.
Reduzir vida útil e cópias sem prometer eliminação total após o handshake.
Provedores servidor resolvem/conectam internamente e retornam apenas resultados
da execução ou diagnósticos autorizados e sanitizados.

## Utilitário de administração

Começar por uma CLI local que use os mesmos serviços de configuração e
credenciais do host: criar/importar chave, definir/atualizar/excluir credencial,
testar conexão e trocar opcionalmente a chave mestra de criptografia. Atualizar
a credencial registra uma senha já provisionada pelo administrador; não muda
a senha SQL no banco nem atualiza configurações ODBC/DBAccess. Pedir senha
interativamente sem eco, sem argumento de linha de comando nem registro em
log. Escritas atômicas devem preservar
outros parâmetros INI e detectar edição concorrente. Testes retornam resultado
sanitizado. Uma interface gráfica futura pode usar o mesmo núcleo e lembrar
o fluxo DBMonitor, sem depender do armazenamento DBAccess nem decifrar suas
senhas. Autenticação, autorização e auditoria remotas ficam em outra etapa;
o primeiro editor é local.

Faça backup de texto cifrado e chaves com controles de acesso separados.
Copiar só o INI não deve transferir senhas utilizáveis; migração exige
importação/exportação explícita de chave. Um processo comprometido com acesso
à chave consegue decifrar seus segredos. Cifragem em repouso, permissões de
arquivo e TLS ODBC tratam partes diferentes do problema.

## Homologação MSSQL atual

Instale driver ODBC da arquitetura do servidor e configure DSN, ou os campos
estruturados `ODBCDriver`/`Server`/`Database`. Os exemplos
[INI](../config/examples/mssql.ini) e [JSON](../config/examples/mssql.json)
usam `Authentication=integrated`, sem campos de usuário/senha. Windows usa a
identidade do processo hbBridge; Linux exige credenciais Kerberos do serviço.
Veja o [guia Microsoft de autenticação integrada](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

Para o caminho local com login SQL, edite `C:/tmp/hbBridge.ini` fora do Git.
Preencha `Username` e `Password` no template `[SQL/mssql/pData]` preparado,
usando o login SQL existente. Mantenha as linhas comentadas até preencher
todos os valores obrigatórios; depois descomente a seção inteira.
`DSN=pData` seleciona a fonte ODBC; `Database=pData` escolhe explicitamente
seu banco. Esses nomes são exemplos da instalação, não padrões do produto.
O [guia de configuração](configuration.pt-BR.md#perfis-mssql) lista opções sem
DSN, chaves JSON, pontuação, criptografia e regras de validação.

O arquivo armazena a senha SQL preenchida em texto aberto. Restrinja o acesso
à identidade do processo hbBridge e aos administradores autorizados, inclusive
nos backups. Passe aos launchers somente caminho do arquivo privado e alias;
mantenha credenciais fora de argumentos, logs e configurações AppServer.
Perfis `ConnectionString` existentes continuam aceitos como alternativa
exclusiva.

Recompile o produto para os campos estruturados e valide sem conectar:

```powershell
./scripts/build-hbbridge.ps1
./out/hbbridge.exe --config-info "-config=C:/tmp/hbBridge.ini"
```

Depois de preencher e ativar o perfil privado, execute o aceite nativo:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

Ele usa o núcleo compartilhado de consultas sem listeners e começa por uma
constante de conexão e identificação do SQL Server real. As fixtures de leitura
verificam valores/tipos nativos, páginas, falhas sanitizadas, liberação e
isolamento; o volume medido é de 1000 linhas. Falhas de pré-requisito retornam
`2` e não contam como homologação MSSQL bem-sucedida. Ele não executa os
testes Protheus.

Inicie o produto separadamente para esses testes:

```powershell
./examples/sql/run.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

No Protheus, com as classes TLPP atuais, execute
`U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)`. As entradas de
conveniência `U_HBBridgeQueryTestMSSQL()` e `U_HBBridgeQueryTestSQLite()`
fornecem os aliases locais de exemplo; não alteram os padrões do cliente
genérico. Mudar somente o perfil do servidor não exige novo build TLPP. O teste usa
SELECTs de constantes, valores SQL, recuperação de erro e páginas, sem gravar
tabelas Protheus. O acesso direto ODBC/SQLRDD é independente das conexões,
regras de negócio e locks DBAccess. Escritas de produção ficam fora desta
homologação.

Em 2026-10-08, o perfil privado preenchido com autenticação SQL passou em
**92 checks nativos, zero falhas e nenhum skip** com SQL Server `16.0.1200.5`,
banco `pData`, ODBC Driver `18.6.2.1`, Windows x64 e Harbour `UTF8EX`.
Separadamente, o operador passou nos **29 checks TCP Protheus para MSSQL** e
repetiu os **29 checks SQLite**, threads 660 e 3192 respectivamente. Mais
tarde no mesmo dia, passou nos **13 checks HTTP de cada entrada**
`U_HBBridgeHTTPTestMSSQL()` e `U_HBBridgeHTTPTestSQLite()`, threads 25976 e
9916. Essas execuções separadas do operador homologam as rotas TCP/HTTP
exercitadas; autenticação integrada, identidades de serviço Windows/Linux,
HTTPS, gerenciamento de credenciais cifradas e cenários ampliados de falha/tipos
continuam pendentes. Veja [homologação](acceptance.pt-BR.md) para evidências
atribuíveis e trabalho restante.
