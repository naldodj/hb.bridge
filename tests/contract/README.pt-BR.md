# Testes de contrato

[English](README.md)

[hbbridgeservicestest.prg](hbbridgeservicestest.prg) verifica registro, versões, permissões por canal,
tipos aceitos, erros de handler, metadados independentes e adaptação JSON.
É executado pelo [runner Harbour](../../scripts/test-hbbridge.ps1).

As duas assinaturas do MVP seguem na [integração MT](../integration/harbour/hbbridgeservertest.prg).
O [teste NETIO](../integration/harbour/hbbridgenetiotest.prg) verifica datas, timestamps,
bytes binários e blocos `hb_Serialize/hb_Deserialize`. Negociação, streaming
e novos formatos permanecem no roadmap.
