# Testes unitários

[English](README.md)

[hbbridgeconfigtest.prg](hbbridgeconfigtest.prg) verifica padrões, precedência JSON/CLI,
resolução de diretórios, tipos, valores inválidos e conflitos de endpoints.
[hbbridgeconfiginitest.prg](hbbridgeconfiginitest.prg) acrescenta equivalência INI/JSON,
autoload junto ao executável, metadados sanitizados e validação estrita sem
alterar senhas/strings ODBC contendo `;`, `#` e `=`.
[hbbridgetimetest.prg](hbbridgetimetest.prg) verifica a fonte monotônica do servidor,
incluindo avanço durante espera e leituras concorrentes sem regressão.
O runner [test-hbbridge.ps1](../../scripts/test-hbbridge.ps1) compila esses
testes com os componentes do produto e os executa em diretório isolado.
