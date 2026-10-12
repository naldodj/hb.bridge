# Contract tests

[Português](README.pt-BR.md)

[hbbridge.services.test.hb](hbbridge.services.test.hb) checks registration,
versions, channel permissions, types, handler errors, independent metadata
and JSON adaptation. The [runner](../../scripts/test-hbbridge.ps1) executes it.

[MT integration](../integration/harbour/hbbridge.server.test.hb) verifies the
single active signature and rejection of different/old signatures.
[NETIO tests](../integration/harbour/hbbridge.netio.test.hb) exercise dates,
timestamps, binary and hb_Serialize/hb_Deserialize values. Negotiation,
streaming and new formats remain roadmap work. The generic core receives
application context through parameters; it does not infer Protheus rules.
