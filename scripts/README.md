# Scripts

`build-hbBridge.ps1` e o caminho oficial de compilacao. Ele usa o Harbour/Zig
de `C:\GitHub\hb_compile\out\zig`, compila a biblioteca `hbBridge_zig`, encerra
o `out\hbBridge.exe` ativo antes do link e compila `hbBridge.hbp` para gerar
o executavel canonico `out\hbBridge.exe`.

A limpeza de builds alternativos limita-se aos arquivos `hbBridge-*.exe` e
`hbBridge-*.pdb` diretamente no diretorio `out` deste projeto.
