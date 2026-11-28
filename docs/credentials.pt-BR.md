# Credenciais no Windows, Linux e Protheus

[English](credentials.md)

A configuração aceita campos MSSQL estruturados ou `connectionString` ODBC.
Na autenticação SQL estruturada é possível usar uma referência cifrada com
chave em arquivo separado ou a forma existente `Username`/`Password` em texto
aberto. A autenticação integrada omite credenciais SQL. O editor local e seu
comando de teste de conexão ainda não foram implementados; textos de exemplo
não são credenciais cifradas válidas. Protheus envia o alias do perfil e a
consulta, sem credenciais de banco. Elas pertencem ao servidor hbBridge.

O provedor local Harbour/C/Zig está ligado ao caminho SQL estruturado. No Windows,
45 verificações passaram com DACL protegida; outras 45 passaram como root no
Ubuntu WSL, com modo 600, usando tanto o Harbour global quanto a toolchain
Harbour/Zig gerenciada e fixada pelo projeto, isolada em filesystem Linux.
As permissões da identidade real de serviço ainda exigem aceite. A criação grava e sincroniza um arquivo
temporário privado antes da publicação exclusiva; em interrupções controladas,
o destino permaneceu ausente no Windows e no WSL Linux. Uma falha pode deixar
arquivo temporário restrito, exigindo inspeção e remoção explícitas; use um
diretório confiável e não presuma durabilidade após falha. `KEY_CLEANUP_FAILED`
indica falha na limpeza: a chave final pode já existir, portanto inspecione os
dois caminhos antes de repetir a operação.
Antes de gravar a chave, a ponte Windows verifica a DACL protegida criada; a
ponte Unix rejeita arquivo temporário com acesso por grupo ou outros. Antes de
ler uma chave existente, a ponte Unix rejeita permissões de grupo ou outros. No
Windows, o leitor exige DACL protegida com entradas explícitas de permissão
somente para o proprietário, a identidade atual ou LocalSystem; outras entradas,
inclusive negações ou herdadas, são rejeitadas preventivamente. O proprietário é
considerado confiável: o diretório e sua administração também devem ser. A
identidade do serviço precisa de leitura e READ_CONTROL e pode ser diferente do
proprietário. Esta política inicial não aceita grupo dedicado nem entrada de
administrador adicional; prepare a ACL de acordo. Permissões inadequadas ou não
verificáveis retornam `KEY_PERMISSIONS_UNSAFE`; arquivo inacessível pode retornar
`KEY_UNAVAILABLE`. Essas verificações não impedem acesso de administradores
privilegiados ou root; filesystem e identidade real de serviço exigem aceite.

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

Referências da implementação: [mapeamento INI do host](../src/hb/host/hbbridge.ini.hb),
[validação do host](../src/hb/host/hbbridge.config.hb),
[adaptador NETIO](../src/hb/transports/netio/hbbridge.netio.hb),
[autorização HTTP](../src/hb/transports/http/hbbridge.http.hb),
[cliente HTTP TLPP](../src/tlpp/hbbridge.http.client.tlpp) e
[configuração TCP TLPP](../src/tlpp/hbbridge.config.tlpp).

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
silenciosamente à cópia em texto aberto. São critérios para o plano ampliado;
somente o provedor SQL inicial e os testes registrados foram implementados.

Na instalação Protheus de referência, senhas de banco raramente mudam,
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

## Contrato de credencial SQL estruturada

O parser estrito de INI aceita as seções e campos a seguir. O envelope exibido
é ilustrativo e não uma credencial utilizável; o editor local ainda está pendente.

```ini
[SQL/protheus]
Driver=mssql
Authentication=sql
ODBCDriver=ODBC Driver 18 for SQL Server
Server=tcp:sql.example,1433
Database=protheus
Encrypt=mandatory
TrustServerCertificate=false
Credential=protheus

[Credential/protheus]
User=hbbridge_reader
KeyId=primary
Password=enc:v1:<authenticated-envelope>

[Key/primary]
Provider=file
Location=/etc/hbbridge/keys/primary.key
```

