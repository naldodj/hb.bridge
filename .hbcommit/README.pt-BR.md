# Ferramentas de validação de commits

[English](README.md)

Este diretório contém os verificadores Harbour `check.hb`, `commit.hb` e
`3rdpatch.hb`. Os avisos de autoria e termos GPL originais continuam nos
fontes; [LICENSE.txt](LICENSE.txt) preserva o texto da licença Harbour.
São ferramentas de desenvolvimento, separadas da decisão ainda pendente
sobre o licenciamento do produto hbBridge.

Execute a validação completa na raiz do checkout com PowerShell 7:

```powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/commit-check.ps1
pwsh ./scripts/commit-check.ps1 -InstallHook
```

O script resolve `hbrun` a partir do `hb_compile` gerenciado e compilado pelo
próprio projeto. Não depende de um runtime incluído neste diretório nem de
um comando `hbrun` global. `-HbCompileRoot` e `-ZigPath` são substituições
explícitas para desenvolvimento; o uso normal requer o bootstrap local.

A validação padrão cobre arquivos versionados existentes e novos arquivos
não ignorados. Executa `check.hb` e `commit.hb`, verifica nomes nos fontes e
pares de documentação e chama `3rdpatch.hb -validate` para cada componente
de terceiros. Não inclui arquivos no índice, corrige formatação, atualiza
dependências nem cria commits.

`-InstallHook` instala um hook Git local de pre-commit somente após os
verificadores passarem. Preserva um hook diferente já existente e informa
a integração necessária. O hook chama `scripts/commit-check.ps1 -Staged`,
que lê todos os arquivos versionados do índice em uma cópia isolada dentro
de `tmp/`. Assim, verifica o conteúdo que será efetivamente publicado,
incluindo exclusões preparadas e arquivos com diferenças entre índice e
cópia de trabalho. O índice e o checkout não são alterados.

Os nomes dos arquivos próprios usam inglês e minúsculas. Mantêm-se os
nomes convencionais `README`, `AGENTS`, `TODO`, `LICENSE` e `ChangeLog` e o
sufixo de idioma `.pt-BR`. O nome-base de um arquivo de classe TLPP deve
corresponder ao nome PascalCase da classe convertido para minúsculas.
Funções, procedures, métodos e namespaces próprios Harbour e TLPP usam
minúsculas; entradas de teste existentes `U_` mantêm a compatibilidade.
A indentação dos fontes próprios usa quatro espaços. APIs nativas e
convenções dos fontes de terceiros conservam sua grafia e formatação.

`3rdpatch.hb -validate` não baixa arquivos, aplica patches nem reescreve
fontes. Os metadados de cada componente declaram `ORIGIN`, `VER`, `URL`,
`MAP` e um `SHA256` para cada arquivo mapeado. Os hashes normalizam CRLF
para LF, garantindo a mesma verificação em checkouts Git no Windows e no
Linux. Atualizar fontes de terceiros requer uma atualização separada e
revisada da procedência e dos hashes; commits normais apenas os validam.

O modo `commit.hb -c` retorna falha quando a validação falha, e o modo
normal de preparação usa as mesmas políticas de `check.hb`. O desvio
forçado da validação foi desativado. A configuração opcional de identidade
local fica em `.hbcommit/config.ini`, ignorado pelo Git; `.hbcommit` é um
diretório.

Na migração, o runtime antigo e os utilitários locais não relacionados
foram preservados nos diretórios ignorados
`tmp/commit-runtime-before-bootstrap/` e `tmp/commit-tools-legacy/`.
Eles não são dependências do projeto.
