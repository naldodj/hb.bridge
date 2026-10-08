# Contract tests

[Português](README.pt-BR.md)

[hbbridgeservicestest.hb](hbbridgeservicestest.hb) checks registration,
versions, channel permissions, types, handler errors, independent metadata
and JSON adaptation. The [runner](../../scripts/test-hbbridge.ps1) executes it.

[MT integration](../integration/harbour/hbbridgeservertest.hb) verifies the
single active signature and rejection of different/old signatures.
[NETIO tests](../integration/harbour/hbbridgenetiotest.hb) exercise dates,
timestamps, binary and hb_Serialize/hb_Deserialize values. Negotiation,
streaming and new formats remain roadmap work. The generic core receives
application context through parameters; it does not infer Protheus rules.
