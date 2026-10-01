# Exemplo mínimo do hbBridge

Este exemplo executa o mesmo `out/hbBridge.exe` do produto, com os clientes e
addons compartilhados. O perfil inicial é TCP na porta 1512 e até 64 workers;
o bind atual do produto é `0.0.0.0`. Não há cópia do servidor nesta pasta.

A partir da raiz do projeto, com PowerShell 7+, Harbour/Zig e Zig no PATH:

```powershell
.\scripts\build-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
.\examples\mvp\run.ps1
```

`run.ps1` aceita `-Port` e `-MaxWorkers` e posiciona a execução na raiz para o
loader localizar `addons/`. Encerre com Ctrl+Q. O script de build encerra o
binário canônico ativo antes do link, conforme [scripts](../../scripts/README.md).

Compile o [cliente TLPP](../../src/tlpp/thbbridgeclient.tlpp) e o
[teste Protheus](../../tests/integration/protheus/hbbridgeconnectiontest.tlpp)
no AppServer e execute `U_HBBridgeConnectionTest()`. O teste usa
`127.0.0.1:1512`; ajuste seu destino se o servidor estiver em outra máquina
ou porta. Os cenários são `Health`, `Echo` e
`ADDON.examples\sample_addon.prg`, usando o [addon compartilhado](../../addons/examples/sample_addon.prg).

Para regressão Harbour automatizada, consulte [testes](../../tests/README.md).
NETIO nativo, SQL, VF IO, serviço de sistema, negociação e depuração continuam
nas etapas descritas no [TODO](../../TODO.md). Esta reorganização preserva o
comportamento e as limitações do MVP.
