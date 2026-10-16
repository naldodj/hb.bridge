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

[hbbridge.sql.pool.test.hb](hbbridge.sql.pool.test.hb) adds 39 SQLite-only
lease checks: caller/thread ownership, forged/stale/double returns, active
reader cleanup, fresh memory databases, defensive status and safe shutdown.
The lease/config subset passed 266 checks; the complete regression passed 712.
