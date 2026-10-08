# Credenciais MSSQL no Windows e no Linux

[English](credentials.md)

Status: proposta de arquitetura. O runtime atual aceita `connectionString`
ODBC nos perfis MSSQL; **ainda não implementa** senha cifrada, editor de
credenciais nem provedor de chaves. Não coloque `encrypted_secret` no arquivo
esperando decifração. Protheus envia o alias do perfil e a consulta, sem
credenciais de banco. As credenciais pertencem à instalação do servidor hbBridge.

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
| String ODBC em INI restrito | Já suportada; configuração inicial simples. | `UID/PWD` ficam em texto aberto e acompanham cópias e backups. |
| Senha cifrada no INI, chave externa | Mesmo envelope e fluxo nos dois sistemas. | Permissões, backup, troca opcional da chave mestra de criptografia e acesso do serviço exigem procedimento próprio; comprometer o processo ainda expõe credenciais utilizáveis. |
| Cofre do SO | Controles administrativos existentes. | Provisionamento, identidade e migração específicos; backend opcional. |
| Gerenciador externo de segredos | Armazenamento seguro e auditoria centralizados. | Dependência adicional; backend opcional para leitura de credenciais SQL estáveis. |

Recomendação: parâmetros públicos de conexão e um envelope de senha cifrada,
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
adaptador OpenBao, serviço RPC de segredos ou novo campo do parser foi implementado.

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

Instale driver ODBC da arquitetura do servidor e defina DSN, ou use string
sem DSN em arquivo privado. Os exemplos [INI](../config/examples/mssql.ini) e
[JSON](../config/examples/mssql.json) usam autenticação integrada, sem senha.
No Linux, `Trusted_Connection=Yes` exige Kerberos, em vez do SSPI Windows,
e o serviço mantém tickets válidos. O driver Microsoft documenta
[strings com/sem DSN](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/connection-string-keywords-and-data-source-names-dsns?view=sql-server-ver17)
e [autenticação integrada Linux](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

```powershell
./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

No Protheus, após recompilar as classes renomeadas, execute
`U_HBBridgeQueryTest("mssql_demo", "127.0.0.1", 1512, 30000)`. O teste usa
SELECTs de constantes, valores SQL, recuperação de erro e páginas, sem gravar
tabelas Protheus. O acesso direto ODBC/SQLRDD é independente das conexões,
regras de negócio e locks DBAccess. Escritas de produção ficam fora desta
homologação. MSSQL real, editor de credenciais cifradas e testes da identidade
do serviço nos dois sistemas permanecem pendentes.