O perfil protegido usa autenticação SQL com campos estruturados.
Um perfil com `Credential` rejeita `Username`, `Password`, `ConnectionString`
livre e autenticação integrada. Os perfis existentes sem referência mantêm
a validação atual. O servidor aplica o escape ODBC existente e resolve a
credencial imediatamente antes da conexão. O campo estruturado `Password` em
texto aberto reserva o prefixo `enc:v` para impedir o envio de um envelope como
senha. Caminhos relativos da chave são resolvidos a partir do diretório do arquivo de configuração.
Em JSON, os objetos de primeiro nível `credentials` e `credentialKeys` usam,
respectivamente, `user`, `keyId`, `password` e `provider`, `location`; o perfil
SQL referencia a credencial por `credential`.
A validação da configuração verifica referências e prefixo do envelope sem
abrir a chave nem conectar ao banco; chave ausente ou incorreta e envelope
inválido impedem a conexão. Portanto, `--config-info` não testa a credencial nem
a conexão com o banco.

A fixture isolada `-CredentialTransport` testa chave ausente e tag de
autenticação adulterada em `RPCRDD.Query` pelos listeners TCP e HTTP em
loopback. Ambos retornam o contrato sanitizado `CONNECTION_FAILED`. Um Echo
é concluído após cada erro. A fixture verifica os dados de resposta e o
estado de conexão ODBC. O executor procura marcadores de credenciais
sintéticas na saída capturada. [Scripts de validação](../scripts/README.pt-BR.md).

A versão 1 usa XChaCha20-Poly1305. O provedor lê uma chave binária de 32 bytes
do caminho configurado fora do INI. O valor após `enc:v1:` usa Base64 padrão
com preenchimento para o nonce de 24 bytes, o texto cifrado e a tag de 16 bytes,
nessa ordem. O conteúdo cifrado é a senha SQL em UTF-8. Cada cifragem usa
um novo nonce do gerador criptográfico do SO. Falhas de entropia, formato e
autenticação interrompem a operação com erro sanitizado.

No Windows, o provedor decodifica caminhos de chave explicitamente como UTF-8,
independentemente da code page ativa do Harbour. Versões anteriores podiam criar
ou procurar um nome diferente com uma code page que não fosse UTF-8. Em instalações
existentes com esses caminhos, verificar o nome efetivo da chave antes de alterar
a configuração; o provedor não move nem substitui chaves automaticamente.

O provedor atual aceita senhas UTF-8 não vazias de até 4096 bytes, sem NUL, CR
ou LF. Cada campo do contexto autenticado é limitado a 1024 bytes UTF-8. Esses
limites pertencem à implementação atual do provedor de credenciais, separados
das políticas de payload RPC; entradas inválidas ou maiores falham sem truncar.

Os dados autenticados começam pelos bytes literais `hbbridge/credential/v1`.
Em seguida vêm a finalidade `sql`, o identificador canônico do perfil SQL,
o identificador da credencial, o identificador da chave e o usuário SQL,
nessa ordem. Cada campo usa bytes UTF-8 precedidos pelo comprimento em bytes
como inteiro sem sinal de 32 bits em big-endian. Usar os identificadores
resolvidos pelo parser para manter os mesmos bytes em buscas equivalentes.
Cada envelope fica vinculado a um perfil. Mover o envelope para outro perfil,
alterar um campo vinculado ou trocar a chave exige nova cifragem. A senha no
banco permanece a mesma.

## C01: recursos nativos e administração local

A interface administrativa prevista usa um modo de comando local do próprio
executável `hbbridge` e compartilha o provedor com o host. A administração
local funciona sem listeners. Os nomes dos comandos ainda serão definidos.

A primeira entrega SQL guarda o envelope no INI e a chave em arquivo binário
separado. A prova de serialização Harbour registra interoperabilidade para
possíveis segredos estruturados futuros. Limitar o tamanho do envelope e
validar versão e codificação antes de decodificar. Autenticar antes de
entregar o texto aberto ao chamador. A configuração e o diretório de chaves
exigem controle administrativo de gravação. O envelope protege uma cópia
do INI sem a chave e detecta alterações nos dados autenticados. O controle
do host, do processo ou da configuração do destino SQL por um atacante está
fora desse modelo de proteção.

Usar a biblioteca estática existente `hbbridge_zig` e um adaptador C/Harbour.
Passar entradas binárias como ponteiros com comprimento explícito em bytes.
O chamador controla os buffers de saída e recebe um código de estado. Validar
comprimentos e capacidades antes de acessar memória. Limpar chaves e texto
aberto em buffers do provedor em todas as saídas. Em caso de falha, a saída
fica indisponível ao chamador Harbour.

