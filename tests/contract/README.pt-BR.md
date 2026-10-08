# Testes de contrato

[English](README.md)

[hbbridgeservicestest.hb](hbbridgeservicestest.hb) verifica registro, versões, permissões por canal,
tipos aceitos, erros de handler, metadados independentes e adaptação JSON.
É executado pelo [runner Harbour](../../scripts/test-hbbridge.ps1).

As duas assinaturas do MVP seguem na [integração MT](../integration/harbour/hbbridgeservertest.hb).
O [teste NETIO](../integration/harbour/hbbridgenetiotest.hb) verifica datas, timestamps,
bytes binários e blocos `hb_Serialize/hb_Deserialize`. Negociação, streaming
e novos formatos permanecem no roadmap.
