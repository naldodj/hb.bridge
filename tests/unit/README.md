# Unit tests

[Português](README.pt-BR.md)

[hbbridge.config.test.hb](hbbridge.config.test.hb) checks defaults, JSON/CLI
precedence, directory resolution, invalid types/values and endpoint conflicts.
[hbbridge.config.ini.test.hb](hbbridge.config.ini.test.hb) adds INI/JSON equivalence,
autoload, sanitized metadata, strict parsing without changing password/ODBC
punctuation (`;`, `#`, `=`), multiple profiles and slash/case-sensitive aliases.
[hbbridge.time.test.hb](hbbridge.time.test.hb) checks monotonic advancement during
waits and concurrent reads without regression. The
[runner](../../scripts/test-hbbridge.ps1) builds them with product components
and executes them in an isolated directory.
