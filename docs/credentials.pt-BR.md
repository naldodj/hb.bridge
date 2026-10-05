# Credenciais MSSQL no Windows e no Linux

[English](credentials.md)

Status: proposta de arquitetura. O runtime atual aceita `connectionString`
ODBC nos perfis MSSQL; **ainda não implementa** senha cifrada, editor de
credenciais nem provedor de chaves. Não coloque `encrypted_secret` no arquivo
esperando decifração. Protheus envia o alias do perfil e a consulta, sem
credenciais de banco. As credenciais pertencem à instalação do servidor hbBridge.

INI é portável. Criptografia exige uma chave gerenciada separadamente;
distribuir texto cifrado e uma chave fixa na mesma instalação apenas esconde
a senha de uma inspeção casual. Credential Manager/DPAPI podem ser provedores
opcionais, mas não a única solução para um produto Windows e Linux.

| Opção | Vantagem | Restrição |
| --- | --- | --- |
| Autenticação integrada | Nenhuma senha SQL no hbBridge. | Windows usa a identidade do processo; Linux exige Kerberos e renovação para serviços. |
| String ODBC em INI restrito | Já suportada; configuração inicial simples. | `UID/PWD` ficam em texto aberto e acompanham cópias e backups. |
| Senha cifrada no INI, chave externa | Mesmo envelope e fluxo nos dois sistemas. | Exige permissões, backup, rotação e acesso do serviço; comprometer o processo ainda expõe credenciais utilizáveis. |
| Cofre do SO | Controles administrativos existentes. | Provisionamento, identidade e migração específicos; backend opcional. |
| Gerenciador externo de segredos | Rotação e auditoria centralizadas. | Dependência adicional; backend opcional. |

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
incorreta, truncamento, senhas não ASCII e rotação. Verifique APIs de entropia
e limpeza de memória no Zig fixado; não presuma APIs de outra versão.

## Utilitário de administração

Começar por uma CLI local que use os mesmos serviços de configuração e
credenciais do host: criar/importar chave, definir/excluir credencial, testar
conexão e rotacionar chave. Pedir senha interativamente sem eco, sem argumento
de linha de comando nem registro em log. Escritas atômicas devem preservar
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
