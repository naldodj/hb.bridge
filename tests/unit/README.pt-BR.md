# Testes unitários

[English](README.md)

[hbbridge.config.test.hb](hbbridge.config.test.hb) verifica padrões, precedência JSON/CLI,
resolução de diretórios, tipos, valores inválidos e conflitos de endpoints.
[hbbridge.config.ini.test.hb](hbbridge.config.ini.test.hb) acrescenta equivalência INI/JSON,
autoload junto ao executável, metadados sanitizados e validação estrita sem
alterar senhas/strings ODBC contendo `;`, `#` e `=`.
[hbbridge.time.test.hb](hbbridge.time.test.hb) verifica a fonte monotônica do servidor,
incluindo avanço durante espera e leituras concorrentes sem regressão.
O runner [test-hbbridge.ps1](../../scripts/test-hbbridge.ps1) compila esses
testes com os componentes do produto e os executa em diretório isolado.