Preservar a referência protegida nas duas normalizações do perfil SQL e
resolvê-la antes de `RDDI_CONNECT` no pool. Auditar diagnósticos nativos ODBC
e falhas de alocação junto com os erros RPC. O driver gerenciado deixou de
solicitar o buffer com a string de conexão completa e de passar a string de
entrada aos erros de alocação. Falhas de conexão preservam um SQLSTATE validado
e mensagem fixa, sem o texto fornecido pelo driver. Um teste com DSN sintético
ausente verifica o diagnóstico nativo e a resposta RPC; o aceite MSSQL somente
de leitura passou no Windows. O Harbour e o driver ODBC
ainda podem manter texto aberto temporário fora dos buffers controlados
pelo provedor.

As primeiras provas em WSL2 x86_64, em 2026-11-06, usaram o Harbour 3.2.0dev
r2307062207 do sistema e Zig 0.16.0 compilado de forma cruzada no Windows.
Em 2026-11-11, as provas no Windows x64 usaram Harbour gerenciado 3.2.1dev
r2609292008 e Zig 0.16.0. A serialização preservou bytes NUL e EOF. Os
testes Zig rejeitaram alteração do texto cifrado, tag, chave, nonce e
contexto. A prova da ABI Harbour/C/Zig passou com a toolchain fixada e
exercitou a entropia do SO por meio de uma instância explícita de
`std.Io.Threaded` na biblioteca Zig vinculada ao executável. A prova usa
`Io.randomSecure` e falha em caso de erro de entropia.

