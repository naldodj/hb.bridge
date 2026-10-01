# Scripts

[build-hbbridge.ps1](build-hbbridge.ps1) e o caminho oficial de compilacao.
Usa Harbour/Zig em `<HbCompileRoot>/out/zig`, compila a biblioteca `hbBridge_zig`
e o projeto `hbbridge.hbp`, que inclui os componentes de `hbbridge.hbm`.
O parametro padrao continua `C:\GitHub\hb_compile`; informe o checkout local:

```powershell
.\scripts\build-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

Antes do link, esse script encerra o `out/hbBridge.exe` ativo. Sua limpeza de
builds alternativos limita-se a `hbBridge-*.exe` e `hbBridge-*.pdb` diretamente
em `out/`. O resultado e o executavel canonico `out/hbBridge.exe`.

[test-hbbridge.ps1](test-hbbridge.ps1) compila e executa as regressoes Harbour
contra os mesmos componentes. Seu padrao de `HbCompileRoot` e o repositorio
irmao `hb_compile`; o parametro explicito tambem pode ser usado:

```powershell
.\scripts\test-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

Esse runner prepara fixtures/artefatos em uma pasta exclusiva `tmp/tests-*`,
grava `results.log` e devolve o resultado da suite, sem parar o servidor do
produto. Os artefatos ficam disponiveis para diagnostico e sao ignorados pelo Git.
Ambos os scripts exigem PowerShell 7+ e Zig no PATH.

O [launcher MVP](../examples/mvp/run.ps1) usa o binario canonico e prepara o
diretorio de trabalho. Instrucoes em [examples/mvp](../examples/mvp/README.md).