As três provas também passaram em 2026-11-11 com Zig 0.16.0 nativo Linux,
Harbour fixado 3.2.1dev r2609292008 e GCC 16.2.0 no WSL2 x86_64 (Kali Linux).
O bootstrap do perfil GCC instala as bibliotecas Harbour em `lib/linux/gcc`,
diretório usado pela toolchain gerenciada do hbBridge. Executar as
[provas de viabilidade](../scripts/README.pt-BR.md#provas-de-viabilidade-de-credenciais)
após o bootstrap no sistema de destino. O executável Linux também foi
vinculado com o perfil GCC após habilitar PIC no módulo Zig e instalar os
metadados de vinculação do SQLite. Em uma prova separada no WSL2,
`hbmk2 -plat=linux -comp=zig` compilou e vinculou um programa Harbour com as
bibliotecas Harbour já compiladas com GCC. O programa executou com sucesso.
Em 2026-11-12, o bootstrap Linux limpo com Zig, a preparação dos contribs
gerenciados, o build do produto e a prova de ABI de credenciais passaram
no WSL2 x86_64. O perfil GCC também passou no bootstrap, no build do produto
e na prova de ABI. O [guia de dependências](dependencies.pt-BR.md#seleção-de-compilador-no-linux)
registra como selecionar cada perfil.

As provas Windows Authz usaram uma DACL em memória e contextos de SID sem
grupos. `LocalService` pôde ler e teve gravação negada, `NetworkService`
teve leitura negada e `LocalSystem` pôde gravar. No WSL2, unidades
transitórias do systemd usaram um arquivo sintético de 32 bytes no sistema
de arquivos nativo Linux. Com dono/grupo `root:nogroup` e modo `0640`, a
unidade com `nobody:nogroup` leu o arquivo e teve gravação negada. A unidade
com `daemon:daemon` teve leitura negada. As unidades e o arquivo sintético
foram temporários.
[API Windows Authz](https://learn.microsoft.com/en-us/windows/win32/api/authz/nf-authz-authzaccesscheck)
· [Identidade de serviço no systemd](https://www.freedesktop.org/software/systemd/man/256/systemd.exec.html#User=).

Essas provas estabelecem a viabilidade. O provedor e a ABI de produção
exigem validação no C02. O C05 cobre os tokens de serviço da instalação,
as permissões de arquivo após substituição atômica e a conexão SQL real.
O consumidor TLPP tem escopo de aceite próprio.

## Provedor OpenBao opcional: análise da RFC em 2026-10-07

A RFC registrada em `hbridge.news.txt` é viável como **provedor de credenciais**
opcional para ler credenciais SQL estáveis do KV v2 OpenBao, junto da
autenticação integrada, INI cifrado com chave externa e provedores do SO.
OpenBao permanece como etapa futura separada; o [WIP](../WIP.pt-BR.md) inicia
com provedor local. OpenBao, mecanismo de segredos
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

## Autenticação futura de clientes e credenciais no servidor

O provedor comum poderá proteger as credenciais SQL, NETIO, HTTP e de
administração usadas pelo hbBridge. Isso não exige um serviço remoto que devolva
essas senhas: o cliente autenticado recebe autorização para executar operações
permitidas, e o servidor mantém e utiliza as credenciais dos serviços de destino.
Uma API externa para exportar segredos exigiria justificativa, contrato e revisão
de segurança próprios; ela não está proposta aqui.

Para integrações automáticas, avaliar identidade distinta por cliente e TLS
autenticado, como certificado do cliente, ou um provedor de identidade confiável
que emita tokens curtos com permissões delimitadas. Certificados e tokens precisam
ser suportados e homologados em cada cliente Protheus/Harbour e transporte; o
cliente ainda precisa proteger sua chave privada ou outra identidade inicial.
Limitar autorização por serviço/perfil e contexto explícito, auditar acessos e
permitir revogação. O Protheus continua resolvendo empresa, filial e permissões
ERP; valores informados pelo cliente não concedem autorização por si. Tokens
OAuth vinculados a certificado são especificados na
[RFC 8705](https://www.rfc-editor.org/rfc/rfc8705).

O [TOTP](https://www.rfc-editor.org/rfc/rfc6238) exige segredo compartilhado e
relógios coordenados. Pode ser útil como fator adicional na administração
interativa; um cliente automático que gere o código ainda precisa proteger seu
próprio segredo TOTP. Avaliar limitação de tentativas, prevenção de reutilização,
recuperação e horário confiável. Esta proposta não implementa TOTP, mTLS nem
emissor de tokens.

O protocolo NETIO nativo atual usa sua senha configurada na conexão. Um cliente
NETIO sem alterações continua precisando dessa senha; mantê-la somente no
servidor exigiria gateway ou mudança de protocolo com desenho próprio. HTTP, TCP
e NETIO exigem aceites separados. Esta é uma evolução posterior, não um
pré-requisito da entrega atual do provedor local de credenciais SQL.

## Utilitário de administração

Para criar localmente uma chave aleatória do provedor de arquivos:

```text
hbbridge --credential-create-key --key=<caminho-do-arquivo-de-chave>
```

O diretório pai deve existir. O provedor restringe o acesso e publica a chave
com exclusividade, sem substituir arquivo existente. O comando não inicia
listeners e retorna somente PASS/FAIL. Após falha, verifique o destino e os
eventuais arquivos temporários privados antes de tentar novamente: um erro de
limpeza pode ocorrer depois da publicação. Siga as orientações de recuperação
abaixo. O comando cria apenas a chave; não cria nem altera credenciais.

Um preparador interno de INI pode montar a substituição de uma senha cifrada
existente preservando os demais bytes, comentários, BOM e finais de linha. Ele
valida o INI e a estrutura canônica do novo envelope, mas não o autentica, não
lê nem grava o arquivo de configuração e não detecta edições concorrentes. O
futuro editor deverá criar e autenticar o envelope no contexto pretendido,
detectar conflitos e publicar a alteração atomicamente. Esse preparador não é
um comando de administração.

Um segundo preparador interno usa o conteúdo do INI e seu diretório para resolver
o perfil MSSQL protegido. Ele autentica o envelope atual no contexto de perfil,
credencial, chave e usuário, cifra e verifica a substituição e chama o primeiro
preparador. Uma credencial referenciada por múltiplos perfis é rejeitada, pois
o envelope é vinculado a um perfil. Esse processo não conecta ao SQL, não lê
o arquivo de configuração, não detecta edições concorrentes e não publica o
resultado. Texto em memória gerenciada pelo Harbour pode permanecer após a
liberação das variáveis; o provedor limpa apenas os próprios buffers.

Uma verificação prévia por bytes retorna `CONFIG_CHANGED` quando o conteúdo
observado difere do original, inclusive em mudanças de mesmo tamanho e após NUL.
Ela não impede alteração após a comparação; o futuro publicador deverá conferir
novamente sob um mecanismo de coordenação documentado e não poderá presumir que
editores externos respeitam um bloqueio consultivo.
Se for adotado um arquivo auxiliar de bloqueio, sua identidade deverá permanecer
estável enquanto algum processo puder mantê-lo ou aguardá-lo; excluir e recriar
esse arquivo pode dividir participantes entre bloqueios distintos. A comparação
deve ser repetida imediatamente antes da publicação, deixando explícito que
editores externos que ignoram o protocolo ainda podem disputar a alteração.

A prova sintética de substituição local verifica bloqueio auxiliar entre
processos, staging, alteração conflitante, leitor aberto e metadados. No volume
Windows NTFS testado, [`ReplaceFileW`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew)
alterou metadados de herança da DACL tanto com DACL herdada quanto protegida;
titulares e direitos observados permaneceram iguais. Reaplicar explicitamente
o descritor anterior o restaurou nesses testes, mas essa etapa adicional não
garante segurança atômica. A prova em sistema de arquivos local no WSL passou
nos limites testados de modo/proprietário, leitor, renomeação e sync do diretório.
Nos dois ambientes, uma alteração sintética feita após a comparação por um editor
que ignorava o bloqueio foi sobrescrita pela substituição. Nenhum dos resultados
comprova durabilidade após falha, preservação de ACLs
estendidas ou segurança contra editores que ignoram o bloqueio. A publicação de
arquivo para produção permanece não implementada.

Uma implementação candidata isolada para Linux é exercitada pela
[prova independente](../tests/probes/hbbridge.credential.publish.probe.hbp) e
pelas fixtures de integração sintética. Está vinculada somente aos alvos de
teste. Ela bloqueia um arquivo auxiliar persistente, confere os
bytes esperados novamente, cria um arquivo temporário exclusivo no mesmo diretório,
reproduz proprietário e modo, sincroniza o arquivo e o renomeia. Rejeita links
simbólicos e físicos para o destino, destinos ou diretórios de publicação com
escrita para grupo ou outros, destinos de outra identidade e atributos estendidos
visíveis.

O caminho absoluto é aberto componente a componente a partir da raiz. Cada
diretório deve pertencer ao root ou ao usuário efetivo. Links simbólicos e
`..` são recusados. Um ancestral com escrita para grupo ou outros é aceito
somente com o sticky bit, como no caso de um diretório privativo sob `/tmp`.
O diretório de publicação deve impedir escrita por grupo ou outros. No Ubuntu
WSL, a prova passou em 25 verificações como root e 24 como `nobody`, incluindo
a recusa de caminhos inseguros antes de criar o lock. Um ancestral confiável com
permissão apenas de travessia também passou. A execução como root testou um
diretório de propriedade de `nobody`.
[Linux `openat()` e `O_NOFOLLOW`](https://man7.org/linux/man-pages/man2/open.2.html),
[Sticky bit em diretórios Linux](https://man7.org/linux/man-pages/man7/inode.7.html).

A fixture de atualização pelo terminal passou a usar uma leitura nativa
limitada. Ela abre o mesmo tipo de arquivo regular validado pelo publicador,
confere identidade e metadados antes e depois da leitura sem criar um lock
ou arquivo de estágio. A fixture compara uma segunda leitura após o prompt.
O leitor e o publicador aceitam até 1 MiB para o snapshot e o INI substituto.
O publicador confere o original sob o lock. O limite pertence à fixture e
independe da leitura de configuração do servidor.

A versão anterior aceitava um arquivo com `nodump` e descartava essa flag
mesmo com a lista de atributos estendidos vazia. O candidato passou a
inspecionar flags do inode e recusar metadados não suportados antes de
prosseguir. O sistema de arquivos da implantação e atributos invisíveis ao
usuário efetivo ainda exigem aceite. [Flags de inode no Linux](https://man7.org/linux/man-pages/man2/ioctl_iflags.2.html),
[visibilidade dos atributos estendidos](https://man7.org/linux/man-pages/man7/xattr.7.html).

O status 8 no Linux indica que a publicação ocorreu, mas a sincronização
do diretório falhou: é preciso examinar o destino antes de tentar novamente.
A injeção de falhas é compilada somente na prova. Um encerramento inesperado pode
deixar o arquivo temporário. O bloqueio cobre apenas processos que respeitam o
protocolo, não editores arbitrários. A visibilidade de atributos estendidos depende
dos privilégios do processo; uma listagem vazia não comprova a ausência de atributos
inacessíveis. Permanecem pendentes a semântica do sistema de arquivos e a validação
com as identidades de serviço da implantação. No Windows, o código retorna
não suportado sem gravar. Na fixture sintética em NTFS, `MoveFileExW` preservou o
descritor observado sem leitor aberto, mas falhou com leitor aberto; isso não basta
para aceitar um publicador Windows. Outra prova sintética em NTFS com
[`FileRenameInfoEx` e semântica POSIX](https://learn.microsoft.com/en-us/windows/win32/api/winbase/ns-winbase-file_rename_info)
preservou proprietário, grupo e DACL observados com leitor aberto, nos casos de DACL
herdada e protegida testados. A substituição descartou um fluxo de dados alternativo
sintético. A leitura da SACL falhou com erro 1314 para a identidade usada no teste.
Portanto, comparar apenas proprietário, grupo e DACL não comprova a preservação dos
metadados; o publicador Windows precisa tratar ou rejeitar explicitamente metadados
não suportados antes de ser integrado ao utilitário. Essas provas não estabelecem
o comportamento para outros sistemas de arquivos, ACLs, privilégios ou leitores
que não permitam compartilhamento de exclusão.
Uma prova nativa isolada de enumeração de fluxos agora rejeita um fluxo nomeado
e arquivo com link físico, e aceita o fluxo sem nome e o nome UTF-8 testados. Ela
não examina todos os tipos de metadados Windows nem autoriza a substituição; é
compilada somente na prova sintética e não está ligada ao utilitário.
A prova também tenta ler a SACL sem alterar o token do processo. Ela informa a
ausência de `SeSecurityPrivilege` em vez de presumir que uma SACL inacessível está
vazia. A Microsoft documenta que o acesso à SACL exige o
[`SeSecurityPrivilege` habilitado](https://learn.microsoft.com/en-us/windows/win32/secauthz/sacl-access-right).
A fixture Windows sem privilégio exercita a recusa. A prova opcional de
auditoria também valida o acesso à SACL e o ciclo do privilégio com escopo
restrito. A preservação durante a substituição atômica permanece pendente.

O modo isolado `metadata` no Windows reúne essas verificações. Ele aceita
um caminho absoluto com letra de unidade para o fluxo sem nome. Abre um
handle do arquivo em disco com compartilhamento de leitura, recusa atributos
extras, links e fluxos nomeados, e examina o descritor de segurança pelo
mesmo handle quando há acesso à SACL. Se o token não tem
`SeSecurityPrivilege`, uma abertura básica permite identificar metadados
não suportados. Um candidato regular ainda retorna que o privilégio é
necessário. A prova não altera o token, cria arquivos auxiliares ou tenta
substituir o INI. O handle é fechado antes do retorno. O resultado
valida a inspeção prévia.
[Acesso à SACL no Windows](https://learn.microsoft.com/en-us/windows/win32/secauthz/sacl-access-right),
[pontos de nova análise no Windows](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points-and-file-operations).

O teste opcional `--require-audit` exige uma identidade que já tenha
`SeSecurityPrivilege`. A prova habilita o privilégio em um token privado
da thread no caso sintético e restaura o estado anterior. Ela cria uma
fixture com SACL protegida e uma ACE de auditoria de leitura, inspeciona
a SACL e compara o resultado antes e depois. O diagnóstico de falha
mostra somente a etapa do teste e o código Win32. Em 2026-11-27, as 21
verificações passaram em NTFS com uma conta local temporária. A ACE de
auditoria permaneceu intacta após a inspeção e a sobrescrita da fixture
existente foi recusada. Confirmada a remoção do direito, da conta, do
perfil e do diretório de arquivos sintéticos.
[Ativação e restauração do privilégio](https://learn.microsoft.com/pt-br/windows/win32/api/securitybaseapi/nf-securitybaseapi-adjusttokenprivileges).

No volume NTFS testado, um identificador que impede compartilhamento de escrita
bloqueou a abertura para gravação por outro processo e permitiu leitores compatíveis.
Quando permite compartilhamento de exclusão, outro processo ainda consegue
substituir o caminho. Quando o impede, a própria substituição preparada também
falha até o identificador ser fechado. Um leitor que não compartilha exclusão
também impede a substituição; na falha testada os dois arquivos foram preservados.
Essas observações não estabelecem um protocolo completo sem conflitos nem cobrem
outros sistemas de arquivos.

O candidato Linux também possui pontos de pausa exclusivos dos testes para uma
alteração concorrente e uma interrupção forçada após o staging. A alteração é
rejeitada na última comparação; o processo interrompido deixa um arquivo temporário
órfão com o modo original testado e preserva o destino. Isso não elimina a janela
após a última comparação nem comprova durabilidade diante de falha.

Uma fixture sintética integrada prepara uma substituição autenticada com uma
chave de teste privada e a encaminha ao publicador isolado. No Windows, a prova
confirma que a operação não suportada preserva o INI original. No WSL, o candidato
publica o INI preparado, o perfil relido decifra a nova senha e uma repetição com
o snapshot anterior é rejeitada. O teste não se conecta a um SGBD real nem
transforma o candidato em comando do produto.

Um leitor experimental independente aceita somente terminal interativo, desativa
o eco durante a leitura e restaura o modo anterior. O leitor está vinculado
somente aos alvos de teste. A implementação de teste aceita UTF-8 não vazio de
até 4096 bytes, preserva espaços nas extremidades e tabulações e rejeita NUL
e controles ASCII além de tabulação. Enter encerra a entrada e o conteúdo
pendente do terminal é descartado antes de restaurar o eco. No Unix, backspace remove um
caractere UTF-8 e os sinais de término testados cancelam a entrada para permitir
a limpeza normal do terminal pelo Harbour. Os sinais afetam todo o processo; o
leitor destina-se apenas à CLI local, antes de listeners ou workers. O futuro
chamador deverá encerrar a operação em caso de cancelamento ou erro ao restaurar
o terminal. O retorno normal e os caminhos de Ctrl+C/término testados restauram
o modo; término forçado do processo ou perda do terminal não permitem garantir a restauração. Buffers
nativos são limpos, mas a string retornada ao Harbour não pode ser apagada com
garantia.

O alvo de testes SQL protegidos também reúne a leitura no terminal, a
preparação autenticada e o publicador isolado com um INI descartável.
Execute `pwsh ./scripts/test-credentials-sql.ps1 -TerminalUpdate`. No Linux,
um pseudoterminal permite verificar gravação e releitura, cancelamento,
entrada redirecionada e edição concorrente do INI durante o prompt. O teste
confere a restauração do modo do terminal, a ausência de credenciais na
saída e a preservação da chave. No Windows, a prova recusa a operação antes
de pedir a senha ou gravar. Os quatro cenários interativos passaram no
Ubuntu WSL como root e como `nobody`. A fixture é exclusiva do alvo de testes.
[Scripts de validação](../scripts/README.pt-BR.md).

O primeiro teste local de conexão aceita um perfil MSSQL protegido existente:

```text
hbbridge --credential-test --config=<arquivo.ini-ou-json> --profile=<alias-do-perfil>
```

O comando lê a configuração indicada, resolve a credencial protegida pelo
caminho SQL normal e executa o `SELECT 1 AS ID` fixo e somente de leitura.
Não inicia listeners nem aceita senha ou SQL na linha de comando. O resultado
é `Credential connection test: PASS` com código 0 ou `FAIL` sanitizado com
código 1. É um primeiro teste de conexão, não um editor de credenciais; exige
perfil MSSQL protegido configurado e chave acessível. O ciclo SQL normal libera
a concessão da conexão após a consulta. O pooling configurado segue a política
do driver no processo até o encerramento do comando. O aceite com identidade
de serviço e MSSQL no Linux permanece pendente.

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

O teste de conexão resolverá o perfil e a credencial salvos, executará uma
consulta inofensiva e liberará a conexão, retornando sucesso ou erro sanitizado
sem iniciar listeners, expor segredos ou alterar dados. Ele ainda precisa ser
implementado e validado junto à integração SQL.

Faça backup de texto cifrado e chaves com controles de acesso separados.
Copiar só o INI não deve transferir senhas utilizáveis; migração exige
importação/exportação explícita de chave. Um processo comprometido com acesso
à chave consegue decifrar seus segredos. Cifragem em repouso, permissões de
arquivo e TLS ODBC tratam partes diferentes do problema.

O envelope versão 1 e sua chave de 32 bytes foram projetados para portabilidade
entre Windows e Linux. O envelope é autenticado com perfil SQL, identificador
da credencial, identificador da chave e usuário SQL; alterar qualquer um deles
exige nova cifragem usando a chave e o contexto originais. Caminhos de arquivo e
identidades do sistema operacional não fazem parte desse contexto. A migração
deve proteger a chave separadamente, preparar permissões no destino e ajustar
configurações ODBC locais. Uma prova externa com dados sintéticos passou nos dois
sentidos entre Windows com Harbour gerenciado r2609292008 e Ubuntu WSL com
Harbour global r2610242111. Ela valida formato e vínculo do contexto no provedor,
não um utilitário de migração de INI nem uma conexão SQL real.

### Recuperação após interrupção da criação da chave

O procedimento se aplica ao provedor local experimental; o editor integrado de
credenciais ainda não existe. Um arquivo `nome-da-chave.tmp.*` contém material
de chave. Não exiba seu conteúdo, não o mova para diretório desprotegido nem o
remova enquanto outro processo possa estar criando a chave.

1. Pare ou coordene todos os processos de criação para aquele destino. Inspecione
   os caminhos exatos do destino e dos arquivos temporários no diretório confiável.
2. Se o destino existir, preserve-o. `KEY_CLEANUP_FAILED` pode ocorrer após a
   publicação no Unix. Uma nova tentativa não deve substituir esse destino.
3. Se o destino estiver ausente e a chave já tiver sido usada, restaure a chave
   correspondente de um backup protegido. Outra chave não recupera o texto cifrado
   com a chave perdida. Não promova arquivo temporário apenas por nome ou tamanho.
4. Somente depois de confirmar que o arquivo temporário não está em uso nem é
   necessário para recuperação, remova esse arquivo específico com ferramentas
   autorizadas do sistema. Se for comprovadamente a primeira criação e não houver
   texto cifrado dependente, tente criar novamente; caso contrário, preserve a
   chave original.
5. Verifique as permissões e, quando a integração SQL estiver disponível, teste
   a conexão configurada. O protocolo ainda não garante a durabilidade dos metadados
   do diretório após perda de energia; valide o filesystem utilizado.

## Homologação MSSQL atual

Instale driver ODBC da arquitetura do servidor e configure DSN, ou os campos
estruturados `ODBCDriver`/`Server`/`Database`. Os exemplos
[INI](../config/examples/mssql.ini) e [JSON](../config/examples/mssql.json)
usam `Authentication=integrated`, sem campos de usuário/senha. Windows usa a
identidade do processo hbBridge; Linux exige credenciais Kerberos do serviço.
Veja o [guia Microsoft de autenticação integrada](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

Para o caminho local com login SQL, edite `C:/tmp/hbBridge.ini` fora do Git.
Preencha `Username` e `Password` no template `[SQL/MSSQL/pData]` preparado,
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
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

Ele usa o núcleo compartilhado de consultas sem listeners e começa por uma
constante de conexão e identificação do SQL Server real. As fixtures de leitura
verificam valores/tipos nativos, páginas, falhas sanitizadas, liberação e
isolamento; o volume medido é de 1000 linhas. Falhas de pré-requisito retornam
`2` e não contam como homologação MSSQL bem-sucedida. Ele não executa os
testes Protheus.

Inicie o produto separadamente para esses testes:

```powershell
./examples/sql/run.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

No Protheus, com as classes TLPP atuais, execute
`U_HBBridgeQueryTest("MSSQL/pData", "127.0.0.1", 1512, 30000)`. As entradas de
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
Separadamente, execuções manuais no AppServer passaram nos **29 checks TCP
Protheus para MSSQL** e repetiram os **29 checks SQLite**, threads 660 e
3192 respectivamente. Mais tarde no mesmo dia, execuções manuais passaram
nos **13 checks HTTP de cada entrada**
`U_HBBridgeHTTPTestMSSQL()` e `U_HBBridgeHTTPTestSQLite()`, threads 25976 e
9916. Essas execuções manuais separadas no AppServer homologam as rotas TCP/HTTP
exercitadas; autenticação integrada, identidades de serviço Windows/Linux,
HTTPS, gerenciamento de credenciais cifradas e cenários ampliados de falha/tipos
continuam pendentes. Veja [homologação](acceptance.pt-BR.md) para evidências
atribuíveis e trabalho restante.
